#!/bin/bash

echo "🔍 Getting VPC information for VPN configuration..."
echo ""

echo "📋 From your VPC module, run:"
echo "   cd ../VPC"
echo "   terraform output -json"
echo ""

echo "📋 From your RKE-cluster module, run:"
echo "   cd ../RKE-cluster/dev-cluster"
echo "   terraform output -json"
echo ""

echo "🔧 Then update vpn/terraform.tfvars with:"
echo "   - vpc_id: The VPC ID from VPC module"
echo "   - subnet_ids: The subnet IDs where your RKE instances are located"
echo "   - vpc_cidr: The VPC CIDR block"
echo ""

echo "💡 Tip: You can also run these commands to get specific values:"
echo "   terraform output vpc_id"
echo "   terraform output subnet_ids"
echo "   terraform output vpc_cidr"
