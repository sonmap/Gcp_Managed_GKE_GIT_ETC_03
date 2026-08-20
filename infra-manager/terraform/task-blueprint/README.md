# Infrastructure Manager task blueprint

This root module is intentionally small for the first PoC. It proves that:

`Cloud Run adapter -> config.googleapis.com -> Infrastructure Manager -> Terraform -> target GCP project`

works before GKE/Shared VPC resources are added.

The current resource is one BigQuery dataset per approved task. The same deployment can later be extended with namespace/IAM/Workload Identity modules.

## Direct control test without Java/Cloud Run

Use this if you want to verify Infrastructure Manager independently first.

```bash
export IM_PROJECT_ID=<infra-manager-project>
export TARGET_PROJECT_ID=<target-project>
export REGION=asia-northeast3
export IM_EXEC_SA=infra-manager-exec@${IM_PROJECT_ID}.iam.gserviceaccount.com

gcloud infra-manager deployments apply \
  projects/${IM_PROJECT_ID}/locations/${REGION}/deployments/task-direct-001 \
  --service-account=projects/${IM_PROJECT_ID}/serviceAccounts/${IM_EXEC_SA} \
  --git-source-repo=https://github.com/sonmap/Gcp_Managed_GKE_GIT_ETC_03.git \
  --git-source-directory=infra-manager/terraform/task-blueprint \
  --git-source-ref=main \
  --input-values=target_project_id=${TARGET_PROJECT_ID},task_id=task-direct-001,task_name=direct-test,group=a,dataset_id=ds_task_direct_001,bq_location=${REGION}
```

Check:

```bash
gcloud infra-manager deployments describe \
  projects/${IM_PROJECT_ID}/locations/${REGION}/deployments/task-direct-001

bq --project_id=${TARGET_PROJECT_ID} show ds_task_direct_001
```

## Variables

- `target_project_id`: BigQuery group/target project
- `task_id`: legacy task ID
- `task_name`: task display name
- `group`: task group code
- `dataset_id`: per-task dataset ID
- `bq_location`: BigQuery location
