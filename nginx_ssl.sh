#!/bin/bash

# Check if the script is running in an interactive shell
if [[ ! -t 0 ]]; then
    echo "This script must be run in an interactive shell."
    exit 1
fi

# Developer credit
echo -e "\nDeveloper: Zaman Sheikh\nGitHub: github.com/zamansheikh\n"

# Check if the script is running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Prompt for the domain name and port
read -p "Enter your domain (e.g., example.com): " DOMAIN
read -p "Enter the port number (e.g., 5130): " PORT

# Check if domain is empty or port is not a number
if [[ -z "$DOMAIN" ]] || ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "Invalid input. Please provide a valid domain and port."
  exit 1
fi

# Install Nginx if not installed
if ! command -v nginx &> /dev/null; then
  echo "Nginx not found, installing..."
  apt update && apt install -y nginx
fi

# Ask if user wants SSL
read -p "Do you want to set up SSL with Let's Encrypt? (y/n): " SSL_CHOICE

# Remove default Nginx config to prevent conflicts
echo "Removing default Nginx configuration..."
rm -f /etc/nginx/sites-enabled/default

# Install Certbot if missing
if [[ "$SSL_CHOICE" =~ ^[Yy]$ ]]; then
  if ! command -v certbot &> /dev/null; then
    echo "Certbot not found, installing..."
    apt install -y certbot python3-certbot-nginx
  fi
fi

# Create a new temporary HTTP-only Nginx configuration for the domain
CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"

echo "Creating temporary HTTP-only Nginx config for $DOMAIN..."
cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the temporary HTTP-only config
ln -sf "$CONFIG_PATH" "/etc/nginx/sites-enabled/"

# Restart Nginx to apply changes
echo "Restarting Nginx with temporary HTTP configuration..."
nginx -t && systemctl restart nginx

# Allow necessary ports in firewall
echo "Configuring firewall..."
ufw allow 80/tcp
ufw allow $PORT/tcp
ufw reload

# Request SSL Certificate if chosen
if [[ "$SSL_CHOICE" =~ ^[Yy]$ ]]; then
  echo "Requesting SSL certificate for $DOMAIN..."
  certbot certonly --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN --redirect
  
  # Verify SSL certificate exists
  if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "SSL certificate generation failed. Please check your domain settings."
    exit 1
  fi

  # Update Nginx configuration to use SSL
  echo "Updating Nginx configuration for SSL..."
  cat > "$CONFIG_PATH" <<EOF
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

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  # Allow HTTPS in firewall
  ufw allow 443/tcp
  ufw reload
fi

# Restart Nginx with the final configuration
echo "Restarting Nginx with SSL enabled..."
nginx -t && systemctl restart nginx

# Set up auto-renewal for SSL
if [[ "$SSL_CHOICE" =~ ^[Yy]$ ]]; then
  echo "Setting up auto-renewal for SSL..."
  certbot renew --dry-run
fi

# Output success message
if [[ "$SSL_CHOICE" =~ ^[Yy]$ ]]; then
  echo -e "\n✅ Setup complete! Your domain **https://$DOMAIN** is now secured with SSL."
else
  echo -e "\n✅ Setup complete! Your domain **http://$DOMAIN** is now pointing to port $PORT."
fi

# End of script
