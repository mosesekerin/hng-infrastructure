output "instance_id" {
  value       = module.compute.instance_id
  description = "EC2 instance ID"
}

output "public_ip" {
  value       = module.compute.public_ip
  description = "Public IP address"
}

output "private_ip" {
  value       = module.compute.private_ip
  description = "Private IP address"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/hng-infrastructure.pem ubuntu@${module.compute.public_ip}"
  description = "SSH command to connect to instance"
}

output "vpc_id" {
  value       = module.networking.vpc_id
  description = "VPC ID"
}

output "security_group_id" {
  value       = module.security.security_group_id
  description = "Security group ID"
}

output "domain_name" {
  value       = var.enable_route53_dns ? var.domain_name : "Not configured"
  description = "Domain name"
}

output "prometheus_url" {
  value       = "http://${module.compute.public_ip}:9090"
  description = "Prometheus URL"
}

output "grafana_url" {
  value       = "http://${module.compute.public_ip}:3000"
  description = "Grafana URL (default credentials: admin/admin)"
}

output "node_exporter_url" {
  value       = "http://${module.compute.public_ip}:9100/metrics"
  description = "Node Exporter metrics URL"
}
