variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "gke-infrastructure-493002"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the GKE cluster (zonal = free control plane)"
  type        = string
  default     = "us-central1-a"
}

variable "pi_public_ip" {
  description = "Public IP of the Raspberry Pi bastion, authorized to reach the GKE control plane. Run `curl ifconfig.me` on the Pi."
  type        = string
}

variable "domain" {
  description = "Root domain name"
  type        = string
  default     = "umarzaman.ca"
}

variable "billing_account_id" {
  description = "GCP billing account ID for budget alerts (format: XXXXXX-XXXXXX-XXXXXX). Leave empty to skip budget creation."
  type        = string
  default     = ""
}

variable "github_owner" {
  description = "GitHub username or org that owns the platform repos, used to scope Workload Identity Federation for GitHub Actions"
  type        = string
}
