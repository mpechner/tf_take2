#!/bin/bash
# Setup kubectl configuration for RKE2 cluster
# Usage: ./setup-k9s.sh <server-ip-address>

set -e

if [ -z "$1" ]; then
  echo "Error: Server IP address required"
  echo "Usage: $0 <server-ip-address>"
  echo "Example: $0 10.8.91.172"
  exit 1
fi

SERVER_IP=$1
SSH_KEY="${HOME}/.ssh/rke-key"
KUBECONFIG_FILE="${HOME}/.kube/dev-rke2.yaml"
CONTEXT_NAME="dev-rke2"

echo "Setting up kubectl configuration for RKE2 cluster..."
echo "Server IP: ${SERVER_IP}"

# Clean up any old dev-rke2 context, cluster, and user from previous deployments
echo "Cleaning up old configurations..."
kubectl config delete-context ${CONTEXT_NAME} 2>/dev/null || true
kubectl config delete-cluster ${CONTEXT_NAME} 2>/dev/null || true
kubectl config delete-cluster default 2>/dev/null || true
kubectl config delete-user ${CONTEXT_NAME} 2>/dev/null || true
kubectl config delete-user default 2>/dev/null || true

# Remove old dev-rke2.yaml file if it exists
if [ -f "${KUBECONFIG_FILE}" ]; then
  echo "Removing old ${KUBECONFIG_FILE}..."
  rm -f "${KUBECONFIG_FILE}"
fi

# Check if SSH key exists
if [ ! -f "${SSH_KEY}" ]; then
  echo "Error: SSH key not found at ${SSH_KEY}"
  echo "Please copy the rke-ssh private key from AWS Secrets Manager first"
  exit 1
fi

# Copy kubeconfig from server
echo "Copying kubeconfig from server..."
scp -i "${SSH_KEY}" ubuntu@${SERVER_IP}:/etc/rancher/rke2/rke2.yaml "${KUBECONFIG_FILE}"

# Update server URL
echo "Updating server URL..."
sed -i '' "s|server: https://127.0.0.1:6443|server: https://${SERVER_IP}:6443|" "${KUBECONFIG_FILE}"

# Rename context to match our naming convention
echo "Renaming context to ${CONTEXT_NAME}..."
kubectl --kubeconfig "${KUBECONFIG_FILE}" config rename-context default "${CONTEXT_NAME}" 2>/dev/null || true

# Also rename cluster and user to match for consistency
TEMP_KUBECONFIG="${HOME}/.kube/dev-rke2-temp.yaml"
kubectl --kubeconfig "${KUBECONFIG_FILE}" config view --flatten | \
  sed "s/name: default/name: ${CONTEXT_NAME}/g" > "${TEMP_KUBECONFIG}"
mv "${TEMP_KUBECONFIG}" "${KUBECONFIG_FILE}"

# Merge with existing kubeconfig
echo "Merging with existing kubeconfig..."
KUBECONFIG="${HOME}/.kube/config:${KUBECONFIG_FILE}" kubectl config view --flatten > "${HOME}/.kube/merged"
mv "${HOME}/.kube/merged" "${HOME}/.kube/config"

# Validate and fix context to cluster mapping
echo "Validating context configuration..."
CONTEXT_CLUSTER=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"${CONTEXT_NAME}\")].context.cluster}")
CONTEXT_USER=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"${CONTEXT_NAME}\")].context.user}")

if [ "${CONTEXT_CLUSTER}" != "${CONTEXT_NAME}" ] || [ "${CONTEXT_USER}" != "${CONTEXT_NAME}" ]; then
  echo "Fixing context ${CONTEXT_NAME} to point to correct cluster and user..."
  kubectl config set-context "${CONTEXT_NAME}" --cluster="${CONTEXT_NAME}" --user="${CONTEXT_NAME}"
fi

# Clean up any orphaned contexts pointing to wrong cluster
echo "Cleaning up orphaned contexts..."
for ctx in $(kubectl config get-contexts -o name); do
  if [ "${ctx}" != "${CONTEXT_NAME}" ] && [ "${ctx}" != "minikube" ] && [ "${ctx}" != "docker-desktop" ]; then
    CTX_CLUSTER=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"${ctx}\")].context.cluster}")
    if [ "${CTX_CLUSTER}" = "default" ] || [ "${CTX_CLUSTER}" = "${CONTEXT_NAME}" ]; then
      echo "  Removing orphaned context: ${ctx}"
      kubectl config delete-context "${ctx}" 2>/dev/null || true
    fi
  fi
done

# Set permissions
chmod 600 "${HOME}/.kube/config"

echo ""
echo "✓ Kubectl configuration complete!"
echo ""
echo "You can now use:"
echo "  kubectl config use-context ${CONTEXT_NAME}"
echo "  kubectl get nodes"
echo "  k9s"
echo ""
