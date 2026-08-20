output "cluster_name" {
  description = "Created GKE Autopilot cluster name"
  value       = google_container_cluster.analysis.name
}

output "cluster_location" {
  description = "Created GKE Autopilot cluster location"
  value       = google_container_cluster.analysis.location
}

output "network" {
  description = "Existing VPC used by the cluster"
  value       = data.google_compute_network.existing.name
}

output "subnetwork" {
  description = "Existing subnet used by the cluster"
  value       = data.google_compute_subnetwork.existing.name
}

output "private_nodes" {
  description = "Whether cluster nodes are private"
  value       = google_container_cluster.analysis.private_cluster_config[0].enable_private_nodes
}
