#!/usr/bin/env bash
# Delete orphaned Traefik NLBs and target groups (e.g. after terraform destroy left them behind).
# Uses us-west-2 by default; set AWS_REGION to override.
set -euo pipefail
REGION="${AWS_REGION:-us-west-2}"

echo "Listing NLBs with name starting 'k8s-traefik' in $REGION..."
NLBS=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query 'LoadBalancers[?starts_with(LoadBalancerName, `k8s-traefik`)].LoadBalancerArn' --output text)
if [[ -z "$NLBS" ]]; then
  echo "No matching NLBs found."
else
  for arn in $NLBS; do
    echo "Deleting NLB: $arn"
    aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region "$REGION"
  done
fi

echo "Listing target groups with name starting 'k8s-traefik' in $REGION..."
TGS=$(aws elbv2 describe-target-groups --region "$REGION" \
  --query 'TargetGroups[?starts_with(TargetGroupName, `k8s-traefik`)].TargetGroupArn' --output text)
if [[ -z "$TGS" ]]; then
  echo "No matching target groups found."
else
  for arn in $TGS; do
    echo "Deleting target group: $arn"
    aws elbv2 delete-target-group --target-group-arn "$arn" --region "$REGION"
  done
fi

echo "Done."
