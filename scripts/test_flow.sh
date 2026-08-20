#!/usr/bin/env bash
set -euo pipefail

: "${ADAPTER_URL:?Set ADAPTER_URL to the Cloud Run service URL}"
: "${TARGET_PROJECT_ID:?Set TARGET_PROJECT_ID to the target project}"
TASK_ID="${TASK_ID:-task-001}"
REGION="${REGION:-asia-northeast3}"

PAYLOAD=$(cat <<EOF
{
  "taskId": "${TASK_ID}",
  "taskName": "analysis-${TASK_ID}",
  "group": "a",
  "targetProjectId": "${TARGET_PROJECT_ID}",
  "location": "${REGION}"
}
EOF
)

echo "== Health =="
curl -fsS "${ADAPTER_URL}/health" | python3 -m json.tool

echo "== Deploy =="
RESPONSE="$(curl -fsS -X POST "${ADAPTER_URL}/deploy" \
  -H 'Content-Type: application/json' \
  -d "${PAYLOAD}")"
echo "${RESPONSE}" | python3 -m json.tool

OPERATION="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("operation", ""))' <<<"${RESPONSE}")"
if [[ -n "${OPERATION}" ]]; then
  echo
  echo "Operation: ${OPERATION}"
  echo "Check status with:"
  echo "curl -G '${ADAPTER_URL}/status' --data-urlencode 'operation=${OPERATION}'"
fi
