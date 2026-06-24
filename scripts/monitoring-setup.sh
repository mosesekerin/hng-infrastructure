#!/bin/bash
set -e

# Monitoring Stack Installation Script (CORRECTED)
# Downloaded and executed by user_data.sh
# Fixes: Grafana symlinks + systemd service paths

exec > >(tee /var/log/monitoring-setup.log)
exec 2>&1

echo "=== Monitoring Stack Setup Starting ==="
echo "Timestamp: $(date)"

# ============================================================
# SECTION 1: PROMETHEUS INSTALLATION
# ============================================================

echo ""
echo "=== Step 1: Installing Prometheus ==="

# Create prometheus user
useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true

# Create directories
mkdir -p /var/lib/prometheus
mkdir -p /etc/prometheus
chown prometheus:prometheus /var/lib/prometheus

# Download and install Prometheus
PROM_VERSION="2.45.0"
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar xzf prometheus-${PROM_VERSION}.linux-amd64.tar.gz

cp prometheus-${PROM_VERSION}.linux-amd64/prometheus /usr/local/bin/
cp prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

cd /

# Create Prometheus config
cat > /etc/prometheus/prometheus.yml << 'PROM_CONFIG'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'hng-infrastructure'

alerting:
  alertmanagers: []

rule_files:
  - '/etc/prometheus/alert_rules.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
PROM_CONFIG

chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Create alert rules
cat > /etc/prometheus/alert_rules.yml << 'ALERT_RULES'
groups:
  - name: system_alerts
    interval: 15s
    rules:
      - alert: HighCPU
        expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
        for: 5m
        annotations:
          summary: "High CPU: {{ $value | humanize }}%"

      - alert: CriticalCPU
        expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 95
        for: 2m
        annotations:
          summary: "Critical CPU: {{ $value | humanize }}%"

      - alert: LowMemory
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 20
        for: 5m
        annotations:
          summary: "Low memory: {{ $value | humanize }}%"

      - alert: CriticalMemory
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10
        for: 2m
        annotations:
          summary: "Critical memory: {{ $value | humanize }}%"

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{fstype=~"ext4|xfs"} / node_filesystem_size_bytes{fstype=~"ext4|xfs"}) * 100 < 15
        for: 5m
        annotations:
          summary: "Low disk: {{ $value | humanize }}%"

      - alert: CriticalDiskSpace
        expr: (node_filesystem_avail_bytes{fstype=~"ext4|xfs"} / node_filesystem_size_bytes{fstype=~"ext4|xfs"}) * 100 < 5
        for: 2m
        annotations:
          summary: "Critical disk: {{ $value | humanize }}%"

      - alert: HighLoadAverage
        expr: node_load15 > 4
        for: 5m
        annotations:
          summary: "High load: {{ $value | humanize }}"

      - alert: NetworkInterfaceDown
        expr: node_network_up{device!~"lo|docker.*"} == 0
        for: 2m
        annotations:
          summary: "Network interface {{ $labels.device }} down"

      - alert: HighNetworkTraffic
        expr: rate(node_network_receive_bytes_total[5m]) > 100000000
        for: 5m
        annotations:
          summary: "High network traffic: {{ $value | humanize }} bytes/sec"
ALERT_RULES

chown prometheus:prometheus /etc/prometheus/alert_rules.yml

# Create systemd service
cat > /etc/systemd/system/prometheus.service << 'PROM_SERVICE'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
PROM_SERVICE

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

echo "✅ Prometheus installed and running (port 9090)"

# ============================================================
# SECTION 2: NODE EXPORTER INSTALLATION
# ============================================================

echo ""
echo "=== Step 2: Installing Node Exporter ==="

# Create user
useradd --no-create-home --shell /bin/false nodeexporter 2>/dev/null || true

# Download and install
NODE_EXPORTER_VERSION="1.6.1"
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
chown nodeexporter:nodeexporter /usr/local/bin/node_exporter

# Create systemd service
cat > /etc/systemd/system/node_exporter.service << 'NODE_EXPORTER_SERVICE'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=nodeexporter
Group=nodeexporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
NODE_EXPORTER_SERVICE

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "✅ Node Exporter installed and running (port 9100)"

# ============================================================
# SECTION 3: GRAFANA INSTALLATION (Binary Method + Auto Provisioning) - CORRECTED
# ============================================================

echo ""
echo "=== Step 3: Installing Grafana with Auto-Provisioned Dashboards ==="

# Download Grafana binary
cd /tmp
wget https://dl.grafana.com/oss/release/grafana-10.2.0.linux-amd64.tar.gz
tar -xzf grafana-10.2.0.linux-amd64.tar.gz

# Create grafana user
useradd --system --no-create-home --shell /bin/false grafana 2>/dev/null || true

# Remove any existing Grafana installation (handles re-runs on same server)
rm -rf /opt/grafana

# Move to /opt (this creates /opt/grafana/ with bin/, conf/, etc. at top level)
mv grafana-10.2.0 /opt/grafana
chown -R grafana:grafana /opt/grafana

# Verify binary exists
if [ ! -f /opt/grafana/bin/grafana-server ]; then
  echo "❌ ERROR: Grafana binary not found at /opt/grafana/bin/grafana-server"
  exit 1
