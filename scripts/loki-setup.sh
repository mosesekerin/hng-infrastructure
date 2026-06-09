#!/bin/bash
set -e

# Loki Stack Installation Script
# Downloaded and executed by user_data.sh
# Installs: Loki (log aggregation) + Promtail (log shipper)

exec > >(tee /var/log/loki-setup.log)
exec 2>&1

echo "=== Loki & Promtail Setup Starting ==="
echo "Timestamp: $(date)"

# ============================================================
# SECTION 1: LOKI INSTALLATION
# ============================================================

echo ""
echo "=== Step 1: Installing Loki (Log Aggregation Engine) ==="

# Create loki user
useradd --no-create-home --shell /bin/false loki 2>/dev/null || true

# Create directories
mkdir -p /var/lib/loki
mkdir -p /etc/loki
chown loki:loki /var/lib/loki
chown loki:loki /etc/loki

# Download and install Loki binary
LOKI_VERSION="2.9.4"
cd /tmp
wget https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip
unzip -o loki-linux-amd64.zip

cp loki-linux-amd64 /usr/local/bin/loki
chmod +x /usr/local/bin/loki
chown loki:loki /usr/local/bin/loki

cd /

# Create Loki configuration file
cat > /etc/loki/loki-config.yml << 'LOKI_CONFIG'
auth_enabled: false

ingester:
  chunk_idle_period: 3m
  chunk_retain_period: 1m
  max_chunk_age: 1h
  chunk_size_target: 1048576
  enforce_metric_name: false
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    num_tokens: 128
    heartbeat_timeout: 5m

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
  max_streams_per_user: 10000

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

server:
  http_listen_port: 3100
  log_level: info

storage_config:
  boltdb_shipper:
    active_index_directory: /var/lib/loki/boltdb-shipper-active
    shared_store: filesystem
  filesystem:
    directory: /var/lib/loki/chunks

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s

retention_config:
  enabled: true
  default_days: 30
LOKI_CONFIG

chown loki:loki /etc/loki/loki-config.yml

# Create Loki systemd service
cat > /etc/systemd/system/loki.service << 'LOKI_SERVICE'
[Unit]
Description=Loki Log Aggregation Engine
Wants=network-online.target
After=network-online.target

[Service]
User=loki
Group=loki
Type=simple
ExecStart=/usr/local/bin/loki \
  -config.file=/etc/loki/loki-config.yml

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
LOKI_SERVICE

systemctl daemon-reload
systemctl enable loki
systemctl start loki

sleep 3  # Wait for Loki to start

echo "✅ Loki installed and running (port 3100)"

# ============================================================
# SECTION 2: LOKI DATASOURCE PROVISIONING IN GRAFANA
# ============================================================

echo ""
echo "=== Step 2: Provisioning Loki Datasource in Grafana ==="

# Add Loki to Grafana datasources provisioning
cat >> /etc/grafana/provisioning/datasources/prometheus.yml << 'LOKI_DATASOURCE'

  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:3100
    isDefault: false
    editable: true
LOKI_DATASOURCE

# Reload Grafana to pick up new datasource
systemctl reload grafana-server

echo "✅ Loki datasource provisioned in Grafana"

# ============================================================
# SECTION 3: PROMTAIL INSTALLATION
# ============================================================

echo ""
echo "=== Step 3: Installing Promtail (Log Shipper) ==="

# Create promtail user
useradd --no-create-home --shell /bin/false promtail 2>/dev/null || true

# Download and install Promtail binary
PROMTAIL_VERSION="2.9.4"
cd /tmp
wget https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip
unzip -o promtail-linux-amd64.zip

cp promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail
chown promtail:promtail /usr/local/bin/promtail

