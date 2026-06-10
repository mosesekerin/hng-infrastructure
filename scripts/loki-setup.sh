#!/bin/bash
set -e

# Loki Stack Installation Script (CORRECTED FOR AUTOMATION)
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

# FIX #1: Create ALL nested directories including compactor subdirectories
# This was the main issue: /var/lib/loki/compactor/deletion/delete_requests didn't exist
mkdir -p /var/lib/loki/boltdb-shipper-active
mkdir -p /var/lib/loki/boltdb-shipper-cache
mkdir -p /var/lib/loki/chunks
mkdir -p /var/lib/loki/compactor/deletion/delete_requests
mkdir -p /var/lib/loki/compactor/compaction

# FIX #2: Proper permissions - 755 for directories, loki owner
chown -R loki:loki /var/lib/loki
chmod -R 755 /var/lib/loki

mkdir -p /etc/loki
chown loki:loki /etc/loki
chmod 755 /etc/loki

# Download and install Loki binary
LOKI_VERSION="2.9.4"
cd /tmp
wget https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip
unzip -o loki-linux-amd64.zip

cp loki-linux-amd64 /usr/local/bin/loki
chmod +x /usr/local/bin/loki
chown loki:loki /usr/local/bin/loki

cd /

# FIX #3: Use CORRECTED Loki config (removed invalid fields, added compactor section)
cat > /etc/loki/loki-config.yml << 'LOKI_CONFIG'
auth_enabled: false

ingester:
  chunk_idle_period: 3m
  chunk_retain_period: 1m
  max_chunk_age: 2h
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
  max_streams_per_user: 10000

schema_config:
  configs:
    - from: 2020-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

server:
  http_listen_port: 3100
  log_level: info
  grpc_listen_port: 9096

storage_config:
  boltdb_shipper:
    active_index_directory: /var/lib/loki/boltdb-shipper-active
    shared_store: filesystem
    cache_location: /var/lib/loki/boltdb-shipper-cache
  filesystem:
    directory: /var/lib/loki/chunks

chunk_store_config:
  max_look_back_period: 0s

compactor:
  working_directory: /var/lib/loki/compactor
  shared_store: filesystem
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 5m
  retention_delete_worker_count: 10

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h
LOKI_CONFIG

chown loki:loki /etc/loki/loki-config.yml
chmod 644 /etc/loki/loki-config.yml

# FIX #4: Corrected systemd service (Type=simple, WorkingDirectory, proper logging)
cat > /etc/systemd/system/loki.service << 'LOKI_SERVICE'
[Unit]
Description=Loki Log Aggregation Engine
Documentation=https://grafana.com/docs/loki/latest/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=loki
Group=loki
WorkingDirectory=/var/lib/loki
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki-config.yml

Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=loki

LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
LOKI_SERVICE

systemctl daemon-reload
systemctl enable loki
systemctl start loki

sleep 5  # Wait for Loki to start (increased from 3s for stability)

echo "✅ Loki installed and running (port 3100)"

# ============================================================
# SECTION 2: LOKI DATASOURCE PROVISIONING IN GRAFANA
# ============================================================

echo ""
echo "=== Step 2: Provisioning Loki Datasource in Grafana ==="

# FIX #5: Create datasource file if it doesn't exist BEFORE appending
mkdir -p /etc/grafana/provisioning/datasources

if [ ! -f /etc/grafana/provisioning/datasources/prometheus.yml ]; then
  cat > /etc/grafana/provisioning/datasources/prometheus.yml << 'DATASOURCES_BASE'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
DATASOURCES_BASE
fi

# Now safely append Loki datasource
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

# FIX #6: Add promtail to groups so it can read log files
usermod -a -G www-data,adm promtail 2>/dev/null || true

# Download and install Promtail binary
PROMTAIL_VERSION="2.9.4"
cd /tmp
wget https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip
unzip -o promtail-linux-amd64.zip

cp promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail
chown promtail:promtail /usr/local/bin/promtail

# Create Promtail configuration directory and file
mkdir -p /etc/promtail
mkdir -p /var/lib/promtail

# FIX #7: Simplified promtail config - removed complex pipeline stages that can fail silently
cat > /etc/promtail/promtail-config.yml << 'PROMTAIL_CONFIG'
server:
  http_listen_port: 9080
  log_level: info

positions:
  filename: /var/lib/promtail/positions.yaml

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

  # Nginx Error Logs
  - job_name: nginx-error
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx-error
          __path__: /var/log/nginx/error.log

  # System Logs
  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          __path__: /var/log/syslog

  # Auth Logs
  - job_name: auth-log
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          __path__: /var/log/auth.log

  # Prometheus Logs
  - job_name: prometheus-log
    static_configs:
      - targets:
          - localhost
        labels:
          job: prometheus
          __path__: /var/log/prometheus.log
PROMTAIL_CONFIG

chown promtail:promtail /etc/promtail
chown promtail:promtail /var/lib/promtail
chmod 755 /etc/promtail
chmod 755 /var/lib/promtail
chown promtail:promtail /etc/promtail/promtail-config.yml
chmod 644 /etc/promtail/promtail-config.yml

# Create Promtail systemd service
cat > /etc/systemd/system/promtail.service << 'PROMTAIL_SERVICE'
[Unit]
Description=Promtail Log Shipper
Documentation=https://grafana.com/docs/loki/latest/
Wants=network-online.target
After=network-online.target
After=loki.service

[Service]
Type=simple
User=promtail
Group=promtail
WorkingDirectory=/var/lib/promtail
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yml

Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=promtail

LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
PROMTAIL_SERVICE

systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

sleep 3  # Wait for Promtail to start

echo "✅ Promtail installed and running (port 9080)"

# ============================================================
# SECTION 4: CREATE LOGS DASHBOARD
# ============================================================

echo ""
echo "=== Step 4: Creating Logs Dashboard in Grafana ==="

mkdir -p /opt/grafana/dashboards

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
          "expr": "{job=\"nginx-access\"}",
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
chmod 644 /opt/grafana/dashboards/logs-dashboard.json

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
echo "✅ 30-day log retention configured"
echo ""
echo "Centralized Logging Active:"
echo "  - Nginx access logs"
echo "  - Nginx error logs"
echo "  - System logs"
echo "  - Auth logs"
echo "  - Prometheus logs"
echo ""
echo "Access logs in Grafana:"
echo "  1. Open Grafana (port 3000)"
echo "  2. Click 'Explore' → Select 'Loki' datasource"
echo "  3. Or view 'Centralized Logs' dashboard"