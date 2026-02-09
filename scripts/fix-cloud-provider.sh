#!/bin/bash
set -e

echo "=========================================="
echo "Fixing RKE2 Cloud Provider Configuration"
echo "=========================================="

SSH_KEY="${1:-~/.ssh/rke-key}"

# Get all node IPs
SERVER_IPS=$(kubectl get nodes -l node-role.kubernetes.io/control-plane=true -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
AGENT_IPS=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo "Found server nodes: $SERVER_IPS"
echo "Found agent nodes: $AGENT_IPS"
echo ""

# Function to fix a node
fix_node() {
  local IP=$1
  local TYPE=$2
  
  echo "=========================================="
  echo "Fixing $TYPE node: $IP"
  echo "=========================================="
  
  # Add cloud-provider-name to config if not present
  ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$IP << 'ENDSSH'
    if ! grep -q "cloud-provider-name" /etc/rancher/rke2/config.yaml; then
      echo "Adding cloud-provider-name to config..."
      sudo sed -i '/^cni:/a cloud-provider-name: "aws"' /etc/rancher/rke2/config.yaml
      echo "Updated config:"
      sudo cat /etc/rancher/rke2/config.yaml
    else
      echo "cloud-provider-name already present in config"
    fi
ENDSSH
  
  echo "✓ Config updated on $IP"
}

# Fix all server nodes
for IP in $SERVER_IPS; do
  fix_node $IP "server"
done

# Fix all agent nodes  
for IP in $AGENT_IPS; do
  fix_node $IP "agent"
done

echo ""
echo "=========================================="
echo "Restarting RKE2 Services"
echo "=========================================="
echo ""
echo "⚠️  This will cause a brief disruption"
echo "⚠️  Server nodes will restart one at a time"
echo "⚠️  Agent nodes will restart in parallel"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Restart server nodes one at a time (to maintain quorum)
for IP in $SERVER_IPS; do
  echo "Restarting server: $IP"
  ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$IP "sudo systemctl restart rke2-server"
  
  echo "Waiting for server to be ready..."
  sleep 30
  
  # Wait for node to be Ready
  NODE_NAME=$(kubectl get nodes -o wide | grep $IP | awk '{print $1}')
  kubectl wait --for=condition=Ready node/$NODE_NAME --timeout=120s
  echo "✓ Server $IP is ready"
done

# Restart all agent nodes in parallel
echo ""
echo "Restarting all agent nodes..."
for IP in $AGENT_IPS; do
  ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$IP "sudo systemctl restart rke2-agent" &
done

# Wait for all background jobs
wait

echo "Waiting for all nodes to be ready..."
sleep 30

# Check all nodes are Ready
kubectl wait --for=condition=Ready node --all --timeout=180s

echo ""
echo "=========================================="
echo "Verifying Provider IDs"
echo "=========================================="
echo ""

kubectl get nodes -o custom-columns=NAME:.metadata.name,PROVIDER-ID:.spec.providerID

echo ""
echo "=========================================="
echo "Checking AWS Load Balancer Controller"
echo "=========================================="
echo ""

# Give controller time to reconcile
echo "Waiting 60 seconds for AWS LB Controller to reconcile..."
sleep 60

# Restart AWS LB Controller to pick up new providerIDs
echo "Restarting AWS Load Balancer Controller pods..."
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
kubectl rollout status deployment aws-load-balancer-controller -n kube-system --timeout=120s

echo ""
echo "=========================================="
echo "✓ Cloud Provider Fix Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for target registration"
echo "2. Check target health with:"
echo "   aws elbv2 describe-target-health --region us-west-2 --target-group-arn <arn>"
echo "3. Test access to:"
echo "   - https://nginx.dev.foobar.support"
echo "   - https://traefik.dev.foobar.support"
echo "   - https://rancher.dev.foobar.support"
