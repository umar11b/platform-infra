resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = "platform-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "nodes" {
  project                  = var.project_id
  name                     = "platform-nodes"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.0.1.0/24"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }
}

resource "google_compute_router" "router" {
  project = var.project_id
  name    = "platform-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "platform-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "platform-allow-internal"
  network = google_compute_network.vpc.name

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }

  source_ranges = ["10.0.0.0/8"]
}

resource "google_compute_firewall" "allow_health_checks" {
  project = var.project_id
  name    = "platform-allow-health-checks"
  network = google_compute_network.vpc.name

  allow { protocol = "tcp" }

  # Google load balancer health check source ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}
