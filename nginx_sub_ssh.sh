#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# Developer credit
echo -e "\nDeveloper: Zaman Sheikh"
echo -e "GitHub: github.com/zamansheikh\n"
# ─────────────────────────────────────────────────────────────────────────────

# 1. Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# 2. Check if running in an interactive shell
if [[ ! -t 0 ]]; then
    echo "This script must be run in an interactive shell."
    exit 1
fi

# 3. Prompt for domain, subdomain, and ports
read -p "Enter your main domain (e.g., example.com): " DOMAIN
read -p "Enter the port number for the main app (e.g., 3002): " MAIN_PORT
read -p "Enter the subdomain for the dashboard (e.g., dash): " SUBDOMAIN
read -p "Enter the port number for the subdomain app (e.g., 5173): " DASH_PORT

if [[ -z "$DOMAIN" || -z "$MAIN_PORT" || -z "$SUBDOMAIN" || -z "$DASH_PORT" ]] || ! [[ "$MAIN_PORT" =~ ^[0-9]+$ ]] || ! [[ "$DASH_PORT" =~ ^[0-9]+$ ]]; then
  echo "Invalid input. Please provide valid domain and numeric port values."
  exit 1
fi

# 4. Ensure Nginx is installed
if ! command -v nginx &> /dev/null; then
  echo "Nginx not found, installing..."
  apt update && apt install -y nginx
fi

# 5. Ask for SSL setup
read -p "Do you want to set up SSL with Let's Encrypt? (y/n): " SSL_CHOICE

# ─────────────────────────────────────────────────────────────────────────────
# CLEANUP: Remove default and old configs for this domain and subdomain
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "/etc/nginx/sites-enabled/default" ]; then
  echo "Removing default Nginx configuration..."
  rm -f /etc/nginx/sites-enabled/default
fi

if [ -f "/etc/nginx/sites-enabled/$DOMAIN" ]; then
  echo "Removing old Nginx config for $DOMAIN from sites-enabled..."
  rm -f "/etc/nginx/sites-enabled/$DOMAIN"
fi

if [ -f "/etc/nginx/sites-available/$DOMAIN" ]; then
  echo "Removing old Nginx config for $DOMAIN from sites-available..."
  rm -f "/etc/nginx/sites-available/$DOMAIN"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Ensure directory exists for ACME challenges
# ─────────────────────────────────────────────────────────────────────────────
ACME_DIR="/var/www/certbot"
mkdir -p "$ACME_DIR"
chown -R www-data:www-data "$ACME_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Create Nginx config for main domain (http & https)
# ─────────────────────────────────────────────────────────────────────────────
CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"

cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # Serve ACME challenge files from a static directory
    location ^~ /.well-known/acme-challenge/ {
        root $ACME_DIR;
        default_type "text/plain";
        try_files \$uri =404;
    }

    # Proxy all other traffic to the backend for main domain
    location / {
        proxy_pass http://127.0.0.1:$MAIN_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# Subdomain configuration for dashboard
server {
    listen 80;
    server_name $SUBDOMAIN.$DOMAIN www.$SUBDOMAIN.$DOMAIN;

    # Serve ACME challenge files for subdomain
    location ^~ /.well-known/acme-challenge/ {
        root $ACME_DIR;
        default_type "text/plain";
        try_files \$uri =404;
    }

    # Proxy all traffic for dashboard subdomain
    location / {
        proxy_pass http://127.0.0.1:$DASH_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf "$CONFIG_PATH" "/etc/nginx/sites-enabled/$DOMAIN"

# 6. Test and reload Nginx with new config
echo "Testing and reloading Nginx with new config..."
nginx -t && systemctl reload nginx

# 7. Configure firewall (if using UFW)
if command -v ufw &> /dev/null; then
  echo "Configuring firewall with ufw..."
  ufw allow 80/tcp 2>/dev/null || true
  ufw allow $MAIN_PORT/tcp 2>/dev/null || true
  ufw allow $DASH_PORT/tcp 2>/dev/null || true
  if [[ "$SSL_CHOICE" =~ ^[Yy]$ ]]; then
    ufw allow 443/tcp 2>/dev/null || true
  fi
  ufw reload 2>/dev/null || true
fi

# 8. If SSL is desired, obtain certificate and update config
if [[ "$SSL_CHOICE" =~ ^[Yy]$ ]]; then

  # Install Certbot if necessary
  if ! command -v certbot &> /dev/null; then
    echo "Installing Certbot..."
    apt update && apt install -y certbot python3-certbot-nginx
  fi

  echo "Requesting SSL certificate for $DOMAIN and $SUBDOMAIN.$DOMAIN..."
  certbot certonly --nginx \
    -d "$DOMAIN" -d "www.$DOMAIN" -d "$SUBDOMAIN.$DOMAIN" -d "www.$SUBDOMAIN.$DOMAIN" \
    --non-interactive --agree-tos \
    -m "admin@$DOMAIN" --redirect

  # Verify certificate generation
  if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "SSL certificate generation failed for $DOMAIN or $SUBDOMAIN. Please check domain DNS or logs."
    exit 1
  fi

  # Overwrite config with HTTPS configuration
  cat > "$CONFIG_PATH" <<EOF
# Redirect HTTP to HTTPS for both main domain and subdomain
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN $SUBDOMAIN.$DOMAIN www.$SUBDOMAIN.$DOMAIN;
    location ^~ /.well-known/acme-challenge/ {
        root $ACME_DIR;
        default_type "text/plain";
        try_files \$uri =404;
    }
    location / {
        return 301 https://$DOMAIN\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN $SUBDOMAIN.$DOMAIN www.$SUBDOMAIN.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem;

    # Proxy to backend for main domain
    location / {
        proxy_pass http://127.0.0.1:$MAIN_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Proxy to backend for subdomain
    location / {
        proxy_pass http://127.0.0.1:$DASH_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  echo "Enabling SSL in Nginx..."
  nginx -t && systemctl reload nginx

  echo "Testing Certbot auto-renewal..."
  certbot renew --dry-run

  echo -e "\n✅ SSL Setup complete! Your domain **https://$DOMAIN** and subdomain **https://$SUBDOMAIN.$DOMAIN** are now secured with SSL."

else
  echo -e "\n✅ Setup complete (HTTP only). Your domain **http://$DOMAIN** points to port $MAIN_PORT and subdomain **http://$SUBDOMAIN.$DOMAIN** points to port $DASH_PORT."
fi
