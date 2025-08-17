#!/bin/bash
set -e

# OpenVPN Configuration Script
# This script configures the OpenVPN server using Ansible

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../ansible"

echo "🔧 Configuring OpenVPN Server with Ansible..."

# Check if inventory exists
if [ ! -f "inventory.ini" ]; then
    echo "❌ inventory.ini not found!"
    exit 1
fi

# Check if playbook exists
if [ ! -f "playbook.yml" ]; then
    echo "❌ playbook.yml not found!"
    exit 1
fi

# Get server IP from Terraform output
cd "../terraform"
SERVER_IP=$(terraform output -raw openvpn_public_ip 2>/dev/null || echo "")
cd "../ansible"

if [ -z "$SERVER_IP" ]; then
    echo "❌ Could not get server IP from Terraform output"
    echo "📝 Please run the infrastructure deployment first:"
    echo "   ./scripts/deploy-infrastructure.sh"
    exit 1
fi

echo "🌐 VPN Server IP: $SERVER_IP"

# Update inventory with server IP
echo "📝 Updating Ansible inventory..."
cat > inventory.ini << EOF
[openvpn_servers]
$SERVER_IP

[openvpn_servers:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/$(cd ../terraform && terraform output -raw key_pair_name).pem
ansible_python_interpreter=/usr/bin/python3
ansible_become=yes
ansible_become_method=sudo
ansible_become_user=root
EOF

echo "✅ Inventory updated"

# Wait for server to be ready
echo "⏳ Waiting for server to be ready..."
sleep 30

# Test SSH connection
echo "🔑 Testing SSH connection..."
ansible openvpn_servers -m ping

if [ $? -ne 0 ]; then
    echo "❌ SSH connection failed. Please check:"
    echo "   1. Server is running"
    echo "   2. Security group allows SSH from your IP"
    echo "   3. Key pair is correct"
    exit 1
fi

echo "✅ SSH connection successful"

# Run Ansible playbook
echo "🚀 Running Ansible playbook..."
ansible-playbook -i inventory.ini playbook.yml

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 OpenVPN server configured successfully!"
    echo ""
    echo "📱 Client Configuration:"
    echo "   Download from: http://$SERVER_IP/certs/"
    echo ""
    echo "🔑 Files available:"
    echo "   - client-config.ovpn (main config)"
    echo "   - ca.crt (CA certificate)"
    echo "   - client.crt (client certificate)"
    echo "   - client.key (client private key)"
    echo ""
    echo "📖 Next steps:"
    echo "   1. Download client configuration files"
    echo "   2. Install OpenVPN client on your devices"
    echo "   3. Import the client-config.ovpn file"
    echo "   4. Connect to your VPN!"
else
    echo "❌ Ansible playbook failed"
    exit 1
fi
