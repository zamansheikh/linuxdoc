#!/bin/bash

# Arch Linux Network Configuration Script
# This script configures IP address, gateway, subnet, and DNS settings.
# Script made by Zaman Sheikh

###########################
#                        #
#  NETWORK SETUP SCRIPT  #
#    BY ZAMAN SHEIKH     #
#                        #
###########################

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo." >&2
    exit 1
fi

# Function to prompt for input with a default value
prompt() {
    local message=$1
    local default=$2
    read -p "$message [$default]: " input
    echo "${input:-$default}"
}

# Display available network interfaces
interfaces=$(ls /sys/class/net | grep -v lo)
echo "Available network interfaces:"
i=1
interface_array=()
for iface in $interfaces; do
    echo "$i) $iface"
    interface_array+=("$iface")
    i=$((i + 1))
done

# Prompt user to select an interface
while true; do
    selection=$(prompt "Select a network interface by number" "1")
    if [[ $selection -ge 1 && $selection -le ${#interface_array[@]} ]]; then
        interface=${interface_array[$((selection - 1))]}
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

# Collect network configuration details
ip_address=$(prompt "Enter the static IP address" "192.168.1.100")
gateway=$(prompt "Enter the gateway address" "192.168.1.1")
subnet_mask=$(prompt "Enter the subnet mask" "24")
dns_servers=$(prompt "Enter the DNS servers (comma-separated)" "8.8.8.8,8.8.4.4")

# Convert DNS servers to a list
IFS=',' read -ra dns_array <<< "$dns_servers"

# Configure the IP address, gateway, and subnet
ip addr flush dev $interface
ip addr add ${ip_address}/${subnet_mask} dev $interface
ip link set $interface up
ip route add default via $gateway

# Configure persistent network settings using systemd-networkd
config_dir="/etc/systemd/network"
mkdir -p $config_dir
config_file="$config_dir/20-static.network"

cat <<EOF > $config_file
[Match]
Name=$interface

[Network]
Address=$ip_address/$subnet_mask
Gateway=$gateway
EOF

# Add DNS servers to the configuration
if [[ ${#dns_array[@]} -gt 0 ]]; then
    echo "DNS=${dns_array[*]}" >> $config_file
fi

# Restart systemd-networkd for changes to take effect
systemctl restart systemd-networkd

# Verify the configuration
ip addr show dev $interface
ip route

# Confirm DNS resolution
for dns in "${dns_array[@]}"; do
    echo "Testing DNS server: $dns"
    ping -c 2 $dns || echo "Failed to reach DNS server: $dns"
done

echo "Network configuration complete."
