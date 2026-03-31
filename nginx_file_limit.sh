#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_GLOBAL_FILE="/etc/nginx/conf.d/99-client-max-body-size.conf"
RELOAD_NGINX="yes"

MODE=""
SIZE=""
DOMAIN=""
LOCATION_PATH=""
CONF_FILE=""
BODY_TIMEOUT=""
BACKUP_FILE=""

print_info() {
    echo "[INFO] $1"
}

print_ok() {
    echo "[OK] $1"
}

print_warn() {
    echo "[WARN] $1"
}

print_err() {
    echo "[ERROR] $1" >&2
}

usage() {
    cat <<EOF
Usage:
  $SCRIPT_NAME --mode global --size 100M [--timeout 300s] [--no-reload]
  $SCRIPT_NAME --mode server --domain example.com --size 100M [--conf /etc/nginx/sites-available/example.com] [--timeout 300s] [--no-reload]
  $SCRIPT_NAME --mode location --domain example.com --path /uploads --size 1G [--conf /etc/nginx/sites-available/example.com] [--timeout 300s] [--no-reload]

Options:
  --mode        global | server | location
  --size        Upload size limit. Examples: 100M, 1G, 512k, 0
  --domain      Domain for server/location mode
  --path        Location path for location mode. Example: /uploads
  --conf        Specific Nginx config file to edit
  --timeout     Optional client_body_timeout value. Examples: 300s, 5m
  --no-reload   Do not run systemctl reload nginx after a successful test
  --help        Show this help

Notes:
  - global mode writes a managed file: $DEFAULT_GLOBAL_FILE
  - server/location mode updates an existing server/location block in a config file
EOF
}

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        print_err "Run as root (use sudo)."
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

validate_size() {
    local value="$1"
    [[ "$value" =~ ^([0-9]+([kKmMgG])?|0)$ ]]
}

validate_timeout() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+(ms|s|m|h)$ ]]
}

backup_file() {
    local file="$1"
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    BACKUP_FILE="${file}.bak.${ts}"

    if [[ -f "$file" ]]; then
        cp -a "$file" "$BACKUP_FILE"
        print_ok "Backup created: $BACKUP_FILE"
    else
        BACKUP_FILE=""
    fi
}

restore_backup() {
    local target="$1"
    if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
        cp -a "$BACKUP_FILE" "$target"
        print_warn "Restored backup after failed validation: $BACKUP_FILE"
    fi
}

detect_server_conf() {
    local domain="$1"
    local candidates=(
        "/etc/nginx/sites-available/${domain}"
        "/etc/nginx/sites-available/${domain}.conf"
        "/etc/nginx/conf.d/${domain}.conf"
        "/etc/nginx/sites-enabled/${domain}"
        "/etc/nginx/sites-enabled/${domain}.conf"
    )

    local f
    for f in "${candidates[@]}"; do
        if [[ -f "$f" ]]; then
            echo "$f"
            return 0
        fi
    done

    return 1
}

