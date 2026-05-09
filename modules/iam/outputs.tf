output "gke_node_sa_email" {
  value = google_service_account.gke_nodes.email
}

output "eso_sa_email" {
  value = google_service_account.eso.email
}

output "eso_sa_name" {
  value = google_service_account.eso.name
}

output "terraform_sa_email" {
  value = google_service_account.terraform_ci.email
}

output "wif_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}
