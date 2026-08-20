output "dataset_id" {
  value       = google_bigquery_dataset.task.dataset_id
  description = "Created BigQuery dataset ID"
}

output "dataset_self_link" {
  value       = google_bigquery_dataset.task.self_link
  description = "Created BigQuery dataset self link"
}
