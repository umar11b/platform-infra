# Run scripts/init-backend.sh once before `terraform init` to create this bucket.
terraform {
  backend "gcs" {
    bucket = "gke-infrastructure-493002-tfstate"
    prefix = "terraform/state"
  }
}
