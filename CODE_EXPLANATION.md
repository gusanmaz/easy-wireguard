# EasyWireGuard VPN: Complete Code Explanation

This document provides a comprehensive explanation of the EasyWireGuard VPN setup script, including all code sections.

## Full Script

Let's start by presenting the entire script, then we'll break it down section by section:

```bash
#!/bin/bash

# Enhanced WireGuard VPN Setup Script

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

# Function to set up enhanced security measures
setup_enhanced_security() {
    local interface=$1
    local distro=$2

    # Set up DNS on the server
    case $distro in
        debian|ubuntu)
            apt install -y unbound
            ;;
        fedora|centos|rhel)
            dnf install -y unbound
            ;;
    esac

    cat << EOF > /etc/unbound/unbound.conf
server:
    verbosity: 1
    interface: 10.0.0.1
    port: 53
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    
    # Use Google and Cloudflare as fallback
    forward-zone:
        name: "."
        forward-addr: 8.8.8.8
        forward-addr: 1.1.1.1
EOF
    systemctl enable unbound
    systemctl start unbound

    # Set up iptables rules for kill switch functionality
    iptables -A INPUT -i wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i wg0 -j ACCEPT
    iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
    iptables -A INPUT -p udp --dport 51820 -j ACCEPT
    iptables -A INPUT -s 10.0.0.0/24 -p tcp --dport 53 -j ACCEPT
    iptables -A INPUT -s 10.0.0.0/24 -p udp --dport 53 -j ACCEPT
    iptables -P INPUT DROP
    iptables -P FORWARD DROP

    # Make iptables rules persistent
    case $distro in
        debian|ubuntu)
            apt install -y iptables-persistent
            netfilter-persistent save
            ;;
        fedora|centos|rhel)
            echo "Please manually save iptables rules for Fedora/CentOS/RHEL"
            ;;
    esac

    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-sysctl.conf
    sysctl -p

    # Set up fail2ban to protect SSH
    case $distro in
        debian|ubuntu)
            apt install -y fail2ban
            ;;
        fedora|centos|rhel)
            dnf install -y fail2ban
            ;;
    esac
    systemctl enable fail2ban
    systemctl start fail2ban
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

    # Set up enhanced security measures
    setup_enhanced_security $interface $distro

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
DNS = 10.0.0.1

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

    echo "Enhanced WireGuard setup complete!"
    echo "Client configuration saved in client_config.conf"
    echo "Use this configuration file on your client devices"
    echo "Please review the README for important security information and client setup instructions."
}

# Run the setup
setup_wireguard
```

Now, let's break down each section and explain its purpose and functionality.

## Script Breakdown

### 1. Initial Check

```bash
#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi
```

- The script starts with a shebang (`#!/bin/bash`) to specify it should be run with bash.
- It checks if the script is being run with root privileges by checking the effective user ID (`$EUID`). This is necessary because many operations in the script require root access.

### 2. Utility Functions

```bash
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
```

- `detect_interface()`: This function finds the primary network interface by looking at the default route.
- `detect_distro()`: This function determines the Linux distribution by checking specific files. It supports detection of systems using `/etc/os-release`, Debian-based systems, and Fedora-based systems.

### 3. WireGuard Installation

```bash
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
```

This function installs WireGuard using the appropriate package manager based on the detected distribution.

### 4. Enhanced Security Setup

```bash
# Function to set up enhanced security measures
setup_enhanced_security() {
    local interface=$1
    local distro=$2

    # Set up DNS on the server
    case $distro in
        debian|ubuntu)
            apt install -y unbound
            ;;
        fedora|centos|rhel)
            dnf install -y unbound
            ;;
    esac

    cat << EOF > /etc/unbound/unbound.conf
server:
    verbosity: 1
    interface: 10.0.0.1
    port: 53
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    
    # Use Google and Cloudflare as fallback
    forward-zone:
        name: "."
        forward-addr: 8.8.8.8
        forward-addr: 1.1.1.1
EOF
    systemctl enable unbound
    systemctl start unbound

    # Set up iptables rules for kill switch functionality
    iptables -A INPUT -i wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i wg0 -j ACCEPT
    iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
    iptables -A INPUT -p udp --dport 51820 -j ACCEPT
    iptables -A INPUT -s 10.0.0.0/24 -p tcp --dport 53 -j ACCEPT
    iptables -A INPUT -s 10.0.0.0/24 -p udp --dport 53 -j ACCEPT
    iptables -P INPUT DROP
    iptables -P FORWARD DROP

    # Make iptables rules persistent
    case $distro in
        debian|ubuntu)
            apt install -y iptables-persistent
            netfilter-persistent save
            ;;
        fedora|centos|rhel)
            echo "Please manually save iptables rules for Fedora/CentOS/RHEL"
            ;;
    esac

    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-sysctl.conf
    sysctl -p

    # Set up fail2ban to protect SSH
    case $distro in
        debian|ubuntu)
            apt install -y fail2ban
            ;;
        fedora|centos|rhel)
            dnf install -y fail2ban
            ;;
    esac
    systemctl enable fail2ban
    systemctl start fail2ban
}
```

This function sets up enhanced security measures:
- Installs and configures Unbound as a local DNS resolver.
- Sets up iptables rules for a kill switch and NAT.
- Makes iptables rules persistent (for supported distributions).
- Enables IP forwarding.
- Installs and starts fail2ban for SSH protection.

### 5. Main WireGuard Setup Function

```bash
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

    # Set up enhanced security measures
    setup_enhanced_security $interface $distro

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
DNS = 10.0.0.1

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

    echo "Enhanced WireGuard setup complete!"
    echo "Client configuration saved in client_config.conf"
    echo "Use this configuration file on your client devices"
    echo "Please review the README for important security information and client setup instructions."
}
```

This is the main function that orchestrates the entire setup process:
- Detects the network interface and distribution.
- Installs WireGuard.
- Generates server keys.
- Creates the WireGuard server configuration.
- Sets up enhanced security measures.
- Configures the firewall.
- Starts the WireGuard service.
- Generates a client configuration.
- Adds the client to the server configuration.
- Restarts WireGuard to apply all changes.

###