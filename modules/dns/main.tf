resource "google_dns_managed_zone" "lab" {
  project     = var.project_id
  name        = "lab-zone"
  dns_name    = "lab.${var.domain}."
  description = "Public zone for lab.${var.domain}. Delegate NS records to Cloudflare for DNS-01 cert-manager challenges."
  visibility  = "public"
}
