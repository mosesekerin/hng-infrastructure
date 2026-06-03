output "prometheus_config_path" {
  value       = local_file.prometheus_config.filename
  description = "Path to Prometheus config"
}

output "alert_rules_path" {
  value       = local_file.prometheus_alerts.filename
  description = "Path to alert rules"
}