find_http_block_range() {
    local file="$1"

    awk '
    {
        line=$0
        opens=gsub(/\{/, "{", line)
        closes=gsub(/\}/, "}", line)

        if (!found && $0 ~ /^[[:space:]]*http[[:space:]]*\{/) {
            start=NR
            targetDepth=depth+1
            found=1
        }

        depth += (opens - closes)

        if (found && !printed && depth < targetDepth) {
            print start ":" NR
            printed=1
            exit
        }
    }
    END {
        if (found && !printed) {
            print start ":" NR
        }
    }
    ' "$file"
}

find_server_block_range_by_domain() {
    local file="$1"
    local domain="$2"

    awk -v domain="$domain" '
    {
        line=$0
        opens=gsub(/\{/, "{", line)
        closes=gsub(/\}/, "}", line)

        if (!inServer && $0 ~ /^[[:space:]]*server[[:space:]]*\{/) {
            inServer=1
            hasDomain=0
            start=NR
            targetDepth=depth+1
        }

        if (inServer && $0 ~ /^[[:space:]]*server_name[[:space:]]+/) {
            tmp=$0
            sub(/^[[:space:]]*server_name[[:space:]]+/, "", tmp)
            gsub(/;/, "", tmp)
            n=split(tmp, parts, /[[:space:]]+/)
            for (i=1; i<=n; i++) {
                if (parts[i] == domain) {
                    hasDomain=1
                }
            }
        }

        depth += (opens - closes)

        if (inServer && depth < targetDepth) {
            if (hasDomain) {
                print start ":" NR
                exit
            }
            inServer=0
            hasDomain=0
            start=0
            targetDepth=0
        }
    }
    ' "$file"
}

find_location_block_range() {
    local file="$1"
    local server_start="$2"
    local server_end="$3"
    local location_path="$4"

    awk -v s="$server_start" -v e="$server_end" -v path="$location_path" '
    {
        line=$0
        opens=gsub(/\{/, "{", line)
        closes=gsub(/\}/, "}", line)

        if (NR >= s && NR <= e) {
            if (!inLocation && $0 ~ /^[[:space:]]*location[[:space:]]+/) {
                tmp=$0
                sub(/^[[:space:]]*location[[:space:]]+/, "", tmp)
                sub(/\{.*/, "", tmp)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", tmp)
                n=split(tmp, parts, /[[:space:]]+/)
                currentPath=parts[n]
                if (currentPath == path) {
                    inLocation=1
                    start=NR
                    targetDepth=depth+1
                }
            }
        }

        depth += (opens - closes)

        if (inLocation && depth < targetDepth) {
            print start ":" NR
            exit
        }
    }
    ' "$file"
}

replace_or_insert_directive_in_range() {
    local file="$1"
    local range_start="$2"
    local range_end="$3"
    local directive_name="$4"
    local directive_value="$5"

    local block_indent
    local directive_indent
    local line_no

    block_indent="$(sed -n "${range_start}p" "$file" | sed -E 's/^([[:space:]]*).*/\1/')"
    directive_indent="${block_indent}    "

    line_no="$(awk -v s="$range_start" -v e="$range_end" -v key="$directive_name" '
        NR >= s && NR <= e && $0 ~ "^[[:space:]]*" key "[[:space:]]+" {
            print NR
            exit
        }
    ' "$file")"

    if [[ -n "$line_no" ]]; then
        sed -i "${line_no}s|^[[:space:]]*${directive_name}[[:space:]]\+[^;]*;|${directive_indent}${directive_name} ${directive_value};|" "$file"
    else
        local insert_at
        insert_at=$((range_start + 1))
        sed -i "${insert_at}i\\${directive_indent}${directive_name} ${directive_value};" "$file"
    fi
}

apply_global_limit() {
    local size="$1"
    local timeout="$2"

    mkdir -p "$(dirname "$DEFAULT_GLOBAL_FILE")"
    backup_file "$DEFAULT_GLOBAL_FILE"

    # Normalize existing line(s) in managed file if present
    if [[ -f "$DEFAULT_GLOBAL_FILE" ]]; then
        sed -i '/^[[:space:]]*client_max_body_size\s\+/d; /^[[:space:]]*client_body_timeout\s\+/d' "$DEFAULT_GLOBAL_FILE" || true
    fi

    {
        echo "# Managed by $SCRIPT_NAME"
        echo "client_max_body_size ${size};"
        if [[ -n "$timeout" ]]; then
            echo "client_body_timeout ${timeout};"
        fi
    } > "$DEFAULT_GLOBAL_FILE"

    # Detect any lingering directive duplicates in other config files
    local foundDupes
    foundDupes=$(grep -R --line-number -E '^[[:space:]]*client_max_body_size\s+' /etc/nginx/conf.d /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/nginx.conf 2>/dev/null | grep -v "^$DEFAULT_GLOBAL_FILE:" | grep -v "\.bak" || true)
    if [[ -n "$foundDupes" ]]; then
        print_warn "Other client_max_body_size definitions exist and may still cause duplicate errors:" 
        echo "$foundDupes"
        print_warn "Consider removing or adjusting them before reloading nginx."
    fi

    print_ok "Global limit written to $DEFAULT_GLOBAL_FILE"
}

apply_server_limit() {
    local conf="$1"
    local domain="$2"
    local size="$3"
    local timeout="$4"

    local range
    local start
    local end

    range="$(find_server_block_range_by_domain "$conf" "$domain")"
    if [[ -z "$range" ]]; then
        print_err "Could not find a server block with server_name containing: $domain"
        return 1
    fi

    start="${range%%:*}"
    end="${range##*:}"

    backup_file "$conf"

    replace_or_insert_directive_in_range "$conf" "$start" "$end" "client_max_body_size" "$size"

    range="$(find_server_block_range_by_domain "$conf" "$domain")"
    start="${range%%:*}"
    end="${range##*:}"

    if [[ -n "$timeout" ]]; then
        replace_or_insert_directive_in_range "$conf" "$start" "$end" "client_body_timeout" "$timeout"
    fi

    print_ok "Server-level limit updated in $conf"
}

apply_location_limit() {
    local conf="$1"
    local domain="$2"
    local location_path="$3"
    local size="$4"
    local timeout="$5"

    local srv_range
    local srv_start
    local srv_end
    local loc_range
    local loc_start
    local loc_end

    srv_range="$(find_server_block_range_by_domain "$conf" "$domain")"
    if [[ -z "$srv_range" ]]; then
        print_err "Could not find a server block with server_name containing: $domain"
        return 1
    fi

    srv_start="${srv_range%%:*}"
    srv_end="${srv_range##*:}"

    loc_range="$(find_location_block_range "$conf" "$srv_start" "$srv_end" "$location_path")"
    if [[ -z "$loc_range" ]]; then
        print_err "Could not find location block path '$location_path' inside server '$domain'"
        return 1
    fi

    loc_start="${loc_range%%:*}"
    loc_end="${loc_range##*:}"

    backup_file "$conf"

    replace_or_insert_directive_in_range "$conf" "$loc_start" "$loc_end" "client_max_body_size" "$size"

    srv_range="$(find_server_block_range_by_domain "$conf" "$domain")"
    srv_start="${srv_range%%:*}"
    srv_end="${srv_range##*:}"
    loc_range="$(find_location_block_range "$conf" "$srv_start" "$srv_end" "$location_path")"
    loc_start="${loc_range%%:*}"
    loc_end="${loc_range##*:}"

    if [[ -n "$timeout" ]]; then
        replace_or_insert_directive_in_range "$conf" "$loc_start" "$loc_end" "client_body_timeout" "$timeout"
    fi

    print_ok "Location-level limit updated in $conf"
}

validate_and_reload() {
    local target_file="$1"

    if ! command_exists nginx; then
        print_err "nginx command not found. Install Nginx first."
        restore_backup "$target_file"
        exit 1
    fi

    if nginx -t >/tmp/nginx_file_limit_test.log 2>&1; then
        print_ok "Nginx configuration test passed"
        if [[ "$RELOAD_NGINX" == "yes" ]]; then
            if systemctl reload nginx >/tmp/nginx_file_limit_reload.log 2>&1; then
                print_ok "Nginx reloaded"
            else
                print_warn "Reload failed. Try: systemctl reload nginx"
                print_warn "Log: /tmp/nginx_file_limit_reload.log"
            fi
        else
            print_info "Skipped reload (--no-reload used)"
        fi
    else
        print_err "Nginx configuration test failed"
        print_err "See: /tmp/nginx_file_limit_test.log"

        # Detect duplicate client_max_body_size definitions for easier troubleshooting
        if grep -q "client_max_body_size" /tmp/nginx_file_limit_test.log; then
            print_warn "Detected client_max_body_size conflict in nginx config."
            print_warn "Current references (excluding managed file):"
            grep -R --line-number -E '^[[:space:]]*client_max_body_size\s+' /etc/nginx/conf.d /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/nginx.conf 2>/dev/null | grep -v "^$DEFAULT_GLOBAL_FILE:"
            print_warn "Edit duplicate entries and re-run the script."
        fi

        restore_backup "$target_file"
        exit 1
    fi
}

interactive_prompt_if_needed() {
    if [[ -n "$MODE" && -n "$SIZE" ]]; then
        return
    fi

    echo "Nginx File Upload Limit Controller"
    echo "1) Global (http scope)"
    echo "2) Server (single domain)"
    echo "3) Location (single path in a domain)"
    read -r -p "Choose mode [1-3]: " choice

    case "$choice" in
        1) MODE="global" ;;
        2) MODE="server" ;;
        3) MODE="location" ;;
        *) print_err "Invalid selection"; exit 1 ;;
    esac

    read -r -p "Enter upload limit (example: 100M, 1G, 0): " SIZE

    if [[ "$MODE" == "server" || "$MODE" == "location" ]]; then
        read -r -p "Enter domain (example.com): " DOMAIN
        read -r -p "Config file path (leave empty to auto-detect): " CONF_FILE
    fi

    if [[ "$MODE" == "location" ]]; then
        read -r -p "Location path (example: /uploads): " LOCATION_PATH
    fi

    read -r -p "Optional client_body_timeout (example: 300s, blank to skip): " BODY_TIMEOUT

    read -r -p "Reload Nginx after successful test? [Y/n]: " reload_answer
    reload_answer="${reload_answer:-Y}"
    if [[ ! "$reload_answer" =~ ^[Yy]$ ]]; then
        RELOAD_NGINX="no"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                MODE="${2:-}"
                shift 2
                ;;
            --size)
                SIZE="${2:-}"
                shift 2
                ;;
            --domain)
                DOMAIN="${2:-}"
                shift 2
                ;;
            --path)
                LOCATION_PATH="${2:-}"
                shift 2
                ;;
            --conf)
                CONF_FILE="${2:-}"
                shift 2
                ;;
            --timeout)
                BODY_TIMEOUT="${2:-}"
                shift 2
                ;;
            --no-reload)
                RELOAD_NGINX="no"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                print_err "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done
}

