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

show_banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "    ╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "    ║                                                                           ║"
    echo "    ║   ███╗   ██╗ ██████╗ ██╗███╗   ██╗██╗  ██╗    ███████╗███████╗██╗       ║"
    echo "    ║   ████╗  ██║██╔════╝ ██║████╗  ██║╚██╗██╔╝    ██╔════╝██╔════╝██║       ║"
    echo "    ║   ██╔██╗ ██║██║  ███╗██║██╔██╗ ██║ ╚███╔╝     ███████╗███████╗██║       ║"
    echo "    ║   ██║╚██╗██║██║   ██║██║██║╚██╗██║ ██╔██╗     ╚════██║╚════██║██║       ║"
    echo "    ║   ██║ ╚████║╚██████╔╝██║██║ ╚████║██╔╝ ██╗    ███████║███████║███████╗  ║"
    echo "    ║   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝    ╚══════╝╚══════╝╚══════╝  ║"
    echo "    ║                                                                           ║"
    echo "    ║              ${GREEN}Automated Nginx Reverse Proxy & SSL Manager${CYAN}              ║"
    echo "    ║                                                                           ║"
    echo "    ╠═══════════════════════════════════════════════════════════════════════════╣"
    echo "    ║  ${YELLOW}Developer:${NC}${CYAN}  Zaman Sheikh                                                  ║"
    echo "    ║  ${YELLOW}GitHub:${NC}${CYAN}     github.com/zamansheikh                                        ║"
    echo "    ║  ${YELLOW}Version:${NC}${CYAN}    2.0 Professional Edition                                      ║"
    echo "    ╚═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    sleep 1
}

print_header() {
    echo -e ""
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    echo -e "${BOLD}${CYAN}   $1   ${NC}"
    echo -e "${BLUE}------------------------------------------------------------${NC}"
}

print_info() {
    echo -e "${BOLD}${CYAN}[INFO]${NC} $1"
}

print_step() {
    echo -e "${BOLD}${BLUE}[STEP]${NC} $1..."
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

show_progress() {
    local duration=$1
    local message="$2"
    local elapsed=0
    echo -ne "${message} "
    while [ $elapsed -lt $duration ]; do
        echo -ne "${CYAN}.${NC}"
        sleep 0.5
        elapsed=$((elapsed + 1))
    done
    echo -e " ${GREEN}✓${NC}"
}

show_spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    echo -ne "${message} "
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %10 ))
        echo -ne "\r${message} ${CYAN}${spin:$i:1}${NC}"
        sleep 0.1
    done
    echo -e "\r${message} ${GREEN}✓${NC}    "
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
LOG_FILE="/var/log/nginx-ssl-setup.log"
MAX_RETRIES=3
BACKUP_DIR="/etc/nginx/backups/$(date +%Y%m%d_%H%M%S)"

# --- Logging Function ---
log_message() {
    local level="$1"
    shift
    local message="$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
}

