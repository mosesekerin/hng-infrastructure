output "zone_id" {
  value       = data.aws_route53_zone.main.zone_id
  description = "Route 53 hosted zone ID"
}

output "a_record" {
  value       = aws_route53_record.main.fqdn
  description = "A record FQDN"
}
