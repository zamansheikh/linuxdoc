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

# Create a new Nginx configuration file for the domain
CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
if [ -f "$CONFIG_PATH" ]; then
  echo "Nginx config for $DOMAIN already exists. Skipping configuration creation."
else
  echo "Creating Nginx config for $DOMAIN..."
  cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
  echo "Nginx config for $DOMAIN created successfully."
fi

# Enable the site configuration by creating a symbolic link
ln -s "$CONFIG_PATH" "/etc/nginx/sites-enabled/"

# Test Nginx configuration for errors
echo "Testing Nginx configuration..."
if ! nginx -t; then
  echo "Nginx configuration test failed. Please check your configurations."
  exit 1
else
  echo "Nginx configuration is valid."
fi

# Restart Nginx to apply the changes
echo "Restarting Nginx..."
systemctl restart nginx

# Allow HTTP traffic on port 80 and the specified port
echo "Configuring firewall..."
ufw allow 80/tcp
ufw allow $PORT/tcp
ufw reload

# Output success message
echo -e "\nSetup complete! Your domain $DOMAIN is now pointing to port $PORT."

# End of script
