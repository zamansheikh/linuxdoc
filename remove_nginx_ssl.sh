#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# Clean up Nginx configurations and SSL certificates
# ─────────────────────────────────────────────────────────────────────────────

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# 1. Remove all Nginx configurations
echo "Removing Nginx configurations..."
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/nginx/sites-available/*

# Remove the default Nginx configuration
rm -f /etc/nginx/sites-enabled/default
echo "Nginx configurations removed."

# 2. Remove SSL certificates (Let's Encrypt)
echo "Removing Let's Encrypt SSL certificates..."
rm -rf /etc/letsencrypt/live/*
rm -rf /etc/letsencrypt/archive/*
rm -rf /etc/letsencrypt/renewal/*
echo "SSL certificates removed."

# Optionally, you can restart Nginx if it’s still installed, to apply the removal.
# If Nginx is still installed, you can restart it like this:
# systemctl restart nginx

echo "Cleanup complete. Nginx and SSL certificates have been removed."
