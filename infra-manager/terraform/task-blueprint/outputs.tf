output "dataset_id" {
  value       = google_bigquery_dataset.task.dataset_id
  description = "Created BigQuery dataset ID"
}

output "dataset_self_link" {
  value       = google_bigquery_dataset.task.self_link
  description = "Created BigQuery dataset self link"
}

output "namespace" {
  value       = kubernetes_namespace_v1.task.metadata[0].name
  description = "Created GKE namespace"
}

output "resource_quota" {
  value       = kubernetes_resource_quota_v1.task.metadata[0].name
  description = "Created Kubernetes ResourceQuota"
}
