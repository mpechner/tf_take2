#!/bin/bash
# Generate Ansible inventory from running RKE instances

set -e

REGION="${1:-us-west-2}"
OUTPUT="${2:-inventory.ini}"

echo "Generating Ansible inventory for RKE nodes..."

# Assume terraform-execute role
TEMP_CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::364082771643:role/terraform-execute" \
  --role-session-name "ansible-inventory" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

export AWS_ACCESS_KEY_ID=$(echo $TEMP_CREDS | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo $TEMP_CREDS | awk '{print $3}')

# Get instances
SERVERS=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:Name,Values=server_*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[PrivateIpAddress]' \
  --output text)

AGENTS=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:Name,Values=agent_*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[PrivateIpAddress]' \
  --output text)

# Generate inventory
cat > $OUTPUT << EOF
[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/rke-key
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_python_interpreter=/usr/bin/python3

[servers]
EOF

for IP in $SERVERS; do
  echo "$IP" >> $OUTPUT
done

cat >> $OUTPUT << EOF

[agents]
EOF

for IP in $AGENTS; do
  echo "$IP" >> $OUTPUT
done

cat >> $OUTPUT << EOF

[all:children]
servers
agents
EOF

echo "✅ Inventory generated: $OUTPUT"
echo ""
echo "Servers: $(echo "$SERVERS" | wc -l | tr -d ' ')"
echo "Agents: $(echo "$AGENTS" | wc -l | tr -d ' ')"
echo ""
cat $OUTPUT
