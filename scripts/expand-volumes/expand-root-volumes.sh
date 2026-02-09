#!/bin/bash
set -e

# Script to expand root volumes on RKE nodes from 8GB to 40GB
# This is a NON-DESTRUCTIVE operation that can be done online

CLUSTER_NAME="${1:-dev}"
NEW_SIZE="${2:-40}"
SSH_KEY="${3:-~/.ssh/rke-key}"

echo "=========================================="
echo "Expanding Root Volumes for $CLUSTER_NAME cluster to ${NEW_SIZE}GB"
echo "=========================================="

# Assume terraform-execute role
echo "Assuming AWS role..."
TEMP_CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::364082771643:role/terraform-execute" \
  --role-session-name "expand-volumes" \
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
echo "Found instances:"
echo "$INSTANCES"
echo ""

# Process each instance
while IFS=$'\t' read -r INSTANCE_ID INSTANCE_NAME PRIVATE_IP VOLUME_ID; do
  echo "=========================================="
  echo "Processing: $INSTANCE_NAME ($INSTANCE_ID)"
  echo "Private IP: $PRIVATE_IP"
  echo "Volume ID: $VOLUME_ID"
  echo "=========================================="
  
  # Check current volume size
  CURRENT_SIZE=$(aws ec2 describe-volumes \
    --region us-west-2 \
    --volume-ids $VOLUME_ID \
    --query 'Volumes[0].Size' \
    --output text)
  
  echo "Current size: ${CURRENT_SIZE}GB"
  
  if [ "$CURRENT_SIZE" -ge "$NEW_SIZE" ]; then
    echo "⚠️  Volume already >= ${NEW_SIZE}GB, skipping..."
    continue
  fi
  
  # Step 1: Modify volume size (can be done online)
  echo "📦 Modifying volume size to ${NEW_SIZE}GB..."
  aws ec2 modify-volume \
    --region us-west-2 \
    --volume-id $VOLUME_ID \
    --size $NEW_SIZE
  
  echo "✓ Volume modification initiated"
  
  # Step 2: Wait for modification to complete
  echo "⏳ Waiting for volume modification to complete (this may take a few minutes)..."
  while true; do
    STATE=$(aws ec2 describe-volumes-modifications \
      --region us-west-2 \
      --volume-ids $VOLUME_ID \
      --query 'VolumesModifications[0].ModificationState' \
      --output text)
    
    if [ "$STATE" == "completed" ]; then
      echo "✓ Volume modification completed"
      break
    elif [ "$STATE" == "optimizing" ]; then
      echo "✓ Volume modification completed (optimizing in background)"
      break
    elif [ "$STATE" == "failed" ]; then
      echo "❌ Volume modification failed!"
      exit 1
    fi
    
    echo "   Current state: $STATE"
    sleep 10
  done
  
  # Step 3: Expand the partition and filesystem on the instance
  echo "💾 Expanding partition and filesystem on $INSTANCE_NAME..."
  
  ssh -i $SSH_KEY \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    ubuntu@$PRIVATE_IP << 'ENDSSH'
    set -e
    
    echo "Current disk usage:"
    df -h /
    
    # Grow the partition
    echo "Growing partition..."
    sudo growpart /dev/nvme0n1 1 || sudo growpart /dev/xvda 1 || echo "Partition already at maximum size"
    
    # Resize the filesystem (works for ext4)
    echo "Resizing filesystem..."
    sudo resize2fs /dev/nvme0n1p1 || sudo resize2fs /dev/xvda1 || echo "Filesystem resize failed"
    
    echo ""
    echo "New disk usage:"
    df -h /
ENDSSH
  
  if [ $? -eq 0 ]; then
    echo "✅ Successfully expanded $INSTANCE_NAME"
  else
    echo "❌ Failed to expand filesystem on $INSTANCE_NAME"
    echo "   Volume was expanded, but filesystem resize failed"
    echo "   You may need to manually SSH and run: sudo resize2fs /dev/nvme0n1p1"
  fi
  
  echo ""
  
done <<< "$INSTANCES"

echo "=========================================="
echo "✅ Volume expansion complete!"
echo "=========================================="
echo ""
echo "Summary:"
aws ec2 describe-instances \
  --region us-west-2 \
  --filters "Name=tag:Name,Values=server_*,agent_*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],BlockDeviceMappings[?DeviceName==`/dev/sda1`].Ebs.VolumeId|[0]]' \
  --output text | while IFS=$'\t' read -r NAME VOLID; do
    SIZE=$(aws ec2 describe-volumes --region us-west-2 --volume-ids $VOLID --query 'Volumes[0].Size' --output text)
    echo "$NAME: ${SIZE}GB"
  done
