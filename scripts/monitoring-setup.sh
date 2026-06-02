#!/bin/bash
set -e

# Monitoring Stack Installation Script
# Downloaded and executed by user_data.sh

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
# SECTION 3: GRAFANA INSTALLATION
# ============================================================

echo ""
echo "=== Step 3: Installing Grafana ==="

# Add repository
apt-get install -y software-properties-common
add-apt-repository -y "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -

# Install
apt-get update
apt-get install -y grafana-server

# Enable and start
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

echo "✅ Grafana installed and running (port 3000)"

# ============================================================
# SECTION 4: CLEANUP
# ============================================================

echo ""
echo "=== Cleanup ==="
rm -rf /tmp/prometheus-*.tar.gz
rm -rf /tmp/node_exporter-*.tar.gz
rm -rf /tmp/prometheus-${PROM_VERSION}.linux-amd64
rm -rf /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

echo ""
echo "=== Monitoring Stack Setup Complete ==="
echo "Completed at: $(date)"
echo ""
echo "Service Status:"
systemctl status prometheus --no-pager 2>&1 | grep -E "Active|Loaded" || true
systemctl status node_exporter --no-pager 2>&1 | grep -E "Active|Loaded" || true
systemctl status grafana-server --no-pager 2>&1 | grep -E "Active|Loaded" || true