# Create Promtail configuration
cat > /etc/promtail/promtail-config.yml << 'PROMTAIL_CONFIG'
server:
  http_listen_port: 9080
  log_level: info

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  # Nginx Access Logs
  - job_name: nginx-access
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx-access
          __path__: /var/log/nginx/access.log
    pipeline_stages:
      - regex:
          expression: '(?P<remote_addr>[\w\.]+) - (?P<remote_user>[\w\.\-]*) \[(?P<timestamp>[\w:/]+\s[+\-]\d{4})\] "(?P<request>[\w\s\.\-_]+)" (?P<status>\d+) (?P<body_bytes_sent>\d+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)" (?P<request_time>[\d\.]+)'
      - labels:
          status: status

  # Nginx Error Logs
  - job_name: nginx-error
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx-error
          __path__: /var/log/nginx/error.log
    pipeline_stages:
      - regex:
          expression: '(?P<timestamp>\d{4}/\d{2}/\d{2}\s\d{2}:\d{2}:\d{2})\s\[(?P<severity>\w+)\]\s(?P<message>.*)'
      - labels:
          severity: severity

  # System Logs
  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          __path__: /var/log/syslog
    pipeline_stages:
      - regex:
          expression: '(?P<timestamp>\w+\s+\d+\s\d{2}:\d{2}:\d{2})\s(?P<hostname>[\w\-\.]+)\s(?P<program>[\w\-\.]+)(?:\[(?P<pid>\d+)\])?:\s(?P<message>.*)'
      - labels:
          program: program

  # Auth Logs
  - job_name: auth-log
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          __path__: /var/log/auth.log
    pipeline_stages:
      - regex:
          expression: '(?P<timestamp>\w+\s+\d+\s\d{2}:\d{2}:\d{2})\s(?P<hostname>[\w\-\.]+)\s(?P<program>[\w\-\.]+)(?:\[(?P<pid>\d+)\])?:\s(?P<message>.*)'
      - labels:
          program: program

  # Prometheus Logs
  - job_name: prometheus-log
    static_configs:
      - targets:
          - localhost
        labels:
          job: prometheus
          __path__: /var/log/prometheus.log
    pipeline_stages:
      - json:
          expressions:
            timestamp: ts
            level: level
            message: msg
      - labels:
          level: level
PROMTAIL_CONFIG

mkdir -p /etc/promtail
chown promtail:promtail /etc/promtail/promtail-config.yml

# Create Promtail systemd service
cat > /etc/systemd/system/promtail.service << 'PROMTAIL_SERVICE'
[Unit]
Description=Promtail Log Shipper
Wants=network-online.target
After=network-online.target
After=loki.service

[Service]
User=promtail
Group=promtail
Type=simple
ExecStart=/usr/local/bin/promtail \
  -config.file=/etc/promtail/promtail-config.yml

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
PROMTAIL_SERVICE

systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

sleep 2  # Wait for Promtail to start

echo "✅ Promtail installed and running (port 9080)"

# ============================================================
# SECTION 4: CREATE LOGS DASHBOARD
# ============================================================

echo ""
echo "=== Step 4: Creating Logs Dashboard in Grafana ==="

# Create Loki logs dashboard
cat > /opt/grafana/dashboards/logs-dashboard.json << 'LOGS_DASHBOARD'
{
  "annotations": {"list": []},
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": "Loki",
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0},
      "id": 2,
      "targets": [
        {
          "expr": "{job=\"nginx-access\"} | json",
          "refId": "A"
        }
      ],
      "title": "Nginx Access Logs",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
      "id": 3,
      "targets": [
        {
          "expr": "{job=\"nginx-error\"}",
          "refId": "A"
        }
      ],
      "title": "Nginx Error Logs",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16},
      "id": 4,
      "targets": [
        {
          "expr": "{job=\"syslog\"}",
          "refId": "A"
        }
      ],
      "title": "System Logs",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 24},
      "id": 5,
      "targets": [
        {
          "expr": "{job=\"auth\"}",
          "refId": "A"
        }
      ],
      "title": "Authentication Logs",
      "type": "logs"
    }
  ],
  "schemaVersion": 27,
  "style": "dark",
  "tags": ["logs", "loki"],
  "templating": {"list": []},
  "time": {"from": "now-1h", "to": "now"},
  "timezone": "",
  "title": "Centralized Logs",
  "uid": "logs-dashboard",
  "version": 0
}
LOGS_DASHBOARD

chown grafana:grafana /opt/grafana/dashboards/logs-dashboard.json

echo "✅ Logs dashboard created"

# ============================================================
# FINAL STATUS
# ============================================================

echo ""
echo "=== Loki & Promtail Setup Complete ==="
echo "✅ Loki running on port 3100"
echo "✅ Promtail shipping logs to Loki"
echo "✅ Loki datasource provisioned in Grafana"
echo "✅ Logs dashboard created"
echo ""
echo "Centralized Logging Active:"
echo "  - Nginx access logs"
echo "  - Nginx error logs"
echo "  - System logs"
echo "  - Auth logs"
echo "  - 30-day retention"
echo ""
echo "Access logs in Grafana:"
echo "  1. Open Grafana (port 3000)"
echo "  2. Click 'Explore' → Select 'Loki' datasource"
echo "  3. Or view 'Centralized Logs' dashboard"
