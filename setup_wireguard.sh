#!/bin/bash

# Advanced WireGuard VPN Setup Script

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Function to detect the primary network interface
detect_interface() {
    ip route | grep default | awk '{print $5}' | head -n1
}

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/fedora-release ]; then
        echo "fedora"
    else
        echo "unknown"
    fi
}

# Install WireGuard based on the distribution
install_wireguard() {
    local distro=$1
    case $distro in
        debian|ubuntu)
            apt update
            apt install -y wireguard
            ;;
        fedora|centos|rhel)
            dnf install -y wireguard-tools
            ;;
        *)
            echo "Unsupported distribution. Please install WireGuard manually."
            exit 1
            ;;
    esac
}

# Main setup function
setup_wireguard() {
    local interface=$(detect_interface)
    local distro=$(detect_distro)

    echo "Detected primary interface: $interface"
    echo "Detected distribution: $distro"

    # Install WireGuard
    install_wireguard $distro

    # Generate keys
    private_key=$(wg genkey)
    public_key=$(echo $private_key | wg pubkey)

    # Set up WireGuard configuration
    cat << EOF > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $private_key
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $interface -j MASQUERADE

# Client configuration will be added here
EOF

    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-sysctl.conf
    sysctl -p

    # Configure firewall based on distribution
    case $distro in
        debian|ubuntu)
            ufw allow 51820/udp
            ufw reload
            ;;
        fedora|centos|rhel)
            firewall-cmd --add-port=51820/udp --permanent
            firewall-cmd --reload
            ;;
    esac

    # Start WireGuard
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0

    # Generate client configuration
    client_private_key=$(wg genkey)
    client_public_key=$(echo $client_private_key | wg pubkey)
    server_public_key=$public_key
    server_endpoint=$(curl -s ifconfig.me):51820

    cat << EOF > client_config.conf
[Interface]
PrivateKey = $client_private_key
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $server_public_key
Endpoint = $server_endpoint
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    # Add client to server configuration
    echo "" >> /etc/wireguard/wg0.conf
    echo "[Peer]" >> /etc/wireguard/wg0.conf
    echo "PublicKey = $client_public_key" >> /etc/wireguard/wg0.conf
    echo "AllowedIPs = 10.0.0.2/32" >> /etc/wireguard/wg0.conf

    # Restart WireGuard to apply changes
    systemctl restart wg-quick@wg0

    echo "WireGuard setup complete!"
    echo "Client configuration saved in client_config.conf"
    echo "Use this configuration file on your client devices"
}

# Run the setup
setup_wireguard