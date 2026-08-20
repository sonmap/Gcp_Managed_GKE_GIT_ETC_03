#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_ID:?Set PROJECT_ID to the Infrastructure Manager/platform project}"
: "${TARGET_PROJECT_ID:?Set TARGET_PROJECT_ID to the project where task resources will be created}"
REGION="${REGION:-asia-northeast3}"
REPO_NAME="${REPO_NAME:-infra-poc}"
SERVICE_NAME="${SERVICE_NAME:-infra-manager-adapter}"
ADAPTER_SA="infra-adapter@${PROJECT_ID}.iam.gserviceaccount.com"
IM_EXEC_SA="infra-manager-exec@${PROJECT_ID}.iam.gserviceaccount.com"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/cloud-run-adapter:latest"

GKE_PROJECT_ID="${GKE_PROJECT_ID:-${PROJECT_ID}}"
GKE_LOCATION="${GKE_LOCATION:-${REGION}}"
GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME:-analysis-autopilot-a}"
GKE_NETWORK_NAME="${GKE_NETWORK_NAME:-managed02-dev-vpc}"
GKE_SUBNETWORK_NAME="${GKE_SUBNETWORK_NAME:-managed02-dev-subnet}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/3] Build adapter container with regional Cloud Build"
gcloud builds submit "${SCRIPT_DIR}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --tag="${IMAGE}"

echo "[2/3] Deploy adapter to Cloud Run"
gcloud run deploy "${SERVICE_NAME}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --image="${IMAGE}" \
  --service-account="${ADAPTER_SA}" \
  --allow-unauthenticated \
  --timeout=900 \
  --set-env-vars="IM_PROJECT_ID=${PROJECT_ID},IM_LOCATION=${REGION},IM_SERVICE_ACCOUNT=projects/${PROJECT_ID}/serviceAccounts/${IM_EXEC_SA},DEFAULT_TARGET_PROJECT_ID=${TARGET_PROJECT_ID},TF_REPO_URL=https://github.com/sonmap/Gcp_Managed_GKE_GIT_ETC_03.git,TF_REPO_REF=main,TF_DIRECTORY=infra-manager/terraform/task-blueprint,FOUNDATION_TF_DIRECTORY=infra-manager/terraform/foundation,FOUNDATION_DEPLOYMENT_ID=foundation-analysis,GKE_PROJECT_ID=${GKE_PROJECT_ID},GKE_LOCATION=${GKE_LOCATION},GKE_CLUSTER_NAME=${GKE_CLUSTER_NAME},GKE_NETWORK_NAME=${GKE_NETWORK_NAME},GKE_SUBNETWORK_NAME=${GKE_SUBNETWORK_NAME},FOUNDATION_WAIT_SECONDS=780,FOUNDATION_POLL_SECONDS=10"

echo "[3/3] Cloud Run URL"
gcloud run services describe "${SERVICE_NAME}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='value(status.url)'

echo
cat <<'EOF'
PoC orchestration:
Java Portal -> Cloud Run Adapter -> Infrastructure Manager foundation Terraform
            -> GKE Autopilot -> Infrastructure Manager task Terraform
            -> BigQuery Dataset + Namespace + ResourceQuota

NOTE: --allow-unauthenticated is for this isolated PoC only.
For production, require authentication and use an approved identity/internal access path.
EOF