fi

echo "✅ Grafana binary verified at /opt/grafana/bin/grafana-server"

# Create Grafana provisioning directories
mkdir -p /etc/grafana/provisioning/dashboards
mkdir -p /etc/grafana/provisioning/datasources
mkdir -p /opt/grafana/dashboards

# Create datasources provisioning config
cat > /etc/grafana/provisioning/datasources/prometheus.yml << 'DATASOURCES_CONFIG'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
DATASOURCES_CONFIG

# Create dashboards provisioning config
cat > /etc/grafana/provisioning/dashboards/dashboards.yml << 'DASHBOARDS_CONFIG'
apiVersion: 1

providers:
  - name: 'System Dashboards'
    orgId: 1
    folder: 'System'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /opt/grafana/dashboards
DASHBOARDS_CONFIG

# Create System Health Dashboard
cat > /opt/grafana/dashboards/system-health.json << 'SYSTEM_DASHBOARD'
{
  "annotations": {"list": []},
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "thresholds"},
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 70},
              {"color": "red", "value": 90}
            ]
          },
          "unit": "percent"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
      "id": 2,
      "targets": [
        {
          "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "refId": "A"
        }
      ],
      "title": "CPU Usage",
      "type": "gauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "thresholds"},
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 70},
              {"color": "red", "value": 90}
            ]
          },
          "unit": "percent"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
      "id": 3,
      "targets": [
        {
          "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
          "refId": "A"
        }
      ],
      "title": "Memory Usage",
      "type": "gauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "palette-classic"},
          "custom": {
            "axisLabel": "",
            "drawStyle": "line",
            "fillOpacity": 10,
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "showPoints": "never",
            "spanNulls": true
          },
          "unit": "short"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
      "id": 4,
      "targets": [
        {"expr": "node_load1", "legendFormat": "1m", "refId": "A"},
        {"expr": "node_load5", "legendFormat": "5m", "refId": "B"},
        {"expr": "node_load15", "legendFormat": "15m", "refId": "C"}
      ],
      "title": "System Load",
      "type": "timeseries"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "thresholds"},
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 70},
              {"color": "red", "value": 85}
            ]
          },
          "unit": "percent"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
      "id": 5,
      "targets": [
        {
          "expr": "(1 - (node_filesystem_avail_bytes{fstype=~\"ext4|xfs\"} / node_filesystem_size_bytes{fstype=~\"ext4|xfs\"})) * 100",
          "refId": "A"
        }
      ],
      "title": "Disk Usage",
      "type": "gauge"
    }
  ],
  "schemaVersion": 27,
  "style": "dark",
  "tags": ["system", "monitoring"],
  "templating": {"list": []},
  "time": {"from": "now-1h", "to": "now"},
  "timezone": "",
  "title": "System Health",
  "uid": "system-health",
  "version": 0
}
SYSTEM_DASHBOARD

# Create Network Metrics Dashboard
cat > /opt/grafana/dashboards/network-metrics.json << 'NETWORK_DASHBOARD'
{
  "annotations": {"list": []},
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "palette-classic"},
          "custom": {
            "axisLabel": "Bytes/sec",
            "drawStyle": "line",
            "fillOpacity": 10,
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "showPoints": "never",
            "spanNulls": true
          },
          "unit": "Bps"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
      "id": 2,
      "targets": [
        {
          "expr": "rate(node_network_receive_bytes_total{device=\"eth0\"}[5m])",
          "legendFormat": "Receive",
          "refId": "A"
        }
      ],
      "title": "Network Receive Rate",
      "type": "timeseries"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "palette-classic"},
          "custom": {
            "axisLabel": "Bytes/sec",
            "drawStyle": "line",
            "fillOpacity": 10,
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "showPoints": "never",
            "spanNulls": true
          },
          "unit": "Bps"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
      "id": 3,
      "targets": [
        {
          "expr": "rate(node_network_transmit_bytes_total{device=\"eth0\"}[5m])",
          "legendFormat": "Transmit",
          "refId": "A"
        }
      ],
      "title": "Network Transmit Rate",
      "type": "timeseries"
    }
  ],
  "schemaVersion": 27,
  "style": "dark",
  "tags": ["network", "monitoring"],
  "templating": {"list": []},
  "time": {"from": "now-1h", "to": "now"},
  "timezone": "",
  "title": "Network Metrics",
  "uid": "network-metrics",
  "version": 0
}
NETWORK_DASHBOARD

# Fix permissions
chown -R grafana:grafana /etc/grafana
chown -R grafana:grafana /opt/grafana

# FIX: Correct systemd service with proper paths
cat > /etc/systemd/system/grafana-server.service << 'GRAFANA_SERVICE'
[Unit]
Description=Grafana
Documentation=https://grafana.com/docs/grafana/latest/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=grafana
Group=grafana
WorkingDirectory=/opt/grafana
ExecStart=/opt/grafana/bin/grafana-server \
  --config=/opt/grafana/conf/defaults.ini \
  --homepath=/opt/grafana

Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=grafana

LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
GRAFANA_SERVICE

# Start Grafana
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

echo "✅ Grafana installed with auto-provisioned dashboards"
echo "   Dashboards will be available after Grafana starts"