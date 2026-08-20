# Gcp_Managed_GKE_GIT_ETC_03

PoC for migrating a legacy Java portal's direct Google Cloud REST provisioning to:

`Java Portal -> Cloud Run Adapter -> Infrastructure Manager REST API -> Terraform -> Google Cloud resources`

## Current architecture

The PoC is split into two Terraform layers.

```text
1. Foundation Terraform (run once)
   existing VPC/Subnet -> GKE Autopilot private cluster

2. Task Terraform (run for every approved task)
   BigQuery Dataset + GKE Namespace + ResourceQuota
```

The bastion VM and its VPC/subnet are intentionally outside Terraform state so they can be preserved during PoC resets.

## Repository layout

```text
portal-java/                       Java sample portal
cloud-run-adapter/                 Legacy JSON -> Terraform input adapter
infra-manager/terraform/
  foundation/                      Terraform-only GKE Autopilot creation
  task-blueprint/                  Per-task BigQuery + Namespace + ResourceQuota
scripts/
  bootstrap_gcp.sh                 Initial API/IAM bootstrap
  reset_poc_workloads.sh           Reset PoC resources but preserve VM/control plane
  test_flow.sh                     Adapter/portal test helper
examples/                          Sample legacy JSON request
```

## Foundation: create GKE with Terraform only

`infra-manager/terraform/foundation` creates `analysis-autopilot-a` without running `gcloud container clusters create-auto`.

It uses the existing PoC network:

- Project: `dev-com-334508`
- Region: `asia-northeast3`
- VPC: `managed02-dev-vpc`
- Subnet: `managed02-dev-subnet`
- Cluster: `analysis-autopilot-a`
- Autopilot: enabled
- Private nodes: enabled, so nodes do not require external IP addresses
- Pod/Service ranges: GKE-managed secondary ranges

Apply:

```bash
terraform -chdir=infra-manager/terraform/foundation init
terraform -chdir=infra-manager/terraform/foundation plan
terraform -chdir=infra-manager/terraform/foundation apply
```

Destroy only the foundation resources managed by this Terraform state:

```bash
terraform -chdir=infra-manager/terraform/foundation destroy
```

The bastion VM, VPC, and subnet are not destroyed because the foundation module reads those network resources as data sources.

## Task provisioning flow

1. User accesses the Java portal through Nginx.
2. The portal submits the existing-style JSON request to the Cloud Run adapter.
3. The adapter forwards the legacy contract unchanged and maps fields to Terraform variables.
4. The adapter calls Infrastructure Manager at `https://config.googleapis.com`.
5. Infrastructure Manager reads `infra-manager/terraform/task-blueprint` from GitHub.
6. Terraform creates the task BigQuery dataset, Kubernetes namespace, and ResourceQuota.

Example request:

```json
{
  "taskId": "task-005",
  "taskName": "analysis-task-005",
  "group": "a",
  "targetProjectId": "dev-com-334508",
  "location": "asia-northeast3"
}
```

Expected resources:

```text
ds_task_005
analysis-autopilot-a
  └─ namespace task-005
      └─ ResourceQuota task-quota
```

## Reset before a fresh test

To remove the PoC workload resources while preserving the bastion VM and the resources required to reach/rebuild the environment:

```bash
export CONFIRM_DELETE=YES
bash scripts/reset_poc_workloads.sh
```

The reset deletes:

- Infrastructure Manager deployments named `task-*` and their managed resources
- GKE cluster `analysis-autopilot-a` from the old/manual PoC
- leftover BigQuery datasets named `ds_task_*`

The reset preserves:

- bastion VM
- `managed02-dev-vpc`
- `managed02-dev-subnet`
- Cloud Run adapter
- Infrastructure Manager/Cloud Run service accounts and IAM bootstrap
- Artifact Registry
- enabled APIs

This preservation is intentional: deleting the VPC/subnet would break the VM, and deleting the Cloud Run/IAM control plane would prevent the existing portal workflow from creating new task deployments.

## IAM summary

Cloud Run runtime service account:
- `roles/config.admin` on the Infrastructure Manager project
- `roles/iam.serviceAccountUser` on the Infrastructure Manager execution service account

Infrastructure Manager execution service account for task deployments:
- `roles/config.agent`
- `roles/bigquery.admin` for this PoC
- `roles/container.admin` for Kubernetes/GKE API access
- `roles/compute.viewer` for GKE backing resource discovery

For production, replace broad PoC permissions with custom/minimum roles.

## Important design point

The Java portal does **not** call individual Google Cloud resource APIs. It calls the Cloud Run adapter. The adapter calls Infrastructure Manager, and Infrastructure Manager executes the task Terraform blueprint. GKE foundation creation is now also represented as Terraform code, but remains a separate one-time lifecycle from per-task provisioning.
