output "cluster_name" {
  description = "GKE cluster name"
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "GKE control plane endpoint (use via Pi only)"
  value       = module.cluster.cluster_endpoint
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Run this on the Pi to configure kubectl"
  value       = "gcloud container clusters get-credentials ${module.cluster.cluster_name} --zone ${var.zone} --project ${var.project_id}"
}

output "artifact_registry_url" {
  description = "Docker image push target"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/platform"
}

output "gke_node_sa_email" {
  description = "GKE node pool service account"
  value       = module.iam.gke_node_sa_email
}

output "eso_sa_email" {
  description = "ESO GCP service account (bind to Kubernetes SA via Workload Identity)"
  value       = module.iam.eso_sa_email
}

output "wif_provider" {
  description = "Workload Identity Federation provider — use as WIF_PROVIDER secret in GitHub Actions"
  value       = module.iam.wif_provider
}

output "cert_manager_sa_email" {
  description = "cert-manager GCP service account (DNS-01 via Workload Identity)"
  value       = module.iam.cert_manager_sa_email
}

output "terraform_sa_email" {
  description = "Terraform CI service account — use as TERRAFORM_SA_EMAIL secret in GitHub Actions"
  value       = module.iam.terraform_sa_email
}

output "lab_zone_name_servers" {
  description = "NS records for lab.umarzaman.ca — configure these at your registrar or Cloudflare to delegate the zone"
  value       = module.dns.name_servers
}
