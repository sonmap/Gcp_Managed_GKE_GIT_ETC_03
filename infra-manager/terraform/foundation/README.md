# Foundation Terraform

This root module creates the shared GKE Autopilot foundation without using `gcloud container clusters create-auto`.

It intentionally **does not create or delete the bastion VM, VPC, or subnet**. The existing network resources are read as data sources because the bastion VM depends on them.

## Managed by this module

- GKE Autopilot cluster: `analysis-autopilot-a`
- Regional cluster in `asia-northeast3`
- Existing VPC: `managed02-dev-vpc`
- Existing subnet: `managed02-dev-subnet`
- Private GKE nodes to comply with `constraints/compute.vmExternalIpAccess`
- GKE-managed Pod/Service secondary IP ranges

## Apply

```bash
terraform -chdir=infra-manager/terraform/foundation init
terraform -chdir=infra-manager/terraform/foundation plan
terraform -chdir=infra-manager/terraform/foundation apply
```

The defaults already target the PoC project. Override them with `-var` when needed.

Example:

```bash
terraform -chdir=infra-manager/terraform/foundation apply \
  -var='project_id=dev-com-334508' \
  -var='region=asia-northeast3' \
  -var='network_name=managed02-dev-vpc' \
  -var='subnetwork_name=managed02-dev-subnet' \
  -var='cluster_name=analysis-autopilot-a'
```

## Destroy

Only resources in this Terraform state are destroyed. The bastion VM and existing VPC/subnet are not in this state.

```bash
terraform -chdir=infra-manager/terraform/foundation destroy
```

After the cluster exists, `infra-manager/terraform/task-blueprint` creates task resources such as BigQuery datasets, Kubernetes namespaces, and ResourceQuota objects.
