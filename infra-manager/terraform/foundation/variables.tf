variable "project_id" {
  description = "GCP project that owns the shared GKE foundation"
  type        = string
  default     = "dev-com-334508"
}

variable "region" {
  description = "GCP region for the regional Autopilot cluster"
  type        = string
  default     = "asia-northeast3"
}

variable "network_name" {
  description = "Existing VPC that must be preserved with the bastion VM"
  type        = string
  default     = "managed02-dev-vpc"
}

variable "subnetwork_name" {
  description = "Existing subnet that must be preserved with the bastion VM"
  type        = string
  default     = "managed02-dev-subnet"
}

variable "cluster_name" {
  description = "Shared GKE Autopilot cluster for analysis tasks"
  type        = string
  default     = "analysis-autopilot-a"
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], upper(var.release_channel))
    error_message = "release_channel must be RAPID, REGULAR, STABLE, or UNSPECIFIED."
  }
}
