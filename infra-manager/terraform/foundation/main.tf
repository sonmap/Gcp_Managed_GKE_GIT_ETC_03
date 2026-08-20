data "google_compute_network" "existing" {
  project = var.project_id
  name    = var.network_name
}

data "google_compute_subnetwork" "existing" {
  project = var.project_id
  region  = var.region
  name    = var.subnetwork_name
}

resource "google_container_cluster" "analysis" {
  project  = var.project_id
  name     = var.cluster_name
  location = var.region

  enable_autopilot = true

  network         = data.google_compute_network.existing.id
  subnetwork      = data.google_compute_subnetwork.existing.id
  networking_mode = "VPC_NATIVE"

  # Organization policy constraints/compute.vmExternalIpAccess is enforced in
  # this PoC project, so Autopilot nodes must not request external IP addresses.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  # Let GKE allocate/manage Pod and Service secondary ranges on the selected
  # subnet. This avoids hard-coding ranges that might overlap existing CIDRs.
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = ""
    services_ipv4_cidr_block = ""
  }

  release_channel {
    channel = upper(var.release_channel)
  }

  deletion_protection = false

  resource_labels = {
    managed_by = "terraform"
    purpose    = "analysis-poc"
  }
}
