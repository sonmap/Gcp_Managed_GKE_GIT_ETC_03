#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_ID:?Set PROJECT_ID to the Infrastructure Manager/platform project}"
: "${TARGET_PROJECT_ID:?Set TARGET_PROJECT_ID to the target project for the PoC BigQuery dataset}"
REGION="${REGION:-asia-northeast3}"
REPO_NAME="${REPO_NAME:-infra-poc}"

ADAPTER_SA_NAME="infra-adapter"
IM_EXEC_SA_NAME="infra-manager-exec"
ADAPTER_SA="${ADAPTER_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
IM_EXEC_SA="${IM_EXEC_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "== Enable required APIs =="
gcloud services enable \
  config.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  --project="${PROJECT_ID}"

gcloud services enable bigquery.googleapis.com --project="${TARGET_PROJECT_ID}"

echo "== Create service accounts if missing =="
gcloud iam service-accounts describe "${ADAPTER_SA}" --project="${PROJECT_ID}" >/dev/null 2>&1 || \
  gcloud iam service-accounts create "${ADAPTER_SA_NAME}" \
    --project="${PROJECT_ID}" \
    --display-name="Cloud Run Infrastructure Manager adapter"

gcloud iam service-accounts describe "${IM_EXEC_SA}" --project="${PROJECT_ID}" >/dev/null 2>&1 || \
  gcloud iam service-accounts create "${IM_EXEC_SA_NAME}" \
    --project="${PROJECT_ID}" \
    --display-name="Infrastructure Manager Terraform execution"

echo "== Cloud Run adapter -> Infrastructure Manager permissions =="
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${ADAPTER_SA}" \
  --role="roles/config.admin" \
  --quiet >/dev/null

gcloud iam service-accounts add-iam-policy-binding "${IM_EXEC_SA}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${ADAPTER_SA}" \
  --role="roles/iam.serviceAccountUser" \
  --quiet >/dev/null

echo "== Infrastructure Manager execution SA permissions =="
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${IM_EXEC_SA}" \
  --role="roles/config.agent" \
  --quiet >/dev/null

# PoC only: lets Terraform create/delete BigQuery datasets in the target project.
# Replace with a custom least-privilege role for production.
gcloud projects add-iam-policy-binding "${TARGET_PROJECT_ID}" \
  --member="serviceAccount:${IM_EXEC_SA}" \
  --role="roles/bigquery.admin" \
  --quiet >/dev/null

echo "== Artifact Registry repository =="
gcloud artifacts repositories describe "${REPO_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" >/dev/null 2>&1 || \
  gcloud artifacts repositories create "${REPO_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --repository-format=docker \
    --description="PoC images for VM-less analysis platform"

echo "== Grant current Cloud Build default SA image push/log permissions =="
BUILD_SA="$(gcloud builds get-default-service-account --project="${PROJECT_ID}" --format='value(serviceAccountEmail)' 2>/dev/null || true)"
if [[ -z "${BUILD_SA}" ]]; then
  # Some gcloud versions print the email directly without a field wrapper.
  BUILD_SA="$(gcloud builds get-default-service-account --project="${PROJECT_ID}" 2>/dev/null | tail -1 | tr -d '[:space:]' || true)"
fi
if [[ -n "${BUILD_SA}" && "${BUILD_SA}" == *"@"* ]]; then
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${BUILD_SA}" \
    --role="roles/artifactregistry.writer" \
    --quiet >/dev/null
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${BUILD_SA}" \
    --role="roles/logging.logWriter" \
    --quiet >/dev/null
else
  echo "WARNING: Could not resolve the Cloud Build default service account."
  echo "If image build fails, run: gcloud builds get-default-service-account --project=${PROJECT_ID}"
fi

cat <<EOF

Bootstrap complete.

Infrastructure Manager project : ${PROJECT_ID}
Target BigQuery project         : ${TARGET_PROJECT_ID}
Region                          : ${REGION}
Cloud Run runtime SA            : ${ADAPTER_SA}
Infra Manager execution SA      : ${IM_EXEC_SA}

Next:
  export PROJECT_ID=${PROJECT_ID}
  export TARGET_PROJECT_ID=${TARGET_PROJECT_ID}
  export REGION=${REGION}
  bash cloud-run-adapter/deploy.sh
EOF
