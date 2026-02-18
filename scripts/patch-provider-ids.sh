#!/bin/bash
set -e

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}"

echo "=========================================="
echo "Patching Node Provider IDs to AWS Format"
echo "=========================================="
echo ""
echo "AWS identity (must be the account that owns the RKE EC2 instances):"
aws sts get-caller-identity --region "$REGION" || { echo "ERROR: aws cli failed. Set AWS_PROFILE or credentials for the account that owns the nodes."; exit 1; }
echo ""
echo "Region: $REGION"
echo ""

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
    --region "$REGION" \
    --filters "Name=private-ip-address,Values=$IP" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)
  
  if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "⚠️  Could not find instance ID for $IP (check: same AWS account and region as EC2s?)"
    continue
  fi
  
  # Get availability zone
  AZ=$(aws ec2 describe-instances \
    --region "$REGION" \
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

# Show target health for any k8s Traefik target groups in this region
echo "Target groups (k8s-traefik*):"
aws elbv2 describe-target-groups --region "$REGION" --query 'TargetGroups[?starts_with(TargetGroupName, `k8s-traefik`)].{Name:TargetGroupName,Port:Port,ARN:TargetGroupArn}' --output table
echo ""
for TG_ARN in $(aws elbv2 describe-target-groups --region "$REGION" --query 'TargetGroups[?starts_with(TargetGroupName, `k8s-traefik`)].TargetGroupArn' --output text); do
  TG_NAME=$(aws elbv2 describe-target-groups --target-group-arns "$TG_ARN" --region "$REGION" --query 'TargetGroups[0].TargetGroupName' --output text)
  echo "Target health for $TG_NAME:"
  aws elbv2 describe-target-health --region "$REGION" --target-group-arn "$TG_ARN" --query 'TargetHealthDescriptions[*].{TargetId:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}' --output table
  echo ""
done

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
