import os
import re
import uuid
from typing import Any, Dict

from flask import Flask, jsonify, request
import google.auth
from google.auth.transport.requests import AuthorizedSession

app = Flask(__name__)

API_ROOT = "https://config.googleapis.com/v1"
IM_PROJECT_ID = os.environ["IM_PROJECT_ID"]
IM_LOCATION = os.getenv("IM_LOCATION", "asia-northeast3")
IM_SERVICE_ACCOUNT = os.environ["IM_SERVICE_ACCOUNT"]
TF_REPO_URL = os.getenv(
    "TF_REPO_URL",
    "https://github.com/sonmap/Gcp_Managed_GKE_GIT_ETC_03.git",
)
TF_REPO_REF = os.getenv("TF_REPO_REF", "main")
TF_DIRECTORY = os.getenv(
    "TF_DIRECTORY", "infra-manager/terraform/task-blueprint"
)
DEFAULT_TARGET_PROJECT_ID = os.getenv("DEFAULT_TARGET_PROJECT_ID", "")

credentials, _ = google.auth.default(
    scopes=["https://www.googleapis.com/auth/cloud-platform"]
)
authed = AuthorizedSession(credentials)


def _first(payload: Dict[str, Any], *names: str, default=None):
    for name in names:
        value = payload.get(name)
        if value is not None and str(value).strip() != "":
            return value
    return default


def _safe_id(value: str, prefix: str = "task") -> str:
    value = str(value).lower().strip()
    value = re.sub(r"[^a-z0-9-]", "-", value)
    value = re.sub(r"-+", "-", value).strip("-")
    if not value:
        value = f"{prefix}-{uuid.uuid4().hex[:8]}"
    if not value[0].isalpha():
        value = f"{prefix}-{value}"
    return value[:60].rstrip("-")


def _dataset_id(task_id: str) -> str:
    # BigQuery dataset IDs use letters/numbers/underscore.
    raw = re.sub(r"[^A-Za-z0-9_]", "_", task_id)
    raw = re.sub(r"_+", "_", raw).strip("_")
    if not raw:
        raw = uuid.uuid4().hex[:8]
    return f"ds_{raw}"[:1024]


def _map_legacy_json(payload: Dict[str, Any]) -> Dict[str, str]:
    """
    Adapter boundary.

    The Java portal JSON is not changed. Only this Cloud Run service knows how
    legacy request fields map to Terraform variables. Add aliases here when the
    real production JSON schema is known.
    """
    task_id = str(
        _first(payload, "taskId", "task_id", "projectId", "project_id", "requestId")
        or ""
    )
    if not task_id:
        raise ValueError("taskId (or task_id/projectId/project_id) is required")

    target_project_id = str(
        _first(
            payload,
            "targetProjectId",
            "target_project_id",
            "gcpProjectId",
            "gcp_project_id",
            default=DEFAULT_TARGET_PROJECT_ID,
        )
        or ""
    )
    if not target_project_id:
        raise ValueError(
            "targetProjectId is required, or set DEFAULT_TARGET_PROJECT_ID on Cloud Run"
        )

    group = str(_first(payload, "group", "groupCode", "group_code", default="a"))
    location = str(_first(payload, "location", "region", default="asia-northeast3"))
    task_name = str(_first(payload, "taskName", "task_name", "projectName", default=task_id))

    return {
        "task_id": task_id,
        "task_name": task_name,
        "group": group.lower(),
        "target_project_id": target_project_id,
        "dataset_id": _dataset_id(task_id),
        "bq_location": location,
    }


def _deployment_body(mapped: Dict[str, str], deployment_name: str | None = None):
    input_values = {
        key: {"inputValue": value}
        for key, value in mapped.items()
    }

    body = {
        "serviceAccount": IM_SERVICE_ACCOUNT,
        "terraformBlueprint": {
            "gitSource": {
                "repo": TF_REPO_URL,
                "directory": TF_DIRECTORY,
                "ref": TF_REPO_REF,
            },
            "inputValues": input_values,
        },
        "annotations": {
            "source": "datalake-portal-cloud-run-adapter",
            "task-id": _safe_id(mapped["task_id"]),
            "group": _safe_id(mapped["group"], "group")[:20],
        },
    }
    if deployment_name:
        body["name"] = deployment_name
    return body


@app.get("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.post("/deploy")
def deploy():
    payload = request.get_json(silent=False)
    if not isinstance(payload, dict):
        return jsonify({"error": "JSON object required"}), 400

    try:
        mapped = _map_legacy_json(payload)
    except ValueError as exc:
        return jsonify({"error": str(exc), "received": payload}), 400

    deployment_id = _safe_id(mapped["task_id"])
    parent = f"projects/{IM_PROJECT_ID}/locations/{IM_LOCATION}"
    deployment_name = f"{parent}/deployments/{deployment_id}"
    deployment_url = f"{API_ROOT}/{deployment_name}"

    existing = authed.get(deployment_url, timeout=30)
    request_id = str(uuid.uuid4())

    if existing.status_code == 404:
        url = f"{API_ROOT}/{parent}/deployments"
        response = authed.post(
            url,
            params={"deploymentId": deployment_id, "requestId": request_id},
            json=_deployment_body(mapped),
            timeout=60,
        )
        action = "create"
    elif existing.ok:
        current = existing.json()
        if current.get("state") in {"CREATING", "UPDATING", "DELETING"}:
            return jsonify(
                {
                    "error": "deployment is busy",
                    "deployment": deployment_name,
                    "state": current.get("state"),
                }
            ), 409

        response = authed.patch(
            deployment_url,
            params={
                "updateMask": "terraformBlueprint,serviceAccount,annotations",
                "requestId": request_id,
            },
            json=_deployment_body(mapped, deployment_name),
            timeout=60,
        )
        action = "update"
    else:
        return jsonify(
            {
                "error": "failed to inspect Infrastructure Manager deployment",
                "status": existing.status_code,
                "detail": existing.text,
            }
        ), 502

    try:
        result = response.json()
    except Exception:
        result = {"raw": response.text}

    if not response.ok:
        return jsonify(
            {
                "error": "Infrastructure Manager API request failed",
                "action": action,
                "status": response.status_code,
                "detail": result,
                "mappedVariables": mapped,
            }
        ), 502

    return jsonify(
        {
            "action": action,
            "deployment": deployment_name,
            "operation": result.get("name"),
            "mappedVariables": mapped,
            "infrastructureManagerResponse": result,
        }
    ), 202


@app.get("/status")
def status():
    operation = request.args.get("operation", "").strip()
    if not operation:
        return jsonify({"error": "operation query parameter is required"}), 400

    operation = operation.removeprefix("https://config.googleapis.com/v1/").lstrip("/")
    if "/operations/" not in operation:
        return jsonify({"error": "invalid Infrastructure Manager operation name"}), 400

    response = authed.get(f"{API_ROOT}/{operation}", timeout=30)
    try:
        body = response.json()
    except Exception:
        body = {"raw": response.text}
    return jsonify(body), response.status_code


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
