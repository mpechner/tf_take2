#!/bin/bash
set -e

# OpenVPN Infrastructure Deployment Script
# This script deploys the OpenVPN server infrastructure using Terraform

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../terraform"

echo "🚀 Deploying OpenVPN Infrastructure..."

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars not found!"
    echo "📝 Please copy terraform.tfvars.example to terraform.tfvars and update the values"
    exit 1
fi

# Check if required variables are set
source terraform.tfvars 2>/dev/null || true

if [ "$comcast_ip" = "YOUR_COMCAST_IP/32" ] || [ "$comcast_ip" = "0.0.0.0/32" ]; then
    echo "❌ Please update comcast_ip in terraform.tfvars to your actual Comcast IP"
    exit 1
fi

# subnet_id is optional - will use first private subnet from VPC if not specified
if [ "$subnet_id" = "subnet-0c9be831d9e3dcdaf" ]; then
    echo "ℹ️  Using first private subnet from VPC (subnet_id not specified)"
fi

if [ "$key_pair_name" = "your-key-pair-name" ]; then
    echo "❌ Please update key_pair_name in terraform.tfvars to your actual key pair name"
    exit 1
fi

echo "✅ Configuration validated"

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Plan the deployment
echo "📋 Planning deployment..."
terraform plan -out=tfplan

# Ask for confirmation
read -p "Do you want to apply this plan? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Apply the plan
echo "🚀 Applying Terraform plan..."
terraform apply tfplan

# Get outputs
echo "📊 Infrastructure deployed successfully!"
echo ""
echo "🔑 SSH Command:"
terraform output ssh_command
echo ""
echo "🌐 VPN Server IP:"
terraform output openvpn_public_ip
echo ""
echo "🎉 OpenVPN Access Server deployed successfully!"
echo ""
echo "🌐 Access the admin interface:"
echo "   https://$(terraform output -raw openvpn_public_ip):943/admin"
echo ""
echo "🔑 Initial user: openvpn (set password on first login)"
echo ""
echo "📱 Client downloads available at:"
echo "   https://$(terraform output -raw openvpn_public_ip):943/"

# Clean up plan file
rm -f tfplan
