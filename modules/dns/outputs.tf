output "name_servers" {
  description = "Configure these NS records at your registrar for lab.umarzaman.ca to delegate to Cloud DNS (then optionally re-delegate to Cloudflare)"
  value       = google_dns_managed_zone.lab.name_servers
}
