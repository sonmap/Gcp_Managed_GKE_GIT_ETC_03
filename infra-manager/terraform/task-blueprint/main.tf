locals {
  task_label  = substr(regexreplace(lower(var.task_id), "[^a-z0-9_-]", "_"), 0, 63)
  group_label = substr(regexreplace(lower(var.group), "[^a-z0-9_-]", "_"), 0, 63)
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
