#!/bin/bash
set -euo pipefail

echo "============================================"
echo "  RKE2 Registry & Image Diagnostic"
echo "  $(date -u)"
echo "============================================"

echo ""
echo "=== 1. registries.yaml content ==="
if [ -f /etc/rancher/rke2/registries.yaml ]; then
  cat /etc/rancher/rke2/registries.yaml
  echo ""
  echo "--- YAML validity check ---"
  python3 -c "import yaml; yaml.safe_load(open('/etc/rancher/rke2/registries.yaml')); print('VALID YAML')" 2>&1 || echo "INVALID YAML"
else
  echo "FILE NOT FOUND"
fi

echo ""
echo "=== 2. RKE2 agent/images directory ==="
if [ -d /var/lib/rancher/rke2/agent/images ]; then
  ls -lah /var/lib/rancher/rke2/agent/images/
else
  echo "DIRECTORY NOT FOUND - this is the problem if RKE2 needs to pull images"
fi

echo ""
echo "=== 3. runtime-image.txt content (if exists) ==="
for f in /var/lib/rancher/rke2/agent/images/*.txt; do
  if [ -f "$f" ]; then
    echo "--- $f ---"
    cat "$f"
  fi
done 2>/dev/null || echo "No .txt files found"

echo ""
echo "=== 4. Docker Hub credential test ==="
DH_ARN=$(grep -o 'dockerhub_secret_arn.*' /usr/local/bin/ecr-login.sh 2>/dev/null | head -1 || echo "")
echo "ecr-login.sh DH_ARN line: $DH_ARN"

REGION=$(curl -sf http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "us-west-2")
echo "Region: $REGION"

echo ""
echo "--- Attempting to fetch Docker Hub secret ---"
DH_SECRET_ARN="arn:aws:secretsmanager:us-west-2:364082771643:secret:admin/dockerhub-PkmrRt"
DH_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$DH_SECRET_ARN" \
  --region "$REGION" \
  --query SecretString --output text 2>&1) || true
if [ -n "$DH_JSON" ] && echo "$DH_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo "Secret fetched OK (valid JSON)"
  DH_USER=$(echo "$DH_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user','MISSING'))")
  DH_TOKEN=$(echo "$DH_JSON" | python3 -c "import sys,json; t=json.load(sys.stdin).get('token','MISSING'); print(t[:4]+'...' if len(t)>4 else t)")
  echo "User: $DH_USER"
  echo "Token (first 4 chars): $DH_TOKEN"

  echo ""
  echo "--- Testing Docker Hub token endpoint ---"
  FULL_TOKEN=$(echo "$DH_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
  HTTP_CODE=$(curl -s -o /tmp/dh-auth-response.json -w "%{http_code}" \
    -u "$DH_USER:$FULL_TOKEN" \
    "https://auth.docker.io/token?service=registry.docker.io&scope=repository:rancher/rke2-runtime:pull" 2>&1) || true
  echo "HTTP status: $HTTP_CODE"
  echo "Response: $(cat /tmp/dh-auth-response.json 2>/dev/null | head -c 200)"
else
  echo "Failed to fetch or parse secret: $DH_JSON"
fi

echo ""
echo "=== 5. Containerd status ==="
if command -v /var/lib/rancher/rke2/bin/containerd &>/dev/null; then
  echo "containerd binary exists"
else
  echo "containerd binary NOT found at /var/lib/rancher/rke2/bin/containerd"
fi

CTR="/var/lib/rancher/rke2/bin/ctr"
SOCK="/run/k3s/containerd/containerd.sock"
if [ -S "$SOCK" ]; then
  echo "containerd socket exists"
  echo ""
  echo "--- containerd images (k8s.io namespace) ---"
  $CTR --address "$SOCK" -n k8s.io images ls 2>&1 | head -30 || echo "Failed to list images"
else
  echo "containerd socket NOT found at $SOCK"
  echo "Checking alternative socket locations..."
  find /run -name "containerd.sock" 2>/dev/null || echo "No containerd socket found anywhere in /run"
fi

echo ""
echo "=== 6. ecr-login.sh output (re-run) ==="
echo "--- Running ecr-login.sh and capturing output ---"
/usr/local/bin/ecr-login.sh 2>&1 || echo "ecr-login.sh failed with exit code $?"

echo ""
echo "=== 7. registries.yaml AFTER ecr-login.sh ==="
cat /etc/rancher/rke2/registries.yaml 2>/dev/null || echo "FILE NOT FOUND"

echo ""
echo "=== 8. Test direct Docker Hub pull (unauthenticated) ==="
echo "--- Trying to pull pause image manifest via curl ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://registry-1.docker.io/v2/" 2>&1) || true
echo "Docker Hub v2 API status (expect 401 = reachable): $HTTP_CODE"

TOKEN=$(curl -sf "https://auth.docker.io/token?service=registry.docker.io&scope=repository:rancher/pause:pull" 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin).get('token','FAILED'))" 2>/dev/null) || true
if [ "$TOKEN" != "FAILED" ] && [ -n "$TOKEN" ]; then
  echo "Anonymous token obtained OK"
  MANIFEST_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "https://registry-1.docker.io/v2/rancher/pause/manifests/3.6" 2>&1) || true
  echo "Manifest pull for rancher/pause:3.6 status: $MANIFEST_CODE"
else
  echo "FAILED to get anonymous token from auth.docker.io - network issue?"
fi

echo ""
echo "=== 9. Full rke2 journal (last 50 lines before crash) ==="
journalctl -u rke2-server --no-pager -n 50 2>&1 | grep -E "(error|fatal|import|image|runtime|registr|sandbox)" -i || echo "No matching journal entries"

echo ""
echo "============================================"
echo "  Diagnostic complete"
echo "============================================"
