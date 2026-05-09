variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "pod_range" {
  type = string
}

variable "service_range" {
  type = string
}

variable "pi_public_ip" {
  type        = string
  description = "Public IP of the Pi bastion, authorized to the GKE control plane"
}

variable "node_service_account" {
  type        = string
  description = "Email of the GKE node pool service account"
}
