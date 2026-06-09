#!/bin/bash
set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== User Data Script Starting ==="
echo "Environment: $$${environment}"
echo "Timestamp: $(date)"

# ============================================================
# SECTION 1: System Updates & Base Tools
# ============================================================

echo "=== Step 1: Updating system ==="
apt-get update
apt-get upgrade -y

echo "=== Step 2: Installing base tools ==="
apt-get install -y \
  curl \
  wget \
  git \
  vim \
  htop \
  net-tools \
  jq \
  unzip \
  awscli \
  ca-certificates

# ============================================================
# SECTION 2: Docker Installation
# ============================================================

echo "=== Step 2: Installing Docker ==="
apt-get install -y docker.io docker-compose
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# ============================================================
# SECTION 3: Nginx Installation & Configuration
# ============================================================

echo "=== Step 3: Installing Nginx ==="
apt-get install -y nginx

# Create Nginx directories
mkdir -p /etc/nginx/conf.d
mkdir -p /var/www/certbot

# Create temporary HTTP-only Nginx config (before SSL)
cat > /etc/nginx/nginx.conf << 'NGINX_HTTP_CONFIG'
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
}

http {
    # Logging
    log_format structured '$remote_addr - $remote_user [$time_local] '
                         '"$request" $status $body_bytes_sent '
                         '"$http_referer" "$http_user_agent" '
                         'request_time=$request_time';

    access_log /var/log/nginx/access.log structured;
    error_log /var/log/nginx/error.log warn;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css application/json text/javascript;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    # HTTP Server Block (temporary)
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        # Certbot validation
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # Health check endpoint (before SSL ready)
        location = /health {
            access_log off;
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }

        # Redirect all other HTTP to HTTPS once ready
        location / {
            return 503;
            add_header Retry-After "60" always;
        }
    }
}
NGINX_HTTP_CONFIG

# Test Nginx config
nginx -t

# Start Nginx
systemctl enable nginx
systemctl start nginx

echo "✅ Nginx installed and running (HTTP-only mode)"

# ============================================================
# SECTION 4: Certbot Installation (for SSL)
# ============================================================

echo "=== Step 4: Installing Certbot ==="
apt-get install -y certbot python3-certbot-nginx

# Create renewal hook script that will be run after cert renewal
mkdir -p /etc/letsencrypt/renewal-hooks/post
cat > /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh << 'RENEWAL_HOOK'
#!/bin/bash
systemctl reload nginx
RENEWAL_HOOK

chmod +x /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh

echo "✅ Certbot installed"

# ============================================================
# SECTION 5: Security Hardening
# ============================================================

echo "=== Step 5: Configuring UFW firewall ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 9090/tcp  # Prometheus
ufw allow 3000/tcp  # Grafana
ufw --force enable

# ============================================================
# SECTION 6: SSH Hardening
# ============================================================

echo "=== Step 6: Hardening SSH ==="
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl reload sshd

# ============================================================
# SECTION 7: Automatic Security Updates
# ============================================================

echo "=== Step 7: Enabling automatic security updates ==="
apt-get install -y unattended-upgrades
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# ============================================================
# SECTION 8: Create Application Directories
# ============================================================

echo "=== Step 8: Creating application directories ==="
mkdir -p /opt/hng
mkdir -p /opt/hng/nginx
mkdir -p /opt/hng/prometheus
mkdir -p /opt/hng/grafana
mkdir -p /opt/hng/loki

chmod 755 /opt/hng

# ============================================================
# SECTION 9: Create Systemd Service Templates
# ============================================================

echo "=== Step 9: Creating systemd service templates ==="

# Enhanced Nginx service with auto-restart
mkdir -p /etc/systemd/system/nginx.service.d
cat > /etc/systemd/system/nginx.service.d/override.conf << 'NGINX_SERVICE'
[Service]
Restart=on-failure
RestartSec=5s
StartLimitInterval=60s
StartLimitBurst=3
NGINX_SERVICE

# Reload systemd
systemctl daemon-reload

# ============================================================
# SECTION 10: Create SSL Certificate Script
# ============================================================

echo "=== Step 10: Creating SSL certificate helper script ==="

# Create script that will be called to obtain SSL cert
cat > /usr/local/bin/setup-ssl.sh << 'SSL_SETUP'
#!/bin/bash
set -e

DOMAIN=$1
EMAIL=$2

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  echo "Usage: setup-ssl.sh <domain> <email>"
  exit 1
fi

echo "Obtaining SSL certificate for $DOMAIN..."

# Obtain certificate
certbot certonly --nginx \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN" \
  -d "www.$DOMAIN"

echo "Certificate obtained successfully!"
echo "Certificate path: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
SSL_SETUP

chmod +x /usr/local/bin/setup-ssl.sh

# ============================================================
# SECTION 11: Create Nginx Configuration Update Script
# ============================================================

echo "=== Step 11: Creating Nginx config update script ==="

cat > /usr/local/bin/update-nginx-ssl.sh << 'NGINX_UPDATE'
#!/bin/bash
set -e

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
  echo "Usage: update-nginx-ssl.sh <domain>"
  exit 1
