#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-dev-com-334508}"
REGION="${REGION:-asia-northeast3}"
CLUSTER_NAME="${CLUSTER_NAME:-analysis-autopilot-a}"

cat <<EOF
This reset deletes PoC workload resources while preserving the bastion VM and
its required network/control-plane dependencies.

Project : ${PROJECT_ID}
Region  : ${REGION}
Delete  : Infrastructure Manager task-* deployments and their resources
          leftover BigQuery ds_task_* datasets
          GKE cluster ${CLUSTER_NAME}
Keep    : bastion VM, VPC, subnet, Cloud Run adapter, IAM/service accounts,
          Artifact Registry and enabled APIs
EOF

if [[ "${CONFIRM_DELETE:-}" != "YES" ]]; then
  echo
  echo "Safety stop. Re-run with CONFIRM_DELETE=YES when ready."
  exit 2
fi

echo "=== 1. Delete task Infrastructure Manager deployments ==="
mapfile -t deployments < <(
  gcloud infra-manager deployments list \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --format='value(name)' 2>/dev/null || true
)

for deployment in "${deployments[@]:-}"; do
  [[ -z "${deployment}" ]] && continue
  deployment_id="${deployment##*/}"
  if [[ "${deployment_id}" == task-* ]]; then
    echo "Deleting ${deployment_id} and managed resources..."
    gcloud infra-manager deployments delete "${deployment_id}" \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --delete-policy=delete \
      --quiet || true
  fi
done

echo "=== 2. Delete GKE cluster created manually in the old PoC ==="
if gcloud container clusters describe "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" >/dev/null 2>&1; then
  gcloud container clusters delete "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --quiet
else
  echo "Cluster ${CLUSTER_NAME} not found; skip."
fi

echo "=== 3. Remove leftover ds_task_* BigQuery datasets ==="
while read -r dataset; do
  [[ -z "${dataset}" ]] && continue
  echo "Deleting leftover dataset ${dataset}..."
  bq rm -r -f -d "${PROJECT_ID}:${dataset}" || true
done < <(
  bq ls --project_id="${PROJECT_ID}" 2>/dev/null \
    | awk 'NR>2 {print $1}' \
    | grep '^ds_task_' || true
)

echo "=== Reset complete ==="
echo "Preserved VM/network/control-plane resources."
echo "Next: terraform -chdir=infra-manager/terraform/foundation init && terraform -chdir=infra-manager/terraform/foundation apply"
