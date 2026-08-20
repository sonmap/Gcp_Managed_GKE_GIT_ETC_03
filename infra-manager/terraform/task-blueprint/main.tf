locals {
  task_label       = substr(replace(lower(var.task_id), "/[^a-z0-9_-]/", "_"), 0, 63)
  group_label      = substr(replace(lower(var.group), "/[^a-z0-9_-]/", "_"), 0, 63)
  namespace_name   = substr(trim(replace(lower(var.task_id), "/[^a-z0-9-]/", "-"), "-"), 0, 63)
  gke_project_id   = var.gke_project_id != "" ? var.gke_project_id : var.target_project_id
}

resource "google_bigquery_dataset" "task" {
  project                    = var.target_project_id
  dataset_id                 = var.dataset_id
  friendly_name              = var.task_name
  description                = "PoC dataset for ${var.task_id}; provisioned by Infrastructure Manager"
  location                   = var.bq_location
  delete_contents_on_destroy = true

  labels = {
    managed_by = "infra-manager"
    task_id    = local.task_label
    task_group = local.group_label
  }
}

resource "kubernetes_namespace_v1" "task" {
  metadata {
    name = local.namespace_name

    labels = {
      "managed-by" = "infra-manager"
      "task-id"    = local.namespace_name
      "task-group" = local.group_label
    }
  }
}

resource "kubernetes_resource_quota_v1" "task" {
  metadata {
    name      = "task-quota"
    namespace = kubernetes_namespace_v1.task.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "8"
      "requests.memory" = "32Gi"
      "limits.cpu"      = "16"
      "limits.memory"   = "64Gi"
      "pods"            = "20"
    }
  }
}
