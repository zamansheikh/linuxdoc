#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# Developer credit
echo -e "\nDeveloper: Zaman Sheikh"
echo -e "GitHub: github.com/zamansheikh\n"
# ─────────────────────────────────────────────────────────────────────────────

# 1. Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# 2. Check if script is running in an interactive shell
if [[ ! -t 0 ]]; then
    echo "This script must be run in an interactive shell."
    exit 1
fi

# 3. Prompt for the domain name and port
read -p "Enter your domain (e.g., example.com): " DOMAIN
read -p "Enter the port number your app listens on (e.g., 3002): " PORT

# Basic validation
if [[ -z "$DOMAIN" ]] || ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "Invalid input. Please provide a valid domain and numeric port."
  exit 1
fi

# 4. Install Nginx if not installed
if ! command -v nginx &> /dev/null; then
  echo "Nginx not found, installing..."
  apt update && apt install -y nginx
fi

# 5. Prompt for SSL choice
read -p "Do you want to set up SSL with Let's Encrypt? (y/n): " SSL_CHOICE

# ─────────────────────────────────────────────────────────────────────────────
# CLEANUP ANY OLD CONFIG FOR THIS DOMAIN
# ─────────────────────────────────────────────────────────────────────────────

# Remove default config to avoid conflicts
if [ -f "/etc/nginx/sites-enabled/default" ]; then
  echo "Removing default Nginx configuration..."
  rm -f /etc/nginx/sites-enabled/default
fi

# Remove old domain configs if they exist
if [ -f "/etc/nginx/sites-enabled/$DOMAIN" ]; then
  echo "Removing old Nginx config for $DOMAIN from sites-enabled..."
  rm -f "/etc/nginx/sites-enabled/$DOMAIN"
fi

if [ -f "/etc/nginx/sites-available/$DOMAIN" ]; then
  echo "Removing old Nginx config for $DOMAIN from sites-available..."
  rm -f "/etc/nginx/sites-available/$DOMAIN"
fi

# 6. Create a minimal HTTP-only Nginx config (temporary or final if no SSL)
CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"

cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # Pass all traffic to your backend on port $PORT
    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf "$CONFIG_PATH" "/etc/nginx/sites-enabled/$DOMAIN"

# 7. Test and reload Nginx
echo "Testing and reloading Nginx with HTTP-only config..."
nginx -t && systemctl reload nginx

# 8. Open firewall ports (if using UFW)
if command -v ufw &> /dev/null; then
  echo "Configuring firewall with ufw..."
  ufw allow 80/tcp 2>/dev/null || true
  ufw allow $PORT/tcp 2>/dev/null || true
  # We only open 443 if user wants SSL
  if [[ "$SSL_CHOICE" =~ ^[Yy]$ ]]; then
    ufw allow 443/tcp 2>/dev/null || true
  fi
  # Reload UFW if enabled
  ufw reload 2>/dev/null || true
fi

# 9. If user wants SSL, obtain certificate and update config
if [[ "$SSL_CHOICE" =~ ^[Yy]$ ]]; then

  # Install Certbot + plugin if missing
  if ! command -v certbot &> /dev/null; then
    echo "Installing Certbot..."
    apt update && apt install -y certbot python3-certbot-nginx
  fi

  echo "Requesting SSL certificate for $DOMAIN (and www.$DOMAIN)..."
  # Use certbot with the nginx plugin
  # --redirect will automatically configure HTTP->HTTPS redirection
  # --non-interactive, --agree-tos, and -m <email> are required for automated usage
  certbot certonly --nginx \
    -d "$DOMAIN" -d "www.$DOMAIN" \
    --non-interactive --agree-tos \
    -m "admin@$DOMAIN" --redirect

  # If certificate generation failed, exit
  if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "SSL certificate generation failed for $DOMAIN. Please check domain DNS or logs."
    exit 1
  fi

  # Now create final HTTPS config
  cat > "$CONFIG_PATH" <<EOF
# Redirect all HTTP requests to HTTPS
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    location / {
        return 301 https://$DOMAIN\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem;

    # Pass traffic to your backend on port $PORT
    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  # Test and reload Nginx with HTTPS config
  echo "Enabling SSL in Nginx..."
  nginx -t && systemctl reload nginx

  # Set up auto-renewal test
  echo "Testing Certbot auto-renewal..."
  certbot renew --dry-run

  echo -e "\n✅ Setup complete! Your domain **https://$DOMAIN** is now secured with SSL."
  exit 0

else
  echo -e "\n✅ Setup complete (HTTP only). Your domain **http://$DOMAIN** points to port $PORT."
  exit 0
fi
