#!/bin/bash
set -e

# OpenVPN Access Server User Data Script
# This script runs when the EC2 instance starts up

echo "🚀 Starting OpenVPN Access Server setup..."

# The OpenVPN Access Server AMI comes pre-configured
# We just need to set up some basic configurations

# Create a flag file to indicate setup is complete
echo "OpenVPN Access Server initial setup complete" > /var/log/openvpn-setup.log

# Set initial admin password (will be changed on first login)
# Default admin user: openvpn
# Default password: openvpn

echo "✅ OpenVPN Access Server initial setup complete!"
echo "🌐 Access the admin interface at: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):943/admin"
echo "🔑 Initial user: openvpn (set password on first login)"
echo "📱 Client UI available at: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):943/"
