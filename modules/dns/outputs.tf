output "zone_id" {
  value       = data.aws_route53_zone.main.zone_id
  description = "Route 53 hosted zone ID"
}

output "a_record" {
  value       = var.create_dns ? aws_route53_record.infra[0].fqdn : ""
  description = "A record FQDN"
}

output "infra_fqdn" {
  description = "FQDN of the infra subdomain"
  value       = var.create_dns ? aws_route53_record.infra[0].fqdn : ""
}

output "infra_ip" {
  description = "IP address that infra domain resolves to"
  value       = var.create_dns ? tolist(aws_route53_record.infra[0].records)[0] : ""
}
