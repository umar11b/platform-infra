output "network_name" {
  value = google_compute_network.vpc.name
}

output "subnetwork_name" {
  value = google_compute_subnetwork.nodes.name
}

output "pod_range_name" {
  value = "pods"
}

output "service_range_name" {
  value = "services"
}
