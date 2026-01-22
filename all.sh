#!/bin/bash

# ==============================================================================
# Script Name: all.sh
# Description: Automated Nginx Reverse Proxy & SSL Setup (Debian/Arch/RHEL support)
# Developer: GitHub Copilot (Based on original logic by Zaman Sheikh)
# ==============================================================================

# --- Aesthetics & Colors ---
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Helper Functions for GUI-like Experience ---

print_header() {
    clear
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BOLD}${CYAN}   $1   ${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BOLD}${BLUE}[INFO]${NC} $1..."
}

print_success() {
    echo -e "${BOLD}${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${BOLD}${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${BOLD}${RED}[ERROR]${NC} $1"
}

ask_confirm() {
    local prompt="$1"
    local default="${2:-Y}"
    local reply
    
    if [[ "$default" == "Y" ]]; then
        prompt_str="[Y/n]"
    else
        prompt_str="[y/N]"
    fi

    echo -ne "${YELLOW}$prompt $prompt_str: ${NC}"
    read -r reply
    reply=${reply:-$default}
    
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

press_enter() {
    echo -e ""
    read -p "Press [Enter] to continue..."
}

# --- Root Privileges Check ---
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root."
   exit 1
fi

# --- Global Variables ---
declare -A domain_ports
declare -A domain_ssl_status
OS_TYPE="unknown"
PKG_MANAGER=""
INSTALL_CMD=""
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_LINK_DIR="/etc/nginx/sites-enabled"

# --- 1. OS Detection ---
detect_os() {
    print_header "System Detection"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
    else
        print_warning "Could not detect OS from /etc/os-release. Assuming generic Linux."
    fi

    case $OS_TYPE in
        ubuntu|debian|kali|linuxmint)
            print_success "Detected Debian-based system ($PRETTY_NAME)."
            PKG_MANAGER="apt"
            INSTALL_CMD="apt install -y"
            UPDATE_CMD="apt update"
            ;;
        arch|manjaro)
            print_success "Detected Arch-based system ($PRETTY_NAME)."
            PKG_MANAGER="pacman"
            INSTALL_CMD="pacman -S --noconfirm"
            UPDATE_CMD="pacman -Sy"
            # Adjust Nginx paths for Arch if standard layout isn't present
            # Arch typically uses /etc/nginx/nginx.conf directly, but we will enforce 
            # the sites-available/enabled structure for consistency with this script's logic.
            ;;
        centos|rhel|fedora|almalinux)
            print_success "Detected RHEL-based system ($PRETTY_NAME)."
            PKG_MANAGER="dnf"
            INSTALL_CMD="dnf install -y"
            UPDATE_CMD="dnf check-update"
            ;;
        *)
            print_warning "OS ($OS_TYPE) not fully supported. Automatic installation might fail."
            PKG_MANAGER="unknown"
            ;;
    esac
    sleep 1
}

# --- 2. Check & Install Prerequisites ---
check_install() {
    local pkg_cmd=$1
    local pkg_name=$2
    local install_pkg_name=${3:-$2} # Optional: different name for installation

    if command -v "$pkg_cmd" &> /dev/null; then
        print_success "$pkg_name is already installed. Skipping."
    else
        print_warning "$pkg_name is missing."
        if ask_confirm "Do you want to install $pkg_name now?" "Y"; then
            print_step "Installing $pkg_name"
            if [[ "$PKG_MANAGER" == "unknown" ]]; then
                print_error "Cannot auto-install on this OS. Please install $pkg_name manually."
                exit 1
            fi
            
            # Run update once if needed (basic logic)
            if [[ ! -f /tmp/update_done ]]; then
                eval "$UPDATE_CMD" &> /dev/null
                touch /tmp/update_done
            fi

            eval "$INSTALL_CMD $install_pkg_name"
            
            if command -v "$pkg_cmd" &> /dev/null; then
                print_success "$pkg_name installed successfully."
            else
                print_error "Failed to install $pkg_name. Please check your package manager."
                exit 1
            fi
        else
            print_error "$pkg_name is required to proceed. Exiting."
            exit 1
        fi
    fi
}

