#!/bin/bash
# Setup script for RKE Agent Module Ansible requirements

set -e

echo "🔧 Setting up Ansible environment for RKE Agent Module..."

# Check if ansible-galaxy is available
if ! command -v ansible-galaxy &> /dev/null; then
    echo "❌ ansible-galaxy not found. Please install Ansible first."
    echo "   Visit: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html"
    exit 1
fi

# Check if requirements.yml exists
if [ ! -f "ansible/requirements.yml" ]; then
    echo "❌ ansible/requirements.yml not found. Please run this script from the module directory."
    exit 1
fi

# Install Ansible collections
echo "📦 Installing required Ansible collections..."
cd ansible
ansible-galaxy collection install -r requirements.yml

echo "✅ Ansible setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Run 'terraform init' to initialize the module"
echo "2. Run 'terraform plan' to see what will be created"
echo "3. Run 'terraform apply' to create the infrastructure and run Ansible"
echo ""
echo "🔍 For manual Ansible execution:"
echo "   cd ansible"
echo "   ansible-playbook -i inventory.ini rke-agent-playbook.yml \\"
echo "     --extra-vars \"cluster_name=your-cluster region=your-region\"" 