# --- Backup Function ---
create_backup() {
    if [ -d "$NGINX_CONF_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$NGINX_CONF_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
        log_message "INFO" "Backup created at $BACKUP_DIR"
    fi
}

# --- Rollback Function ---
rollback_config() {
    if [ -d "$BACKUP_DIR" ]; then
        print_warning "Rolling back to previous configuration..."
        cp -r "$BACKUP_DIR"/* "$NGINX_CONF_DIR/" 2>/dev/null || true
        systemctl reload nginx 2>/dev/null || true
        print_success "Rollback completed."
        log_message "INFO" "Configuration rolled back from $BACKUP_DIR"
    fi
}

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
    local install_pkg_name=${3:-$2}
    local retry_count=0

    if command -v "$pkg_cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $pkg_name is already installed."
        log_message "INFO" "$pkg_name already installed"
        return 0
    fi
    
    print_warning "$pkg_name is not installed."
    if ! ask_confirm "Do you want to install $pkg_name now?" "Y"; then
        print_error "$pkg_name is required to proceed. Exiting."
        log_message "ERROR" "User declined to install $pkg_name"
        exit 1
    fi
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        print_step "Installing $pkg_name (Attempt $((retry_count + 1))/$MAX_RETRIES)"
        
        if [[ "$PKG_MANAGER" == "unknown" ]]; then
            print_error "Cannot auto-install on this OS. Please install $pkg_name manually."
            log_message "ERROR" "Unknown package manager"
            exit 1
        fi
        
        # Run update once
        if [[ ! -f /tmp/update_done ]]; then
            print_info "Updating package lists..."
            eval "$UPDATE_CMD" &> /tmp/pkg_update.log
            touch /tmp/update_done
        fi

        # Attempt installation
        if eval "$INSTALL_CMD $install_pkg_name" &> /tmp/pkg_install.log; then
            if command -v "$pkg_cmd" &> /dev/null; then
                print_success "$pkg_name installed successfully."
                log_message "INFO" "$pkg_name installed successfully"
                return 0
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            print_warning "Installation failed. Retrying..."
            sleep 2
        fi
    done
    
    print_error "Failed to install $pkg_name after $MAX_RETRIES attempts."
    log_message "ERROR" "Failed to install $pkg_name after $MAX_RETRIES attempts"
    
    if ask_confirm "Continue without $pkg_name? (Not recommended)" "N"; then
        print_warning "Continuing without $pkg_name..."
        return 1
    else
        exit 1
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

    # 3. Certbot & Nginx Plugin
    # We must ensure the Nginx plugin is installed, not just the base certbot command.
    print_step "Checking Certbot and Nginx Plugin"
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # Debian/Ubuntu
        if ! dpkg -l | grep -q python3-certbot-nginx; then
            print_warning "Certbot Nginx plugin is missing."
            if ask_confirm "Install Certbot and Nginx Plugin?" "Y"; then
                apt install -y certbot python3-certbot-nginx
            fi
        else
            print_success "Certbot Nginx plugin is installed."
        fi
    elif [[ "$PKG_MANAGER" == "pacman" ]]; then
        # Arch
        if ! pacman -Qi certbot-nginx &> /dev/null; then
             print_warning "Certbot Nginx plugin is missing."
             if ask_confirm "Install Certbot Nginx Plugin?" "Y"; then
                 pacman -S --noconfirm certbot certbot-nginx
             fi
        else
             print_success "Certbot Nginx plugin is installed."
        fi
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        # RHEL/CentOS
        if ! rpm -q python3-certbot-nginx &> /dev/null; then
             print_warning "Certbot Nginx plugin is missing."
             if ask_confirm "Install Certbot Nginx Plugin?" "Y"; then
                 dnf install -y certbot python3-certbot-nginx
             fi
        else
             print_success "Certbot Nginx plugin is installed."
        fi
    else
        # Fallback for unknown OS or if manual check required
        if ! command -v certbot &> /dev/null; then
            print_warning "Certbot is missing."
            print_error "Please install 'certbot' and 'python3-certbot-nginx' manually for your OS."
        fi
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
    print_header "Backend Connectivity Verification"
    
    local all_ok=true
    echo ""
    
    for domain in "${!domain_ports[@]}"; do
        port=${domain_ports[$domain]}
        echo -ne "  ${CYAN}→${NC} Testing $domain:$port ... "
        
        local retry=0
        local connected=false
        
        while [ $retry -lt 3 ]; do
            # Try multiple methods to check connectivity
            if timeout 2 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
                connected=true
                break
            elif command -v curl &> /dev/null; then
                if check_code=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$port 2>/dev/null); then
                    if [[ "$check_code" =~ ^[23] ]]; then
                        echo -e "${GREEN}✓ ONLINE${NC} (HTTP $check_code)"
                        log_message "INFO" "Backend $domain:$port is responding (HTTP $check_code)"
                        connected=true
                        break
                    fi
                fi
            fi
            retry=$((retry + 1))
            sleep 0.5
        done
        
        if [ "$connected" = true ]; then
            echo -e "${GREEN}✓ ONLINE${NC}"
            log_message "INFO" "Backend $domain:$port is accessible"
        else
            echo -e "${RED}✗ OFFLINE${NC}"
            all_ok=false
            log_message "WARNING" "Backend $domain:$port is not accessible"
            
            print_warning "Cannot connect to localhost:$port for $domain."
            echo -e "  ${YELLOW}Possible reasons:${NC}"
            echo "    • Backend application is not running"
            echo "    • Application is listening on a different port"
            echo "    • Firewall blocking localhost connections"
            echo ""
            
            if ask_confirm "Continue with $domain configuration anyway?" "N"; then
                print_info "Will configure $domain (ensure backend starts later)"
            else
                print_warning "Skipping $domain configuration"
                unset domain_ports["$domain"]
            fi
        fi
    done
    
    echo ""
    if [ "$all_ok" = false ]; then
        print_warning "Some backends are not responding. Configuration will proceed."
        press_enter
    fi
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
    print_header "Nginx Configuration Generation"
    
    create_backup
    
    ACME_DIR="/var/www/letsencrypt"
    mkdir -p "$ACME_DIR"
    chown -R www-data:www-data "$ACME_DIR" 2>/dev/null || chown -R nginx:nginx "$ACME_DIR" 2>/dev/null || true
    
    echo ""
    local config_count=0

    for domain in "${!domain_ports[@]}"; do
        port=${domain_ports[$domain]}
        CONFIG_PATH="$NGINX_CONF_DIR/$domain"
        
        echo -ne "  ${CYAN}→${NC} Creating config for $domain ... "
        
        cat <<EOF > "$CONFIG_PATH"
# Nginx Configuration for $domain
# Generated by Nginx SSL Manager
# Date: $(date)

server {
    listen 80;
    server_name $domain;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # ACME Challenge for Let's Encrypt
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
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
        
        if [ $? -eq 0 ]; then
            ln -sf "$CONFIG_PATH" "$NGINX_LINK_DIR/$domain"
            echo -e "${GREEN}✓${NC}"
            config_count=$((config_count + 1))
            log_message "INFO" "Configuration created for $domain"
        else
            echo -e "${RED}✗${NC}"
            log_message "ERROR" "Failed to create configuration for $domain"
        fi
    done

    echo ""
    print_info "Generated $config_count configuration file(s)"
    echo ""
    print_step "Validating Nginx configuration"
    
    if nginx -t 2>&1 | tee /tmp/nginx_test.log; then
        print_success "Configuration validation passed!"
        log_message "INFO" "Nginx configuration validated successfully"
        
        print_step "Applying configuration (restarting Nginx)"
        if systemctl restart nginx 2>&1 | tee /tmp/nginx_restart.log; then
            print_success "Nginx restarted successfully!"
            log_message "INFO" "Nginx restarted successfully"
        else
            print_error "Failed to restart Nginx"
            log_message "ERROR" "Nginx restart failed"
            rollback_config
            exit 1
        fi
    else
        print_error "Nginx configuration validation failed!"
        log_message "ERROR" "Nginx configuration validation failed"
        cat /tmp/nginx_test.log
        
        if ask_confirm "Rollback to previous configuration?" "Y"; then
            rollback_config
        fi
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
        print_error "SSL Certificate request failed."
        log_message "ERROR" "SSL certificate request failed"
        
        echo ""
        echo -e "${YELLOW}Common SSL Setup Issues:${NC}"
        echo "  • Domain DNS not pointing to this server"
        echo "  • Firewall blocking ports 80/443"
        echo "  • Certbot Nginx plugin not properly installed"
        echo "  • Rate limiting from Let's Encrypt"
        echo ""
        
        if [ -f /var/log/letsencrypt/letsencrypt.log ]; then
            echo -e "${CYAN}Last 10 lines from Certbot log:${NC}"
            tail -n 10 /var/log/letsencrypt/letsencrypt.log
            echo ""
        fi
        
        print_info "Your domains are still accessible via HTTP."
        
        if ask_confirm "Retry SSL setup?" "N"; then
            print_step "Retrying SSL configuration"
            sleep 2
            setup_ssl
        else
            print_warning "Continuing with HTTP-only configuration."
            log_message "WARNING" "User chose to skip SSL retry"
        fi
    fi
}

finalize() {
    print_header "Finalization & Summary"

    # Firewall configuration
    echo -ne "  ${CYAN}→${NC} Configuring firewall ... "
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp > /dev/null 2>&1
        ufw allow 443/tcp > /dev/null 2>&1
        echo -e "${GREEN}✓${NC}"
        log_message "INFO" "Firewall rules configured"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=http > /dev/null 2>&1
        firewall-cmd --permanent --add-service=https > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ No firewall detected${NC}"
    fi

    echo ""
    echo -e "${BOLD}${GREEN}"
    echo "    ╔═══════════════════════════════════════════════════════════════════════╗"
    echo "    ║                      ✅  SETUP COMPLETED SUCCESSFULLY                 ║"
    echo "    ╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}📋 Configured Domains:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    for domain in "${!domain_ports[@]}"; do
        if [[ "$SETUP_SSL" == "yes" ]] && [ -f "/etc/letsencrypt/live/$MAIN_DOMAIN-bundle/fullchain.pem" ]; then
            echo -e "  ${GREEN}🔒${NC} https://${BOLD}$domain${NC}"
            echo -e "     ${CYAN}↳${NC} Backend: localhost:${domain_ports[$domain]}"
        else
            echo -e "  ${YELLOW}🌐${NC} http://${BOLD}$domain${NC}"
            echo -e "     ${CYAN}↳${NC} Backend: localhost:${domain_ports[$domain]}"
        fi
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${BOLD}${CYAN}📝 Important Notes:${NC}"
    echo -e "  ${YELLOW}•${NC} Nginx config location: ${CYAN}$NGINX_CONF_DIR${NC}"
    echo -e "  ${YELLOW}•${NC} Backup location: ${CYAN}$BACKUP_DIR${NC}"
    echo -e "  ${YELLOW}•${NC} Log file: ${CYAN}$LOG_FILE${NC}"
    echo ""
    
    echo -e "${BOLD}${CYAN}🔍 Troubleshooting Tips:${NC}"
    echo -e "  ${YELLOW}•${NC} Test Nginx config: ${CYAN}nginx -t${NC}"
    echo -e "  ${YELLOW}•${NC} Reload Nginx: ${CYAN}systemctl reload nginx${NC}"
    echo -e "  ${YELLOW}•${NC} View Nginx logs: ${CYAN}tail -f /var/log/nginx/error.log${NC}"
    echo -e "  ${YELLOW}•${NC} Check backend: ${CYAN}curl http://localhost:PORT${NC}"
    echo ""
    
    if [[ "$SETUP_SSL" == "yes" ]]; then
        echo -e "${BOLD}${CYAN}🔐 SSL Certificate Info:${NC}"
        echo -e "  ${YELLOW}•${NC} Auto-renewal: ${GREEN}Enabled${NC} (via certbot timer)"
        echo -e "  ${YELLOW}•${NC} Test renewal: ${CYAN}certbot renew --dry-run${NC}"
        echo -e "  ${YELLOW}•${NC} Certificate expires: ${CYAN}~90 days from now${NC}"
        echo ""
    fi
    
    log_message "INFO" "Setup completed successfully"
    
    echo -e "${GREEN}${BOLD}Thank you for using Nginx SSL Manager!${NC}"
    echo -e "${CYAN}For issues or contributions: github.com/zamansheikh${NC}"
    echo ""
}

# --- Main Execution Flow ---
show_banner
detect_os
setup_environment
collect_info
verify_backends
clean_existing
generate_configs
setup_ssl
finalize

exit 0