setup_environment() {
    print_header "Environment Setup"
    
    # 1. Nginx
    check_install "nginx" "Nginx" "nginx"
    systemctl enable nginx &> /dev/null
    systemctl start nginx &> /dev/null

    # 2. Firewall (UFW or Firewalld)
    # Simple logic: prefer UFW on Debian, check others on other systems
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        check_install "ufw" "UFW Firewall" "ufw"
        if ! ufw status | grep -q "Status: active"; then
             if ask_confirm "Enable UFW Firewall?" "Y"; then
                 ufw --force enable
             fi
        fi
    fi
    # (Checking ports logic moved to finalization)

    # 3. Certbot
    if ! command -v certbot &> /dev/null; then
        print_warning "Certbot (SSL tool) is missing."
        if ask_confirm "Install Certbot?" "Y"; then
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                apt install -y certbot python3-certbot-nginx
            elif [[ "$PKG_MANAGER" == "pacman" ]]; then
                pacman -S --noconfirm certbot certbot-nginx
            elif [[ "$PKG_MANAGER" == "dnf" ]]; then
                dnf install -y certbot python3-certbot-nginx
            fi
        fi
    else
        print_success "Certbot is already installed."
    fi

    # Ensure nginx folder structure exists (Critical for Arch/Others compatibility)
    if [ ! -d "$NGINX_CONF_DIR" ]; then
        print_step "Creating Nginx sites directory structure..."
        mkdir -p "$NGINX_CONF_DIR"
        mkdir -p "$NGINX_LINK_DIR"
        
        # Check if nginx.conf includes these. simpler approach: warn user if logic fails later.
        CONFIG_FILE="/etc/nginx/nginx.conf"
        if [ -f "$CONFIG_FILE" ]; then
            if ! grep -q "sites-enabled" "$CONFIG_FILE"; then
                print_warning "Your nginx.conf does not seem to include $NGINX_LINK_DIR/*.conf"
                print_warning "I will attempt to add it to the http block."
                # Attempt to inject include before the last closing brace of http block is risky with sed; just warning for now.
                echo -e "${YELLOW}MANUAL ACTION REQUIRED:${NC} Please ensure 'include $NGINX_LINK_DIR/*;' is in your http {} block in $CONFIG_FILE"
                press_enter
            fi
        fi
    fi
}

# --- 3. Configuration Input (GUI-like) ---
collect_info() {
    print_header "Project Configuration"

    echo -e "${CYAN}We will now configure your Reverse Proxy domains.${NC}"
    echo -e "Existing configurations will be detected."
    echo ""

    read -p "Enter your Main Domain (e.g., example.com): " MAIN_DOMAIN
    if [[ -z "$MAIN_DOMAIN" ]]; then
        print_error "Domain cannot be empty."
        exit 1
    fi

    # Config Main Domain?
    if ask_confirm "Do you want to configure the root domain ($MAIN_DOMAIN)?"; then
        while true; do
            read -p "  > Enter backend port for $MAIN_DOMAIN (e.g., 3000): " PORT
            if [[ "$PORT" =~ ^[0-9]+$ ]]; then
                domain_ports["$MAIN_DOMAIN"]=$PORT
                break
            else
                print_error "Invalid port number."
            fi
        done
    fi

    # Config WWW?
    if ask_confirm "Do you want to configure www.$MAIN_DOMAIN?"; then
         read -p "  > Enter backend port for www.$MAIN_DOMAIN (Press Enter to use ${domain_ports[$MAIN_DOMAIN]:-same}): " WWW_PORT
         WWW_PORT=${WWW_PORT:-${domain_ports[$MAIN_DOMAIN]}}
         if [[ -z "$WWW_PORT" ]]; then
             read -p "  > Port currently required. Enter port: " WWW_PORT
         fi
         domain_ports["www.$MAIN_DOMAIN"]=$WWW_PORT
    fi

    # Config Subdomains
    echo ""
    echo -e "${CYAN}Additional Subdomains${NC}"
    echo "Enter subdomain prefixes (e.g., 'api' for api.$MAIN_DOMAIN)."
    echo "Enter 'done' when finished."
    
    while true; do
        read -p "Subdomain prefix (or 'done'): " SUB
        if [[ "$SUB" == "done" || -z "$SUB" ]]; then
            break
        fi
        
        FULL_SUB="$SUB.$MAIN_DOMAIN"
        if [[ -n "${domain_ports[$FULL_SUB]}" ]]; then
            print_warning "$FULL_SUB is already in the list."
            continue
        fi

        read -p "  > Enter backend port for $FULL_SUB: " SUB_PORT
        domain_ports["$FULL_SUB"]=$SUB_PORT
    done

    echo ""
    if ask_confirm "Do you want to set up SSL (HTTPS) with Let's Encrypt?"; then
        SETUP_SSL="yes"
        read -p "  > Enter email for notifications: " EMAIL
    else
        SETUP_SSL="no"
    fi
}

# --- 4. Logic Execution ---
verify_backends() {
    print_header "Verifying Backends"
    
    for domain in "${!domain_ports[@]}"; do
        port=${domain_ports[$domain]}
        echo -ne "Checking $domain -> 127.0.0.1:$port ... "
        
        # Simple curl check only if possible
        if check_code=$(sudo -u www-data timeout 3 curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$port 2>/dev/null); then
            if [[ "$check_code" =~ ^[23] ]]; then
                echo -e "${GREEN}OK ($check_code)${NC}"
            else
                echo -e "${YELLOW}Warning ($check_code)${NC}"
                print_warning "Backend returned HTTP $check_code (non-standard)."
                if ! ask_confirm "Continue configuration for $domain anyway?"; then
                    unset domain_ports["$domain"]
                    continue
                fi
            fi
        else
            echo -e "${RED}FAILED${NC}"
            print_error "Could not connect to localhost:$port."
            if ! ask_confirm "Is the backend server running? Continue anyway?"; then
                unset domain_ports["$domain"]
                continue
            fi
        fi
    done
}

