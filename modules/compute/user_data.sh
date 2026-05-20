#!/bin/bash
set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== User Data Script Starting ==="
echo "Environment: ${environment}"
echo "Timestamp: $(date)"

# Update system
echo "=== Updating system ==="
apt-get update
apt-get upgrade -y

# Install basic tools
echo "=== Installing basic tools ==="
apt-get install -y \
  curl \
  wget \
  git \
  vim \
  htop \
  net-tools \
  jq \
  unzip \
  awscli

# Install Docker (for future use)
echo "=== Installing Docker ==="
apt-get install -y docker.io docker-compose
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# Create non-root user for deployments
echo "=== Creating deployment user ==="
useradd -m -s /bin/bash -G docker,sudo deployment || true
echo "deployment ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/deployment

# Enable automatic security updates
echo "=== Enabling automatic security updates ==="
apt-get install -y unattended-upgrades
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# Configure UFW (host-level firewall)
echo "=== Configuring UFW ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 9090/tcp  # Prometheus
ufw allow 3000/tcp  # Grafana
ufw --force enable

# Disable root login (security)
echo "=== Hardening SSH ==="
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl reload sshd

# Create directories for applications
echo "=== Creating directories ==="
mkdir -p /opt/hng
mkdir -p /opt/hng/nginx
mkdir -p /opt/hng/prometheus
mkdir -p /opt/hng/grafana
mkdir -p /opt/hng/loki

chmod 755 /opt/hng

# Create systemd service templates (we'll populate these later)
echo "=== Creating service templates ==="

# Nginx service
cat > /etc/systemd/system/nginx.service << 'NGINX_SERVICE'
[Unit]
Description=Nginx HTTP Server
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
Restart=on-failure
RestartSec=5s
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
NGINX_SERVICE

# Prometheus service
cat > /etc/systemd/system/prometheus.service << 'PROMETHEUS_SERVICE'
[Unit]
Description=Prometheus Monitoring
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
PROMETHEUS_SERVICE

# Reload systemd
systemctl daemon-reload

echo "=== User Data Script Complete ==="
echo "Completed at: $(date)"
