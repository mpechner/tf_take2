# Expand Root Volumes on Running RKE Nodes

This directory contains scripts to **safely expand root volumes** from 8GB to 40GB on running RKE nodes **without downtime or data loss**.

## Overview

The scripts perform these steps:
1. Use AWS API to expand EBS volumes (online operation)
2. SSH to each node and expand the partition
3. Resize the filesystem to use the new space

**This is NON-DESTRUCTIVE** and can be done on running nodes!

## Prerequisites

- AWS CLI configured
- SSH key at `~/.ssh/rke-key`
- Connected to VPN (to reach private IPs)
- Terraform execute role access

## Scripts

1. **verify-volumes.sh** - Check current volume and filesystem sizes
2. **expand-root-volumes.sh** - Expand volumes using AWS CLI and SSH
3. **expand-volumes.yml** - Ansible playbook for volume expansion (alternative method)
4. **generate-inventory.sh** - Generate Ansible inventory from running instances

## Usage

### Step 0: Verify Current Sizes (Optional)

```bash
cd /Users/mpechner/dev/tf_take2/scripts/expand-volumes

# Check current volumes
./verify-volumes.sh dev

# Or specify custom SSH key location
./verify-volumes.sh dev ~/.ssh/my-key
```

This will show:
- AWS EBS volume size
- Current filesystem size
- Available space
- SSH connectivity status

### Step 1: Simple Bash Script (Recommended)

```bash
cd /Users/mpechner/dev/tf_take2/scripts/expand-volumes

# Run (defaults to 40GB)
./expand-root-volumes.sh dev 40

# Or specify custom size
./expand-root-volumes.sh dev 60
```

### Step 2: Ansible Playbook (More robust)

```bash
cd /Users/mpechner/dev/tf_take2/scripts/expand-volumes

# Generate inventory
./generate-inventory.sh us-west-2 inventory.ini

# Run playbook
ansible-playbook -i inventory.ini expand-volumes.yml
```

## What It Does

### AWS Volume Expansion
- Finds all running RKE instances (server_*, agent_*)
- Checks current volume size
- Expands volumes < 40GB to 40GB
- Waits for expansion to complete (AWS does this online)

### Partition & Filesystem Expansion
For each node:
1. Runs `growpart` to expand partition
2. Runs `resize2fs` to expand ext4 filesystem
3. Verifies new size with `df -h`

## Safety

✅ **Safe to run on live cluster** - No downtime required
✅ **Idempotent** - Safe to run multiple times (skips already-expanded volumes)
✅ **Non-destructive** - Only expands, never shrinks
✅ **Rollback not needed** - Expansion is permanent but safe

## Verification

After running, check each node:

```bash
# Via kubectl
kubectl get nodes

# SSH to a node
ssh -i ~/.ssh/rke-key ubuntu@10.8.27.167
df -h /
# Should show ~37GB available (40GB - system overhead)
```

## Troubleshooting

### "Failed to expand filesystem"
If volume expanded but filesystem didn't:
```bash
ssh -i ~/.ssh/rke-key ubuntu@<NODE_IP>
sudo growpart /dev/nvme0n1 1  # or /dev/xvda 1
sudo resize2fs /dev/nvme0n1p1  # or /dev/xvda1
df -h /
```

### "Volume modification already in progress"
Wait a few minutes for previous modification to complete, then retry.

### SSH connection fails
Ensure you're connected to VPN and can reach private IPs.

## Notes

- Uses `gp3` volumes (already configured in Terraform)
- Expansion is immediate for volumes, partition/filesystem takes ~10 seconds per node
- No pod eviction or rescheduling required
- Does not require Kubernetes drain/cordon
