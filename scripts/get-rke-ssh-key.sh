#!/bin/bash
# Get RKE SSH private key from AWS Secrets Manager (created by RKE-cluster/dev-cluster/ec2)
# Usage: ./scripts/get-rke-ssh-key.sh [secret-name]
# If no secret name provided, defaults to: rke-ssh
# Saves key to ~/.ssh/rke-key (used by RKE terraform and kubectl/ssh to nodes)

set -e

SECRET_NAME="${1:-rke-ssh}"
SSH_KEY_PATH="$HOME/.ssh/rke-key"

echo "Fetching RKE SSH key from Secrets Manager..."
echo "Secret: $SECRET_NAME"

# Assume the terraform-execute role to access dev account (same as RKE-cluster/dev-cluster/ec2)
echo "Assuming terraform-execute role..."
TEMP_CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::364082771643:role/terraform-execute" \
  --role-session-name "get-rke-ssh-key" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

export AWS_ACCESS_KEY_ID=$(echo $TEMP_CREDS | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo $TEMP_CREDS | awk '{print $3}')

# Secret is JSON with private_key and public_key (same shape as openvpn)
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region us-west-2 \
  --query SecretString \
  --output text | jq -r '.private_key' > "$SSH_KEY_PATH"

if [ ! -s "$SSH_KEY_PATH" ]; then
  echo "ERROR: Failed to retrieve SSH key or key is empty"
  rm -f "$SSH_KEY_PATH"
  exit 1
fi

if ! head -1 "$SSH_KEY_PATH" | grep -q "BEGIN.*PRIVATE KEY"; then
  echo "ERROR: Retrieved key is not in valid PEM format"
  echo "Key content:"
  head -3 "$SSH_KEY_PATH"
  rm -f "$SSH_KEY_PATH"
  exit 1
fi

chmod 600 "$SSH_KEY_PATH"

echo "✓ SSH key saved to $SSH_KEY_PATH"
echo "✓ Permissions set to 600"
echo ""
echo "Use for RKE nodes (ubuntu user, server IP from terraform output):"
echo "  ssh -i ~/.ssh/rke-key ubuntu@<SERVER_IP>"
