#!/bin/bash
set -e

echo "=========================================="
echo "Patching Node Provider IDs to AWS Format"
echo "=========================================="

# Get all nodes with their IPs and instance IDs
kubectl get nodes -o json | jq -r '.items[] | 
  {
    name: .metadata.name,
    ip: (.status.addresses[] | select(.type=="InternalIP") | .address),
    providerID: .spec.providerID
  } | 
  "\(.name)|\(.ip)|\(.providerID)"' | while IFS='|' read -r NODE_NAME IP CURRENT_PROVIDER_ID; do
  
  echo ""
  echo "Processing node: $NODE_NAME (IP: $IP)"
  
  # Get the instance ID from AWS
  INSTANCE_ID=$(aws ec2 describe-instances \
    --region us-west-2 \
    --filters "Name=private-ip-address,Values=$IP" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)
  
  if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "⚠️  Could not find instance ID for $IP"
    continue
  fi
  
  # Get availability zone
  AZ=$(aws ec2 describe-instances \
    --region us-west-2 \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' \
    --output text)
  
  # Build AWS providerID
  NEW_PROVIDER_ID="aws:///$AZ/$INSTANCE_ID"
  
  echo "  Current: $CURRENT_PROVIDER_ID"
  echo "  New:     $NEW_PROVIDER_ID"
  
  # Patch the node
  kubectl patch node $NODE_NAME -p "{\"spec\":{\"providerID\":\"$NEW_PROVIDER_ID\"}}"
  
  echo "✓ Patched $NODE_NAME"
done

echo ""
echo "=========================================="
echo "Verifying New Provider IDs"
echo "=========================================="
echo ""

kubectl get nodes -o custom-columns=NAME:.metadata.name,PROVIDER-ID:.spec.providerID

echo ""
echo "=========================================="
echo "Restarting AWS Load Balancer Controller"
echo "=========================================="
echo ""

# Restart AWS LB Controller to pick up new providerIDs
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
kubectl rollout status deployment aws-load-balancer-controller -n kube-system --timeout=120s

echo ""
echo "Waiting 90 seconds for target registration..."
sleep 90

echo ""
echo "=========================================="
echo "Checking Target Group Health"
echo "=========================================="
echo ""

# Get target group ARNs
TG_443=$(aws elbv2 describe-target-groups --region us-west-2 --query 'TargetGroups[?contains(TargetGroupName, `k8s-traefik-traefik-92f1c14a88`)].TargetGroupArn' --output text)
TG_80=$(aws elbv2 describe-target-groups --region us-west-2 --query 'TargetGroups[?contains(TargetGroupName, `k8s-traefik-traefik-f9e8effcef`)].TargetGroupArn' --output text)

if [ -n "$TG_443" ]; then
  echo "Target Group (Port 443):"
  aws elbv2 describe-target-health --region us-west-2 --target-group-arn $TG_443 --query 'TargetHealthDescriptions[*].{TargetId:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}' --output table
fi

if [ -n "$TG_80" ]; then
  echo ""
  echo "Target Group (Port 80):"
  aws elbv2 describe-target-health --region us-west-2 --target-group-arn $TG_80 --query 'TargetHealthDescriptions[*].{TargetId:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}' --output table
fi

echo ""
echo "=========================================="
echo "✓ Provider ID Fix Complete!"
echo "=========================================="
echo ""
echo "If targets show as 'healthy', you can now access:"
echo "  - https://nginx.dev.foobar.support"
echo "  - https://traefik.dev.foobar.support"
echo "  - https://rancher.dev.foobar.support"
echo ""
echo "If targets are still 'initial' or 'unhealthy', wait 2-3 minutes"
echo "for health checks to complete, then recheck target health."