validate_inputs() {
    MODE="${MODE,,}"

    if [[ -z "$MODE" || -z "$SIZE" ]]; then
        print_err "mode and size are required"
        usage
        exit 1
    fi

    if [[ "$MODE" != "global" && "$MODE" != "server" && "$MODE" != "location" ]]; then
        print_err "--mode must be global, server, or location"
        exit 1
    fi

    if ! validate_size "$SIZE"; then
        print_err "Invalid --size value: $SIZE"
        exit 1
    fi

    if [[ -n "$BODY_TIMEOUT" ]] && ! validate_timeout "$BODY_TIMEOUT"; then
        print_err "Invalid --timeout value: $BODY_TIMEOUT"
        exit 1
    fi

    if [[ "$MODE" == "server" || "$MODE" == "location" ]]; then
        if [[ -z "$DOMAIN" ]]; then
            print_err "--domain is required for $MODE mode"
            exit 1
        fi

        if [[ -z "$CONF_FILE" ]]; then
            if CONF_FILE="$(detect_server_conf "$DOMAIN")"; then
                print_info "Auto-detected config: $CONF_FILE"
            else
                print_err "Could not auto-detect config for $DOMAIN. Use --conf"
                exit 1
            fi
        fi

        if [[ ! -f "$CONF_FILE" ]]; then
            print_err "Config file not found: $CONF_FILE"
            exit 1
        fi
    fi

    if [[ "$MODE" == "location" ]]; then
        if [[ -z "$LOCATION_PATH" ]]; then
            print_err "--path is required for location mode"
            exit 1
        fi

        if [[ "$LOCATION_PATH" != /* ]]; then
            print_err "--path must start with /"
            exit 1
        fi
    fi
}

main() {
    require_root
    parse_args "$@"
    interactive_prompt_if_needed
    validate_inputs

    case "$MODE" in
        global)
            print_info "Applying global upload limit: $SIZE"
            apply_global_limit "$SIZE" "$BODY_TIMEOUT"
            validate_and_reload "$DEFAULT_GLOBAL_FILE"
            ;;
        server)
            print_info "Applying server upload limit: domain=$DOMAIN size=$SIZE"
            apply_server_limit "$CONF_FILE" "$DOMAIN" "$SIZE" "$BODY_TIMEOUT"
            validate_and_reload "$CONF_FILE"
            ;;
        location)
            print_info "Applying location upload limit: domain=$DOMAIN path=$LOCATION_PATH size=$SIZE"
            apply_location_limit "$CONF_FILE" "$DOMAIN" "$LOCATION_PATH" "$SIZE" "$BODY_TIMEOUT"
            validate_and_reload "$CONF_FILE"
            ;;
    esac

    print_ok "Completed"
}

main "$@"
