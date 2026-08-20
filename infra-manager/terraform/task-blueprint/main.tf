resource "google_bigquery_dataset" "task" {
  project                     = var.target_project_id
  dataset_id                  = var.dataset_id
  friendly_name               = var.task_name
  description                 = "PoC dataset for ${var.task_id}; provisioned by Infrastructure Manager"
  location                    = var.bq_location
  delete_contents_on_destroy  = true

  labels = {
    managed_by = "infra-manager"
    task_id    = replace(lower(var.task_id), "-", "_")
    task_group = lower(var.group)
  }
}