clean_existing() {
    for domain in "${!domain_ports[@]}"; do
        CONFIG_PATH="$NGINX_CONF_DIR/$domain"
        LINK_PATH="$NGINX_LINK_DIR/$domain"
        
        if [ -f "$CONFIG_PATH" ]; then
            print_warning "Configuration for $domain already exists."
            if ask_confirm "Overwrite existing configuration?" "Y"; then
                rm -f "$LINK_PATH"
                rm -f "$CONFIG_PATH"
                print_success "Removed old config."
            else
                print_info "Skipping $domain..."
                unset domain_ports["$domain"]
            fi
        fi
    done
}

generate_configs() {
    print_header "Generating Configurations"
    
    ACME_DIR="/var/www/letsencrypt"
    mkdir -p "$ACME_DIR"
    chown -R www-data:www-data "$ACME_DIR" 2>/dev/null || true # Best effort chown

    for domain in "${!domain_ports[@]}"; do
        port=${domain_ports[$domain]}
        CONFIG_PATH="$NGINX_CONF_DIR/$domain"
        
        print_step "Writing HTTP config for $domain"
        
        cat <<EOF > "$CONFIG_PATH"
server {
    listen 80;
    server_name $domain;
    
    # ACME Challenge for Certbot
    location ^~ /.well-known/acme-challenge/ {
        root $ACME_DIR;
        default_type "text/plain";
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
        # Link it
        ln -sf "$CONFIG_PATH" "$NGINX_LINK_DIR/$domain"
    done

    print_step "Checking Nginx syntax..."
    if nginx -t; then
        print_success "Syntax OK. Restarting Nginx."
        systemctl restart nginx
    else
        print_error "Nginx configuration test failed. Reverting..."
        # In a real GUI, likely would offer to edit file or rollback.
        exit 1
    fi
}

setup_ssl() {
    if [[ "$SETUP_SSL" != "yes" ]]; then
        return
    fi
    
    print_header "SSL Setup (Let's Encrypt)"

    DOMAINS_TO_CERT=()
    for domain in "${!domain_ports[@]}"; do
        DOMAINS_TO_CERT+=("-d" "$domain")
    done

    if [ ${#DOMAINS_TO_CERT[@]} -eq 0 ]; then
        print_warning "No domains to securely configure."
        return
    fi

    print_step "Requesting certificates..."
    if certbot certonly --nginx --cert-name "$MAIN_DOMAIN-bundle" "${DOMAINS_TO_CERT[@]}" --non-interactive --agree-tos -m "$EMAIL"; then
        print_success "Certificates obtained!"
        
        # Rewrite configs with SSL
        for domain in "${!domain_ports[@]}"; do
            port=${domain_ports[$domain]}
            CONFIG_PATH="$NGINX_CONF_DIR/$domain"
            
            print_step "Updating $domain to HTTPS..."
             cat <<EOF > "$CONFIG_PATH"
server {
    listen 80;
    server_name $domain;
    location ^~ /.well-known/acme-challenge/ {
        root $ACME_DIR;
        default_type "text/plain";
        try_files \$uri =404;
    }
    location / {
        return 301 https://$domain\$request_uri;
    }
}
server {
    listen 443 ssl http2;
    server_name $domain;
    
    ssl_certificate /etc/letsencrypt/live/$MAIN_DOMAIN-bundle/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$MAIN_DOMAIN-bundle/privkey.pem;
    
    # Generic safe SSL settings (can be tuned)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
        done
        
        systemctl restart nginx
        print_success "Nginx restarted with SSL support."
        
    else
        print_error "SSL Certificate request failed. Keeping HTTP-only config."
        print_info "Check firewall settings or domain DNS propagation."
        
        if ask_confirm "Retry SSL setup?" "N"; then
            setup_ssl
        fi
    fi
}

finalize() {
    print_header "Finalization"

    # Firewall ports
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp > /dev/null
        ufw allow 443/tcp > /dev/null
        print_success "Firewall configured (Ports 80, 443 opened)."
    fi

    echo -e "\n${BOLD}${GREEN}✅ SETUP COMPLETE!${NC}"
    echo "------------------------------------------------"
    for domain in "${!domain_ports[@]}"; do
        if [[ "$SETUP_SSL" == "yes" ]]; then
            echo -e " - https://$domain  --> localhost:${domain_ports[$domain]}"
        else
            echo -e " - http://$domain   --> localhost:${domain_ports[$domain]}"
        fi
    done
    echo "------------------------------------------------"
    echo -e "${Cyan}Advice:${NC} If you see a 'Welcome to Nginx' page instead of your app, check if your app is really running on the specified port."
}

# --- Main Execution Flow ---
detect_os
setup_environment
collect_info
verify_backends
clean_existing
generate_configs
setup_ssl
finalize

exit 0
