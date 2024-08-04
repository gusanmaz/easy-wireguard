# EasyWireGuard VPN

## Purpose
EasyWireGuard VPN is a project aimed at simplifying the process of setting up a personal VPN server using WireGuard. It provides an automated script for server setup and comprehensive guidelines for client configuration across various platforms. This project is designed for individuals who want to maintain their privacy and security online by running their own VPN server.

## Supported Distributions
This script should be running on the following Linux distributions:

- Debian 10+
- Ubuntu 20.04+
- Fedora 33+
- CentOS 8+
- RHEL 8+

Note that this script is not tested in these distros, you could create an issue if you are having problem running the script.

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/gusanmaz/easy-wireguard-vpn.git
   cd easywireguard-vpn
   ```

2. Make the script executable:
   ```
   chmod +x setup_wireguard.sh
   ```

3. Run the script as root:
   ```
   sudo ./setup_wireguard.sh
   ```

## Client Setup

### iOS
1. Install the WireGuard app from the App Store.
2. Tap the + button and choose "Create from QR code" or "Create from file".
3. If using a file, transfer `client_config.conf` to your iPhone and select it.
4. Alternatively, generate a QR code from the config file on your server:
   ```
   qrencode -t ansiutf8 < client_config.conf
   ```
5. Scan this QR code with the WireGuard app.

### Android
1. Install the WireGuard app from the Google Play Store.
2. Tap the + button and choose "Create from QR code" or "Create from file".
3. If using a file, transfer `client_config.conf` to your Android device and select it.
4. Alternatively, use the QR code method described in the iOS section.

### Linux (Command Line)
1. Install WireGuard:
    - Debian/Ubuntu: `sudo apt install wireguard`
    - Fedora: `sudo dnf install wireguard-tools`
2. Copy `client_config.conf` to `/etc/wireguard/wg0.conf`
3. Start WireGuard: `sudo wg-quick up wg0`
4. To enable on boot: `sudo systemctl enable wg-quick@wg0`

### Linux (KDE)
1. Go to System Settings > Connections > Add Connection > WireGuard.
2. Import the `client_config.conf` file.

### Linux (GNOME)
1. Go to Settings > Network > VPN > Add VPN.
2. Choose "Import from file" and select `client_config.conf`.

### Windows
1. Download and install the WireGuard client from the official website.
2. Click "Add Tunnel" and choose "Import tunnel(s) from file".
3. Select the `client_config.conf` file.

### macOS
1. Download and install the WireGuard client from the official website.
2. Click "Import tunnel(s) from file" and select `client_config.conf`.

## Troubleshooting

If you're experiencing issues with your VPN connection, try the following steps:

1. Check server status:
   ```
   sudo systemctl status wg-quick@wg0
   ```

2. Verify WireGuard interface:
   ```
   sudo wg show
   ```

3. Check server logs:
   ```
   sudo journalctl -u wg-quick@wg0 -f
   ```

4. Verify IP forwarding is enabled:
   ```
   cat /proc/sys/net/ipv4/ip_forward
   ```
   It should return 1. If not, enable it:
   ```
   echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
   ```

5. Check firewall rules:
    - For UFW (Debian/Ubuntu):
      ```
      sudo ufw status
      ```
    - For firewalld (Fedora/CentOS):
      ```
      sudo firewall-cmd --list-all
      ```

6. Verify the server's public IP:
   ```
   curl ifconfig.me
   ```
   Ensure this matches the Endpoint in your client configuration.

7. Test server reachability:
   ```
   sudo tcpdump -i any udp port 51820
   ```
   Then try to connect from your client. You should see incoming packets.

8. Check client configuration:
    - Ensure the server's public key is correct.
    - Verify the Endpoint IP and port.
    - Check that AllowedIPs is set correctly (usually 0.0.0.0/0 for full tunneling).

## VPS Firewall Settings

Different VPS providers have different ways to configure firewalls. Here are instructions for some popular providers:

### DigitalOcean
1. Go to the Networking section of your droplet.
2. Add an inbound rule allowing UDP traffic on port 51820.

### Linode
1. Go to the Network tab of your Linode.
2. In the Firewall section, add an inbound rule for UDP port 51820.

### Vultr
1. Go to the Firewall section in your server settings.
2. Add a rule to allow inbound UDP traffic on port 51820.

### AWS EC2
1. Go to the Security Groups section in EC2 settings.
2. Edit the inbound rules to allow UDP traffic on port 51820 from anywhere (0.0.0.0/0).

### Google Cloud Platform
1. Go to VPC network > Firewall rules.
2. Create a new rule allowing UDP traffic on port 51820.

Always ensure that you also allow SSH access (usually port 22) to manage your server.

## DNS Configuration and Leak Prevention

Our VPN setup uses a local DNS resolver (Unbound) on the VPN server to enhance privacy and prevent DNS leaks. Here's how it works:

1. The VPN server runs its own DNS resolver at 10.0.0.1.
2. This resolver forwards requests to Google (8.8.8.8) and Cloudflare (1.1.1.1) as fallback options.
3. All client DNS requests go through the VPN tunnel to this local resolver.

To ensure your device uses this secure DNS setup, configure your client as follows:

### Configuring Clients to Use VPN DNS

#### Android
1. Open the WireGuard app
2. Tap on your VPN configuration
3. Tap "Edit"
4. In the "DNS servers" field, enter: 10.0.0.1
5. Tap "Save"

#### iOS
1. Open the WireGuard app
2. Tap on your VPN configuration
3. Tap "Edit"
4. In the "DNS servers" field, enter: 10.0.0.1
5. Tap "Save"

#### Windows
1. Open the WireGuard app
2. Select your VPN configuration
3. Click "Edit"
4. In the "DNS servers" field, enter: 10.0.0.1
5. Click "Save"

#### macOS
1. Open the WireGuard app
2. Select your VPN configuration
3. Click "Edit"
4. In the "DNS servers" field, enter: 10.0.0.1
5. Click "Save"

#### Linux (KDE)
1. Open System Settings
2. Go to "Connections"
3. Select your WireGuard VPN connection
4. Click "IPv4" tab
5. In the "DNS servers" field, enter: 10.0.0.1
6. Click "Apply"

#### Linux (GNOME)
1. Open Settings
2. Go to "Network"
3. Select your WireGuard VPN connection
4. Click the gear icon to edit
5. Go to the "IPv4" tab
6. In the "DNS" field, enter: 10.0.0.1
7. Click "Apply"

By configuring your client to use 10.0.0.1 as the DNS server, you ensure that:
- All DNS queries are routed through the VPN tunnel.
- Requests are resolved by the server's local DNS resolver.
- DNS leaks are prevented, enhancing your privacy.

This setup provides an additional layer of privacy compared to directly using public DNS servers on the client side.

## Safety and Privacy Considerations

While running your own VPN can enhance your privacy and security, there are several factors to consider:

1. **Server Location**: The VPN server will appear as your exit node. Choose a server location that aligns with your privacy needs and local laws.

2. **Logging**: By default, this setup doesn't include logging of user activities. Be aware of any logging you enable and how it might affect user privacy.

3. **DNS Leaks**: Ensure your client is configured to use the VPN's DNS to prevent DNS leaks. The provided configurations use Cloudflare's 1.1.1.1 DNS.

4. **Kill Switch**: Configure a kill switch on your clients to prevent data leaks if the VPN connection drops.

5. **Regular Updates**: Keep both the server and client software updated to patch any security vulnerabilities.

6. **Strong Keys**: The script generates strong keys, but if you're generating keys manually, ensure they're sufficiently complex.

7. **Limited Access**: Limit SSH access to your server and regularly update passwords and access keys.

8. **Traffic Analysis**: While WireGuard encrypts your traffic, a dedicated adversary might still perform traffic analysis. Be aware of this limitation.

9. **Legal Considerations**: Understand the legal implications of running a VPN server in your jurisdiction and the jurisdictions of your users.

10. **Provider Trust**: Your VPS provider can potentially access your server. Choose a reputable provider and consider using additional encryption for sensitive data.

Remember, while a personal VPN provides many benefits, it's not a silver bullet for online anonymity or security. Always use additional security measures for sensitive activities.

## Contributing

Contributions to EasyWireGuard VPN are welcome! Please feel free to submit pull requests, create issues or spread the word.

## Disclaimer and Responsibility

**IMPORTANT: Please read this section carefully before using this VPN solution.**

The owners, contributors, and maintainers of this repository ("EasyWireGuard VPN") are not responsible for any problems, damages, or legal issues that may arise from the use of this VPN setup. By using this software and instructions, you acknowledge and agree to the following:

1. **Use at Your Own Risk**: This VPN solution is provided "as is" without any warranties of any kind, either express or implied. The use of this VPN is entirely at your own risk.

2. **No Liability**: The project owners, contributors, and maintainers shall not be liable for any direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business interruption) arising in any way out of the use of this software.

3. **Legal Compliance**: It is your responsibility to ensure that your use of this VPN complies with all applicable local, state, national, and international laws and regulations.

4. **Privacy and Security**: While this VPN setup aims to enhance privacy and security, no system is 100% secure. The project owners do not guarantee complete anonymity or protection against all forms of surveillance or data breaches.

5. **Modifications and Updates**: You are responsible for maintaining and updating the VPN setup. The project owners are not obligated to provide updates, support, or maintenance.

6. **Third-Party Services**: This VPN setup may involve the use of third-party services or software. The project owners are not responsible for any issues arising from the use of these third-party components.

7. **Ethical Use**: You agree to use this VPN solution ethically and not for any illegal or malicious activities.

By proceeding with the installation and use of this VPN solution, you acknowledge that you have read, understood, and agreed to this disclaimer.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.