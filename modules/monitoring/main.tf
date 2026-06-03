# Monitoring module - Installs Prometheus, Grafana, Node Exporter
# Note: All installation happens in user_data in compute module
# This module just provides configuration files

resource "local_file" "prometheus_config" {
  filename = "${path.module}/prometheus.yml"
  content  = templatefile("${path.module}/templates/prometheus.yml.tpl", {
    domain_name = var.domain_name
  })
}

resource "local_file" "prometheus_alerts" {
  filename = "${path.module}/alert_rules.yml"
  content  = file("${path.module}/templates/alert_rules.yml")
}

resource "local_file" "grafana_dashboard_system" {
  filename = "${path.module}/grafana_dashboard_system.json"
  content  = file("${path.module}/templates/grafana_dashboard_system.json")
}

resource "local_file" "grafana_dashboard_nginx" {
  filename = "${path.module}/grafana_dashboard_nginx.json"
  content  = file("${path.module}/templates/grafana_dashboard_nginx.json")
}
