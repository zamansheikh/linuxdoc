#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# Script to remove all Nginx and Certbot configurations for specified domains
# ─────────────────────────────────────────────────────────────────────────────

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Define domains to clean up
DOMAINS=("poopalert.fun" "api.poopalert.fun")

# ─────────────────────────────────────────────────────────────────────────────
# 1. Stop Nginx to prevent conflicts during cleanup
# ─────────────────────────────────────────────────────────────────────────────
echo "Stopping Nginx..."
systemctl stop nginx

# ─────────────────────────────────────────────────────────────────────────────
# 2. Remove Nginx configuration files
# ─────────────────────────────────────────────────────────────────────────────
echo "Removing Nginx configuration files..."
for DOMAIN in "${DOMAINS[@]}"; do
  # Remove from sites-enabled
  if [ -f "/etc/nginx/sites-enabled/$DOMAIN" ]; then
    echo "Removing /etc/nginx/sites-enabled/$DOMAIN..."
    rm -f "/etc/nginx/sites-enabled/$DOMAIN"
  fi

  # Remove from sites-available
  if [ -f "/etc/nginx/sites-available/$DOMAIN" ]; then
    echo "Removing /etc/nginx/sites-available/$DOMAIN..."
    rm -f "/etc/nginx/sites-available/$DOMAIN"
  fi
done

# Check for other files containing server_name for these domains
echo "Checking for other configurations with conflicting server_name..."
for DOMAIN in "${DOMAINS[@]}"; do
  conflicting_files=$(grep -rl "server_name.*$DOMAIN" /etc/nginx/ | grep -v "/etc/nginx/sites-available/$DOMAIN")
  if [ -n "$conflicting_files" ]; then
    echo "Found conflicting configurations for $DOMAIN in:"
    echo "$conflicting_files"
    for file in $conflicting_files; do
      echo "Removing $file..."
      rm -f "$file"
    done
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 3. Remove SSL certificates
# ─────────────────────────────────────────────────────────────────────────────
echo "Removing SSL certificates..."
for DOMAIN in "${DOMAINS[@]}"; do
  if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "Removing SSL certificates for $DOMAIN..."
    certbot delete --cert-name "$DOMAIN" 2>/dev/null || true
  fi
done

# Clean up additional Certbot files
echo "Cleaning up Certbot directories..."
rm -rf /etc/letsencrypt/archive/* /etc/letsencrypt/renewal/* /etc/letsencrypt/live/*

# ─────────────────────────────────────────────────────────────────────────────
# 4. Remove ACME challenge directory
# ─────────────────────────────────────────────────────────────────────────────
echo "Removing ACME challenge directory..."
if [ -d "/var/www/certbot" ]; then
  rm -rf /var/www/certbot
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Reset firewall rules (if using ufw)
# ─────────────────────────────────────────────────────────────────────────────
if command -v ufw &> /dev/null; then
  echo "Resetting ufw firewall rules..."
  ufw delete allow 80/tcp 2>/dev/null || true
  ufw delete allow 443/tcp 2>/dev/null || true
  ufw delete allow 4500/tcp 2>/dev/null || true
  ufw reload 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. Start Nginx
# ─────────────────────────────────────────────────────────────────────────────
echo "Starting Nginx..."
systemctl start nginx

# Test Nginx configuration
echo "Testing Nginx configuration..."
nginx -t

# ─────────────────────────────────────────────────────────────────────────────
# 7. Verify cleanup
# ─────────────────────────────────────────────────────────────────────────────
echo "Verifying cleanup..."
for DOMAIN in "${DOMAINS[@]}"; do
  if ! grep -r "server_name.*$DOMAIN" /etc/nginx/ >/dev/null; then
    echo "No Nginx configurations found for $DOMAIN."
  else
    echo "Warning: Some configurations for $DOMAIN still exist:"
    grep -r "server_name.*$DOMAIN" /etc/nginx/
  fi
  if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "No SSL certificates found for $DOMAIN."
  else
    echo "Warning: SSL certificates for $DOMAIN still exist."
  fi
done

echo -e "\n✅ Cleanup complete! You can now run your setup script for a fresh Nginx configuration."
exit 0
