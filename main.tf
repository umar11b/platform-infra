module "project_bootstrap" {
  source             = "./modules/project-bootstrap"
  project_id         = var.project_id
  region             = var.region
  billing_account_id = var.billing_account_id
}

module "network" {
  source     = "./modules/network"
  project_id = var.project_id
  region     = var.region
  depends_on = [module.project_bootstrap]
}

module "iam" {
  source       = "./modules/iam"
  project_id   = var.project_id
  github_owner = var.github_owner
  depends_on   = [module.project_bootstrap]
}

module "cluster" {
  source               = "./modules/cluster"
  project_id           = var.project_id
  zone                 = var.zone
  network              = module.network.network_name
  subnetwork           = module.network.subnetwork_name
  pod_range            = module.network.pod_range_name
  service_range        = module.network.service_range_name
  pi_public_ip         = var.pi_public_ip
  node_service_account = module.iam.gke_node_sa_email
  depends_on           = [module.network, module.iam]
}

module "dns" {
  source     = "./modules/dns"
  project_id = var.project_id
  domain     = var.domain
  depends_on = [module.project_bootstrap]
}
