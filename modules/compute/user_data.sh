#!/bin/bash
set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== User Data Script Starting ==="
echo "Environment: ${environment}"
echo "HNG Username: ${hng_username}"
echo "Timestamp: $(date)"

# ============================================================
# SECTION 1: System Updates & Base Tools
# ============================================================

echo ""
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

echo ""
echo "=== Step 3: Installing Docker ==="
apt-get install -y docker.io docker-compose
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# ============================================================
# SECTION 3: Nginx Installation
# ============================================================

echo ""
echo "=== Step 4: Installing Nginx ==="
apt-get install -y nginx

# Create necessary directories
mkdir -p /etc/nginx/conf.d
mkdir -p /var/www/certbot

# Create initial HTTP-only config
cat > /etc/nginx/nginx.conf << 'NGINX_HTTP_EOF'
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
}

http {
    log_format structured '$${remote_addr} - $${remote_user} [$${time_local}] '
                         '"$${request}" $${status} $${body_bytes_sent} '
                         '"$${http_referer}" "$${http_user_agent}" '
                         'request_time=$${request_time}';

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

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location = /health {
            access_log off;
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }

        location / {
            return 503;
        }
    }
}
NGINX_HTTP_EOF

# Test and start Nginx
nginx -t
systemctl enable nginx
systemctl start nginx

echo "✅ Nginx installed and running (HTTP-only mode)"

# ============================================================
# SECTION 4: Certbot Installation
# ============================================================

echo ""
echo "=== Step 5: Installing Certbot ==="
apt-get install -y certbot python3-certbot-nginx

echo "✅ Certbot installed"

# ============================================================
# SECTION 5: Security & System Configuration
# ============================================================

echo ""
echo "=== Step 6: Configuring UFW firewall ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 9090/tcp
ufw allow 3000/tcp
ufw --force enable

echo ""
echo "=== Step 7: Hardening SSH ==="
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl reload sshd

echo ""
echo "=== Step 8: Enabling automatic security updates ==="
apt-get install -y unattended-upgrades
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# ============================================================
# SECTION 6: Create Application Directories
# ============================================================

echo ""
echo "=== Step 9: Creating application directories ==="
mkdir -p /opt/hng/{nginx,prometheus,grafana,loki}
chmod 755 /opt/hng

# ============================================================
# SECTION 7: Create Systemd Service Overrides
# ============================================================

echo ""
echo "=== Step 10: Creating systemd service overrides ==="
mkdir -p /etc/systemd/system/nginx.service.d

cat > /etc/systemd/system/nginx.service.d/override.conf << 'SYSTEMD_EOF'
[Service]
Restart=on-failure
RestartSec=5s
StartLimitInterval=60s
StartLimitBurst=3
SYSTEMD_EOF

systemctl daemon-reload

# ============================================================
# SECTION 8: SSL Certificate Automation
# ============================================================

echo ""
echo "=== Step 11: Automating SSL certificate setup ==="

# Store domain and email for later use
DOMAIN_NAME="${domain_name}"
CERTBOT_EMAIL="${certbot_email}"
HNG_USERNAME="${hng_username}"

# Only attempt certificate if domain is provided
if [ -n "$$DOMAIN_NAME" ] && [ -n "$$CERTBOT_EMAIL" ]; then
    echo "Attempting to obtain SSL certificate for $$DOMAIN_NAME..."
    
    # Wait for DNS to propagate (give it 30 seconds)
    sleep 30
    
    # Attempt to get certificate (don't fail if it doesn't work on first try)
    if sudo certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "$$CERTBOT_EMAIL" \
        -d "$$DOMAIN_NAME" 2>/dev/null; then
        
        echo "✅ SSL certificate obtained successfully"
        CERT_SUCCESS=true
    else
        echo "⚠️ SSL certificate not obtained yet (will need manual setup)"
        CERT_SUCCESS=false
    fi
    
    # If certificate obtained, configure Nginx with SSL
    if [ "$$CERT_SUCCESS" = true ]; then
        echo "Configuring Nginx with SSL..."
        
        cat > /etc/nginx/nginx.conf << 'NGINX_SSL_EOF'
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
}

http {
    log_format structured '$${remote_addr} - $${remote_user} [$${time_local}] '
                         '"$${request}" $${status} $${body_bytes_sent} '
                         '"$${http_referer}" "$${http_user_agent}" '
                         'request_time=$${request_time} upstreamtime=$${upstream_response_time}';

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

    limit_req_zone $${binary_remote_addr} zone=general:10m rate=30r/s;
    limit_req_zone $${binary_remote_addr} zone=api:10m rate=10r/s;

    server {
        listen 80;
        listen [::]:80;
        server_name $$DOMAIN_NAME;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://$${host}$${request_uri};
        }
    }

    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        server_name $$DOMAIN_NAME;

        ssl_certificate /etc/letsencrypt/live/$$DOMAIN_NAME/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$$DOMAIN_NAME/privkey.pem;

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
            return 200 '<h1>$$HNG_USERNAME</h1>';
            access_log /var/log/nginx/root.log structured;
        }

        location = /api {
            limit_req zone=api burst=5 nodelay;
            default_type application/json;
            return 200 '{
              "message": "HNGI14 Stage 1",
              "track": "DevOps",
              "username": "$$HNG_USERNAME"
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
NGINX_SSL_EOF

        nginx -t
        systemctl reload nginx
        echo "✅ Nginx configured with SSL"
    else
        echo "⚠️ SSL not configured yet - will need manual setup"
        echo "Once SSL obtained, update Nginx config manually"
    fi
else
    echo "⚠️ Domain or email not provided - skipping SSL setup"
    echo "Manual SSL setup required"
fi

# ============================================================
# SECTION 9: Status Report
# ============================================================

echo ""
echo "=== User Data Script Complete ==="
echo "Completed at: $(date)"
echo ""
echo "Service Status:"
systemctl status nginx --no-pager 2>&1 | grep -E "Active|Loaded" || true
systemctl status docker --no-pager 2>&1 | grep -E "Active|Loaded" || true
systemctl status ssh --no-pager 2>&1 | grep -E "Active|Loaded" || true
echo ""
echo "✅ System initialization complete!"
