#!/bin/bash
# RKE2 Bootstrap Failure Diagnostic Script
# Run on the primary server node after a failed terraform apply
# Usage: ssh -i ~/.ssh/rke-key ubuntu@<server-ip> 'bash -s' < diagnose-rke2.sh

set -uo pipefail
SEP="=================================================================="

echo "$SEP"
echo "RKE2 BOOTSTRAP FAILURE DIAGNOSTICS"
echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Hostname: $(hostname)"
echo "$SEP"

echo ""
echo "=== 1. SYSTEM RESOURCES ==="
echo "--- Memory ---"
free -h
echo ""
echo "--- Disk ---"
df -h / /var/lib/rancher 2>/dev/null || df -h /
echo ""
echo "--- CPU ---"
nproc
echo ""
echo "--- Load average ---"
uptime

echo ""
echo "=== 2. INSTANCE IDENTITY ==="
echo "--- Instance metadata ---"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
if [ -n "$TOKEN" ]; then
  echo "Instance ID: $(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)"
  echo "Instance type: $(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-type)"
  echo "IAM info: $(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/info 2>/dev/null | head -5)"
else
  echo "IMDSv2 token fetch failed"
fi
echo ""
echo "--- AWS STS identity ---"
aws sts get-caller-identity 2>&1 || echo "FAILED: No IAM credentials available"

echo ""
echo "=== 3. RKE2 INSTALLATION ==="
echo "--- RKE2 binary ---"
ls -la /usr/local/bin/rke2 2>/dev/null || echo "MISSING: /usr/local/bin/rke2"
/usr/local/bin/rke2 --version 2>&1 || echo "Cannot get RKE2 version"
echo ""
echo "--- RKE2 systemd unit ---"
systemctl cat rke2-server.service 2>/dev/null | head -20 || echo "Unit file not found"
echo ""
echo "--- RKE2 service status ---"
systemctl status rke2-server --no-pager 2>&1 | head -20

echo ""
echo "=== 4. RKE2 CONFIG FILES ==="
echo "--- /etc/rancher/rke2/config.yaml (token redacted) ---"
if [ -f /etc/rancher/rke2/config.yaml ]; then
  sed 's/token:.*/token: [REDACTED]/' /etc/rancher/rke2/config.yaml
else
  echo "MISSING: /etc/rancher/rke2/config.yaml"
fi
echo ""
echo "--- /etc/rancher/rke2/registries.yaml ---"
if [ -f /etc/rancher/rke2/registries.yaml ]; then
  sed 's/password:.*/password: [REDACTED]/' /etc/rancher/rke2/registries.yaml
else
  echo "MISSING: /etc/rancher/rke2/registries.yaml"
fi
echo ""
echo "--- registries.yaml YAML validity ---"
if [ -f /etc/rancher/rke2/registries.yaml ]; then
  python3 -c "import yaml; yaml.safe_load(open('/etc/rancher/rke2/registries.yaml'))" 2>&1 && echo "VALID YAML" || echo "INVALID YAML"
fi
echo ""
echo "--- /etc/rancher/rke2/ directory listing ---"
ls -la /etc/rancher/rke2/ 2>/dev/null || echo "Directory does not exist"

echo ""
echo "=== 5. CONTAINERD STATUS ==="
echo "--- RKE2 containerd socket ---"
ls -la /run/k3s/containerd/containerd.sock 2>/dev/null || echo "MISSING: containerd socket"
echo ""
echo "--- Containerd processes ---"
ps aux | grep -E 'containerd|rke2' | grep -v grep || echo "No containerd/rke2 processes found"

echo ""
echo "=== 6. RKE2 DATA DIRECTORIES ==="
echo "--- /var/lib/rancher/rke2/ top-level ---"
ls -la /var/lib/rancher/rke2/ 2>/dev/null || echo "Directory does not exist"
echo ""
echo "--- /var/lib/rancher/rke2/server/ ---"
ls -la /var/lib/rancher/rke2/server/ 2>/dev/null || echo "Directory does not exist"
echo ""
echo "--- /var/lib/rancher/rke2/server/db/ ---"
ls -la /var/lib/rancher/rke2/server/db/ 2>/dev/null || echo "Directory does not exist"
echo ""
echo "--- /var/lib/rancher/rke2/agent/images/ ---"
ls -la /var/lib/rancher/rke2/agent/images/ 2>/dev/null || echo "Directory does not exist (air-gap images)"
echo ""
echo "--- RKE2 embedded image archives ---"
ls -la /var/lib/rancher/rke2/agent/images/*.tar* 2>/dev/null || echo "No embedded image tarballs found"

echo ""
echo "=== 7. CONTAINERD IMAGES (if containerd is running) ==="
if [ -S /run/k3s/containerd/containerd.sock ]; then
  /var/lib/rancher/rke2/bin/ctr --address /run/k3s/containerd/containerd.sock --namespace k8s.io images list 2>/dev/null | head -30 || echo "Could not list images"
else
  echo "Containerd socket not available"
fi

echo ""
echo "=== 8. NETWORK CHECKS ==="
echo "--- Ports in use (2379, 2380, 6443, 9345, 10250) ---"
ss -tlnp | grep -E ':(2379|2380|6443|9345|10250)\b' 2>/dev/null || echo "No RKE2 ports in use"
echo ""
echo "--- Firewall (iptables) ---"
sudo iptables -L INPUT -n 2>/dev/null | head -20 || echo "Could not list iptables rules"

echo ""
echo "=== 9. JOURNAL LOGS (rke2-server, last 200 lines) ==="
journalctl -u rke2-server -n 200 --no-pager 2>/dev/null || echo "No journal entries"

echo ""
echo "=== 10. JOURNAL LOGS (containerd, last 50 lines) ==="
journalctl -u rke2-server -n 500 --no-pager 2>/dev/null | grep -i -E 'containerd|cri|sandbox|image|pull|import' | tail -50 || echo "No containerd-related entries"

echo ""
echo "=== 11. DMESG (OOM / kernel issues, last 30 lines) ==="
dmesg | grep -i -E 'oom|killed|memory|error|fail' | tail -30 || echo "No kernel issues found"

echo ""
echo "=== 12. QUICK FIX TEST ==="
echo "Attempting manual rke2-server start with verbose logging..."
echo "(Will run for 120 seconds then stop)"
echo ""
echo "--- Stopping any existing rke2-server ---"
sudo systemctl stop rke2-server 2>/dev/null || true
sleep 2
echo ""
echo "--- Starting rke2-server in foreground (120s timeout, last 100 lines) ---"
sudo timeout 120 /usr/local/bin/rke2 server --config /etc/rancher/rke2/config.yaml 2>&1 | tail -100 || true

echo ""
echo "$SEP"
echo "DIAGNOSTICS COMPLETE"
echo "$SEP"
