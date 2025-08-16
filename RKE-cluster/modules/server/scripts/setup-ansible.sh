#!/bin/bash
# Setup script for RKE Server Module - Post-Instance Setup
# This script is designed to run AFTER Terraform creates instances with Ansible pre-installed

set -e

echo "🔧 Setting up RKE Server Module on instances with pre-installed Ansible..."

# Check if we're running on an instance or locally
if [ -f "/opt/ansible-playbook" ]; then
    echo "✅ Running on instance with Ansible pre-installed"
    PLAYBOOK_DIR="/opt/ansible-playbook"
    cd "$PLAYBOOK_DIR"
else
    echo "⚠️  Running locally - this script is meant for instances"
    echo "   The instances should already have Ansible installed via userdata.sh"
    echo "   This script will prepare files for remote execution"
    PLAYBOOK_DIR="./ansible"
    cd "$PLAYBOOK_DIR"
fi

# Check if ansible-galaxy is available
if ! command -v ansible-galaxy &> /dev/null; then
    echo "❌ ansible-galaxy not found. Please ensure Ansible is installed."
    echo "   If running locally, install Ansible first."
    echo "   If running on instance, check userdata.sh execution"
    exit 1
fi

# Check if requirements.yml exists
if [ ! -f "requirements.yml" ]; then
    echo "❌ requirements.yml not found. Please run this script from the module directory."
    exit 1
fi

# Install Ansible collections
echo "📦 Installing required Ansible collections..."
ansible-galaxy collection install -r requirements.yml

echo "✅ Ansible setup completed successfully!"
echo ""

if [ -f "/opt/ansible-playbook" ]; then
    echo "🚀 Running on instance - ready to execute playbooks!"
    echo ""
    echo "📋 To run the server playbook:"
    echo "   cd $PLAYBOOK_DIR"
    echo "   ansible-playbook -i 'localhost,' -c local rke-server-playbook.yml \\"
    echo "     --extra-vars \"cluster_name=your-cluster region=your-region\""
    echo ""
    echo "🔍 The playbook will:"
    echo "   - Configure the server node"
    echo "   - Install Docker and RKE server"
    echo "   - Initialize the RKE cluster"
    echo "   - Generate kubeconfig and join tokens"
    echo ""
    echo "⚠️  Important: Run this on the FIRST server node only!"
    echo "   Other server nodes will join automatically"
else
    echo "📋 Next steps for local execution:"
    echo "1. Run 'terraform init' to initialize the module"
    echo "2. Run 'terraform plan' to see what will be created"
    echo "3. Run 'terraform apply' to create the infrastructure"
    echo "4. SSH into the instances and run the playbooks manually"
    echo ""
    echo "🔍 For manual execution on instances:"
    echo "   ssh -i your-key.pem ubuntu@instance-ip"
    echo "   cd /opt/ansible-playbook"
    echo "   ansible-playbook -i 'localhost,' -c local rke-server-playbook.yml \\"
    echo "     --extra-vars \"cluster_name=your-cluster region=your-region\""
    echo ""
    echo "⚠️  Important: Ensure your server instances are tagged with:"
    echo "   Name = 'your-cluster-rke-server*'"
    echo "   Run the server playbook on the FIRST server node only!"
fi 