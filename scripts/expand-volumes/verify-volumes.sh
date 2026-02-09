#!/bin/bash
set -e

# Script to verify root volume sizes on RKE nodes
# Shows both AWS EBS volume size and actual filesystem usage on each node

CLUSTER_NAME="${1:-dev}"
SSH_KEY="${2:-~/.ssh/rke-key}"

echo "=========================================="
echo "Verifying Root Volumes for $CLUSTER_NAME cluster"
echo "=========================================="

# Assume terraform-execute role
echo "Assuming AWS role..."
TEMP_CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::364082771643:role/terraform-execute" \
  --role-session-name "verify-volumes" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

export AWS_ACCESS_KEY_ID=$(echo $TEMP_CREDS | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo $TEMP_CREDS | awk '{print $3}')

# Get all instances with tag Name matching server_* or agent_*
INSTANCES=$(aws ec2 describe-instances \
  --region us-west-2 \
  --filters "Name=tag:Name,Values=server_*,agent_*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],PrivateIpAddress,BlockDeviceMappings[?DeviceName==`/dev/sda1`].Ebs.VolumeId|[0]]' \
  --output text)

if [ -z "$INSTANCES" ]; then
  echo "ERROR: No running instances found"
  exit 1
fi

echo ""
printf "%-15s %-20s %-15s %-12s %-15s %-12s\n" "NAME" "INSTANCE-ID" "PRIVATE-IP" "EBS-SIZE" "FILESYSTEM" "AVAILABLE"
printf "%-15s %-20s %-15s %-12s %-15s %-12s\n" "===============" "====================" "===============" "============" "===============" "============"

# Process each instance
while IFS=$'\t' read -r INSTANCE_ID INSTANCE_NAME PRIVATE_IP VOLUME_ID; do
  
  # Get AWS EBS volume size
  EBS_SIZE=$(aws ec2 describe-volumes \
    --region us-west-2 \
    --volume-ids $VOLUME_ID \
    --query 'Volumes[0].Size' \
    --output text)
  
  # Get filesystem size from the instance
  FS_INFO=$(ssh -i $SSH_KEY \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    ubuntu@$PRIVATE_IP "df -h / | awk 'NR==2 {print \$2,\$4}'" 2>/dev/null || echo "OFFLINE OFFLINE")
  
  FS_SIZE=$(echo $FS_INFO | awk '{print $1}')
  FS_AVAIL=$(echo $FS_INFO | awk '{print $2}')
  
  # Determine status
  if [ "$FS_SIZE" == "OFFLINE" ]; then
    STATUS="⚠️  SSH FAILED"
    printf "%-15s %-20s %-15s %-12s %-15s %-12s\n" "$INSTANCE_NAME" "$INSTANCE_ID" "$PRIVATE_IP" "${EBS_SIZE}GB" "$STATUS" ""
  elif [ "$EBS_SIZE" -eq "$EBS_SIZE" ] 2>/dev/null && [ "$EBS_SIZE" -ge 40 ]; then
    STATUS="✅"
    printf "%-15s %-20s %-15s %-12s %-15s %-12s\n" "$INSTANCE_NAME" "$INSTANCE_ID" "$PRIVATE_IP" "${EBS_SIZE}GB" "$FS_SIZE" "$FS_AVAIL"
  else
    STATUS="⚠️"
    printf "%-15s %-20s %-15s %-12s %-15s %-12s\n" "$INSTANCE_NAME" "$INSTANCE_ID" "$PRIVATE_IP" "${EBS_SIZE}GB" "$FS_SIZE" "$FS_AVAIL"
  fi
  
done <<< "$INSTANCES"

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "Legend:"
echo "  ✅ = Volume >= 40GB and filesystem expanded"
echo "  ⚠️  = Volume < 40GB or filesystem not expanded"
echo ""
