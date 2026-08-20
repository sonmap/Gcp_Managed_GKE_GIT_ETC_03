# Gcp_Managed_GKE_GIT_ETC_03

PoC for migrating a legacy Java portal's direct Google Cloud REST provisioning to:

`Java Portal -> Cloud Run Adapter -> Infrastructure Manager REST API -> Terraform -> Google Cloud resource`

## PoC flow

1. User accesses the Java portal through Nginx on `192.168.142.101`.
2. The portal submits the existing-style JSON request to the Cloud Run adapter.
3. The adapter keeps the portal contract isolated from Google Cloud provisioning logic and maps JSON fields to Terraform input variables.
4. The adapter calls Infrastructure Manager at `https://config.googleapis.com`.
5. Infrastructure Manager reads the Terraform blueprint from this public GitHub repository and creates a test BigQuery dataset.
6. The portal receives the Infrastructure Manager long-running operation name and can query its status.

## Repository layout

```text
portal-java/                       Java sample portal for 192.168.142.101
  deploy/                          Nginx and VM installation files
cloud-run-adapter/                 Step 7 mapping adapter on Cloud Run
infra-manager/terraform/
  task-blueprint/                  Terraform root module run by Infra Manager
scripts/                           GCP bootstrap/deploy helper scripts
examples/                          Sample legacy JSON request
```

## Important design point

The Java portal does **not** call individual GCP resource APIs. It only calls the Cloud Run adapter. The adapter calls the Infrastructure Manager API, and Infrastructure Manager executes the Terraform blueprint. This keeps Terraform state/revisions in Infrastructure Manager and removes resource-specific GCP API calls from the portal.

## Quick test sequence

### 1. Bootstrap GCP

```bash
export PROJECT_ID=<infra-manager-project-id>
export TARGET_PROJECT_ID=<project-that-will-own-test-dataset>
export REGION=asia-northeast3
bash scripts/bootstrap_gcp.sh
```

### 2. Deploy the Cloud Run adapter

```bash
export PROJECT_ID=<infra-manager-project-id>
export TARGET_PROJECT_ID=<project-that-will-own-test-dataset>
export REGION=asia-northeast3
bash cloud-run-adapter/deploy.sh
```

Copy the Cloud Run URL printed by the script.

### 3. Install the Java portal on 192.168.142.101

Run on that VM:

```bash
git clone https://github.com/sonmap/Gcp_Managed_GKE_GIT_ETC_03.git
cd Gcp_Managed_GKE_GIT_ETC_03
sudo CLOUD_RUN_ADAPTER_URL=https://<cloud-run-url> bash portal-java/deploy/install_vm.sh
```

Then browse to:

```text
http://192.168.142.101/
```

### 4. Submit a request

The sample portal posts JSON to `/api/tasks`. The Java backend forwards the request body to Cloud Run without changing the JSON schema.

Example:

```json
{
  "taskId": "task-001",
  "taskName": "analysis-demo-001",
  "group": "a",
  "targetProjectId": "my-target-project",
  "location": "asia-northeast3"
}
```

The Terraform PoC creates a BigQuery dataset named `ds_task_001` in the requested target project.

## IAM summary

Cloud Run runtime service account:
- `roles/config.admin` on the Infrastructure Manager project
- `roles/iam.serviceAccountUser` on the Infra Manager execution service account

Infrastructure Manager execution service account:
- `roles/config.agent` on the Infrastructure Manager project
- `roles/bigquery.admin` on the target project for this PoC

For production, replace broad PoC permissions with custom/minimum roles.

## Notes

- `config.googleapis.com` is the Infrastructure Manager API endpoint.
- Infrastructure Manager reads `infra-manager/terraform/task-blueprint` from this repository.
- Because this repository is public, the PoC can use Infra Manager `gitSource` directly. For a private repository, connect the Git provider as required by Infrastructure Manager/Cloud Build.
- The VM installation cannot be performed remotely by this repository; `portal-java/deploy/install_vm.sh` is provided to run on `192.168.142.101`.
