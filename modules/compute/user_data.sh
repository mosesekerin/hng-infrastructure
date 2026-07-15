#!/bin/bash
set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== User Data Script Starting ==="
echo "Environment: ${environment}"
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
apt-get install -y docker.io docker-compose-v2
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
ufw allow 3100/tcp  # Loki
ufw allow 9080/tcp  # Promtail
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

# Obtain certificate for base domain only (not www)
certbot certonly --nginx \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN"

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
HNG_USERNAME=$2

if [ -z "$DOMAIN" ] || [ -z "$HNG_USERNAME" ]; then
  echo "Usage: update-nginx-ssl.sh <domain> <hng_username>"
  exit 1
fi

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

    upstream microapp_frontend {
        server 127.0.0.1:3001;  # Frontend React/Vue app
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        listen [::]:80;
        server_name \$DOMAIN;

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
        server_name \$DOMAIN;

        ssl_certificate /etc/letsencrypt/live/\$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/\$DOMAIN/privkey.pem;

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

        #location = / {
         #   limit_req zone=general burst=20 nodelay;
         #  default_type text/html;
         #   return 200 '<h1>$HNG_USERNAME</h1>';
         #   access_log /var/log/nginx/root.log structured;
        #}

        # Frontend microapp
        location / {
            proxy_pass http://microapp_frontend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            access_log /var/log/nginx/microapp_frontend.log structured;
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

        #location / {
        #    return 404;
        #    access_log /var/log/nginx/404.log structured;
        #}
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

# ============================================================
# SECTION 12: Obtain SSL Certificate and Configure Nginx
# ============================================================

echo ""
echo "=== Step 12: Obtaining SSL certificate and configuring Nginx ==="

# Wait for Nginx to be fully ready
sleep 5

# Get SSL certificate
/usr/local/bin/setup-ssl.sh "${domain_name}" "${letsencrypt_email}"

# Update Nginx with SSL configuration
/usr/local/bin/update-nginx-ssl.sh "${domain_name}" "${hng_username}"

echo "✅ SSL certificate obtained and Nginx configured"

# ============================================================
# SECTION 13: DOWNLOAD AND EXECUTE MONITORING & LOGGING SETUP
# ============================================================

echo ""
echo "=== Step 13: Setting up monitoring and logging stack ==="

# Download and run monitoring setup
GITHUB_MONITORING="https://raw.githubusercontent.com/mosesekerin/hng-infrastructure/main/scripts/monitoring-setup.sh"
if curl -fsSL "$GITHUB_MONITORING" -o /tmp/monitoring-setup.sh 2>/dev/null; then
  chmod +x /tmp/monitoring-setup.sh
  mkdir -p /var/log
  touch /var/log/monitoring-setup.log
  chmod 666 /var/log/monitoring-setup.log
  nohup bash /tmp/monitoring-setup.sh >> /var/log/monitoring-setup.log 2>&1 &
  echo "✅ Monitoring stack setup started"
else
  echo "⚠️  Could not download monitoring setup script"
fi

# Download and run Loki setup (logging)
GITHUB_LOKI="https://raw.githubusercontent.com/mosesekerin/hng-infrastructure/main/scripts/loki-setup.sh"
if curl -fsSL "$GITHUB_LOKI" -o /tmp/loki-setup.sh 2>/dev/null; then
  chmod +x /tmp/loki-setup.sh
  mkdir -p /var/log
  touch /var/log/loki-setup.log
  chmod 666 /var/log/loki-setup.log
  nohup bash /tmp/loki-setup.sh >> /var/log/loki-setup.log 2>&1 &
  echo "✅ Loki & Promtail setup started"
else
  echo "⚠️  Could not download loki setup script"
fi

echo "   Check progress: tail -f /var/log/monitoring-setup.log"
echo "   Check progress: tail -f /var/log/loki-setup.log"

# ============================================================
# SECTION 14: Micro-service App Bootstrap
# ============================================================

echo "=== Step 14: Bootstrapping micro-service app ==="

# 14a. Authorize the CI/CD deploy key for SSH as ubuntu
mkdir -p /home/ubuntu/.ssh
echo "${deploy_public_key}" >> /home/ubuntu/.ssh/authorized_keys
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# 14b. Clone the app repo to the exact path the pipeline expects
APP_DIR=/home/ubuntu/micro-service-app/job-queue-microservices
mkdir -p /home/ubuntu/micro-service-app
git clone https://github.com/mosesekerin/job-queue-microservices.git "$${APP_DIR}"

# 14c. Fetch the secret via the instance's IAM role; write .env
REDIS_PASSWORD=$(aws ssm get-parameter \
  --name /microapp/${environment}/redis_password \
  --with-decryption \
  --region us-east-1 \
  --query Parameter.Value \
  --output text)

cat > "$${APP_DIR}/.env" << EOF
REDIS_PASSWORD=$${REDIS_PASSWORD}
FRONTEND_PORT=3001
EOF
chmod 600 "$${APP_DIR}/.env"

# 14d. Ownership to ubuntu, so the pipeline's git pull works over SSH
chown -R ubuntu:ubuntu /home/ubuntu/micro-service-app

# 14e. First launch — creates the world the deploy script will later evolve
cd "$${APP_DIR}"
docker compose up -d --build

echo "Micro-service app bootstrapped"
