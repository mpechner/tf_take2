#!/usr/bin/env bash
# Delete orphaned Traefik NLBs and target groups (e.g. after terraform destroy left them behind).
# Uses us-west-2 by default; set AWS_REGION to override.
# NLBs live in the cluster account. If your default credentials are not in that account:
#   export AWS_ASSUME_ROLE_ARN="arn:aws:iam::ACCOUNT:role/terraform-execute"
#   or:  ./scripts/delete-traefik-nlbs.sh arn:aws:iam::ACCOUNT:role/terraform-execute
set -euo pipefail
REGION="${AWS_REGION:-us-west-2}"
# First argument can be the terraform-execute role ARN (cluster account)
if [[ -n "${1:-}" ]]; then
  export AWS_ASSUME_ROLE_ARN="$1"
fi

if [[ -n "${AWS_ASSUME_ROLE_ARN:-}" ]]; then
  echo "Assuming role ${AWS_ASSUME_ROLE_ARN}..."
  CREDS=$(aws sts assume-role --role-arn "$AWS_ASSUME_ROLE_ARN" --role-session-name "delete-traefik-nlbs" --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
  export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | awk '{print $1}')
  export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | awk '{print $2}')
  export AWS_SESSION_TOKEN=$(echo "$CREDS" | awk '{print $3}')
fi

echo "Listing NLBs with name starting 'k8s-traefik' in $REGION..."
NLBS=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query 'LoadBalancers[?starts_with(LoadBalancerName, `k8s-traefik`)].LoadBalancerArn' --output text 2>/dev/null || true)
if [[ -z "$NLBS" ]]; then
  echo "No matching NLBs found in this account."
  IDENTITY=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || true)
  if [[ -n "$IDENTITY" ]]; then
    echo "Current AWS account: $IDENTITY (NLBs may be in the cluster account; use AWS_ASSUME_ROLE_ARN or pass role ARN as first argument)."
  fi
  echo "Example: AWS_ASSUME_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/terraform-execute $0"
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