fi

HNG_USERNAME="$$${HNG_USERNAME:-Your-Username}"

# Update Nginx config with SSL
cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
}

http {
    log_format structured '\$remote_addr - \$remote_user [\$time_local] '
                         '"\$request" \$status \$body_bytes_sent '
                         '"\$http_referer" "\$http_user_agent" '
                         'request_time=\$request_time upstreamtime=\$upstream_response_time';

    access_log /var/log/nginx/access.log structured;
    error_log /var/log/nginx/error.log warn;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css application/json text/javascript;

    limit_req_zone \$binary_remote_addr zone=general:10m rate=30r/s;
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;

    # HTTP to HTTPS redirect
    server {
        listen 80;
        listen [::]:80;
        server_name $DOMAIN www.$DOMAIN;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        server_name $DOMAIN www.$DOMAIN;

        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "DENY" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

        location = / {
            limit_req zone=general burst=20 nodelay;
            default_type text/html;
            return 200 '<h1>$HNG_USERNAME</h1>';
            access_log /var/log/nginx/root.log structured;
        }

        location = /api {
            limit_req zone=api burst=5 nodelay;
            default_type application/json;
            return 200 '{
              "message": "HNGI14 Stage 1",
              "track": "DevOps",
              "username": "$HNG_USERNAME"
            }';
            access_log /var/log/nginx/api.log structured;
        }

        location = /health {
            access_log off;
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }

        location = /metrics {
            access_log off;
            return 404;
        }

        location / {
            return 404;
            access_log /var/log/nginx/404.log structured;
        }
    }
}
EOF

# Verify config
nginx -t

# Reload Nginx
systemctl reload nginx

echo "✅ Nginx updated with SSL configuration"
NGINX_UPDATE

chmod +x /usr/local/bin/update-nginx-ssl.sh

# # ============================================================
# SECTION 12: DOWNLOAD AND EXECUTE MONITORING SETUP
# ============================================================

echo ""
echo "=== Step 12: Setting up monitoring stack ==="

GITHUB_RAW="https://raw.githubusercontent.com/mosesekerin/hng-infrastructure/main/scripts/monitoring-setup.sh"
MAX_RETRIES=5
RETRY_COUNT=0

# Prepare log file with proper permissions
mkdir -p /var/log
touch /var/log/monitoring-setup.log
chmod 666 /var/log/monitoring-setup.log

echo "Attempting to download monitoring setup script..."
echo "URL: $GITHUB_RAW" | tee -a /var/log/user-data.log

# Retry loop for downloading
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -fsSL "$GITHUB_RAW" -o /tmp/monitoring-setup.sh 2>&1 | tee -a /var/log/user-data.log; then
    if [ -f /tmp/monitoring-setup.sh ] && [ -s /tmp/monitoring-setup.sh ]; then
      echo "✅ Download successful, file size: $(wc -c < /tmp/monitoring-setup.sh) bytes" | tee -a /var/log/user-data.log
      chmod +x /tmp/monitoring-setup.sh
      break
    else
      echo "⚠️ Download returned empty file, retrying..." | tee -a /var/log/user-data.log
      RETRY_COUNT=$((RETRY_COUNT + 1))
      sleep $((RETRY_COUNT * 5))  # Exponential backoff: 5s, 10s, 15s, 20s, 25s
      continue
    fi
  else
    echo "⚠️ Download failed (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES), retrying..." | tee -a /var/log/user-data.log
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep $((RETRY_COUNT * 5))
    continue
  fi
done

# Execute monitoring setup if download succeeded
if [ -f /tmp/monitoring-setup.sh ] && [ -s /tmp/monitoring-setup.sh ]; then
  echo "✅ Starting monitoring stack setup in background..." | tee -a /var/log/user-data.log
  
  # Run with nohup to ensure it survives even if user_data exits
  nohup bash /tmp/monitoring-setup.sh >> /var/log/monitoring-setup.log 2>&1 &
  SETUP_PID=$!
  echo "Monitoring setup PID: $SETUP_PID" | tee -a /var/log/user-data.log
  
  # Wait up to 5 minutes for key services to start
  echo "Waiting for monitoring services to start (timeout: 5 minutes)..." | tee -a /var/log/user-data.log
  for i in {1..60}; do
    sleep 5
    if systemctl is-active --quiet prometheus 2>/dev/null && \
       systemctl is-active --quiet node_exporter 2>/dev/null; then
      echo "✅ Monitoring services started successfully!" | tee -a /var/log/user-data.log
      break
    fi
    if [ $((i % 6)) -eq 0 ]; then
      echo "   Waiting... ($((i * 5))s elapsed)" | tee -a /var/log/user-data.log
    fi
  done
else
  echo "❌ Failed to download monitoring setup script after $MAX_RETRIES attempts" | tee -a /var/log/user-data.log
  echo "   URL: $GITHUB_RAW" | tee -a /var/log/user-data.log
  echo "   The monitoring stack will need to be set up manually or the instance can be recreated" | tee -a /var/log/user-data.log
fi