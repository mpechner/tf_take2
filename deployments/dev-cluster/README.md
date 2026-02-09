# RKE Cluster Deployment - Two-Stage Approach

This deployment is split into **2 stages** to handle Terraform's limitation with Custom Resource Definitions (CRDs).

## Why Two Stages?

Terraform's `kubernetes_manifest` resource validates API schemas during the **plan phase**, before any resources are deployed. This creates a chicken-and-egg problem:

- **Stage 1** deploys Helm charts (cert-manager, Traefik, external-dns) which **install CRDs**
- **Stage 2** creates Kubernetes manifests (ClusterIssuer, IngressRoute, etc.) which **require those CRDs**

If we tried to deploy everything in one stage, Terraform would fail during `terraform plan` because it tries to validate manifests for CRDs that don't exist yet.

## Deployment Order

### Prerequisites

1. RKE cluster must be deployed and healthy
2. Kubeconfig must be configured (`~/.kube/config`)
3. AWS credentials must be valid

### Stage 1: Infrastructure (Helm Charts)

```bash
cd 1-infrastructure
terraform init
terraform apply
```

**What this deploys:**
- cert-manager (certificate management + CRD installation)
- external-dns (automatic Route53 DNS record management)
- Traefik (ingress controller with public + internal load balancers)

**Duration:** ~2-3 minutes

**Output:** Helm charts deployed, CRDs installed in the cluster

### Stage 2: Applications (Manifests + Workloads)

```bash
cd ../2-applications
terraform init
terraform apply
```

**What this deploys:**
- ClusterIssuer (Let's Encrypt configuration)
- Traefik Dashboard (with IngressRoute + authentication)
- Backend TLS infrastructure (internal service certificates)
- Nginx sample application (demo with TLS)

**Duration:** ~1-2 minutes

## Verification

After both stages complete:

```bash
# Check all pods are running
kubectl get pods -A

# Verify certificates
kubectl get certificates -A

# Check ingress resources
kubectl get ingress -A

# Verify DNS records created
kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Accessing Services

- **Nginx Sample:** https://nginx.dev.foobar.support (public)
- **Traefik Dashboard:** https://traefik.dev.foobar.support (internal VPN only)

## Common Operations

### Update Helm Chart Versions

Modify `1-infrastructure/main.tf` and re-apply Stage 1 only:

```bash
cd 1-infrastructure
terraform apply
```

### Add New Applications

Modify `2-applications/main.tf` and re-apply Stage 2 only:

```bash
cd 2-applications
terraform apply
```

### Full Rebuild

```bash
cd 2-applications
terraform destroy

cd ../1-infrastructure
terraform destroy

# Then redeploy in order
terraform apply
cd ../2-applications
terraform apply
```

## Troubleshooting

### "CRD not found" errors in Stage 2

This means Stage 1 didn't complete successfully. Check:

```bash
# Verify cert-manager is running
kubectl get pods -n cert-manager

# Verify Traefik is running
kubectl get pods -n kube-system | grep traefik

# Check CRDs are installed
kubectl get crd | grep cert-manager
kubectl get crd | grep traefik
```

### Load balancer not provisioning

Check AWS load balancer controller logs and ensure IAM roles have proper permissions for ELB creation.

### DNS records not creating

Check external-dns logs:

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns
```

## Architecture Decision

This two-stage approach is intentional and follows operations best practices:

- ✅ **Clear separation** - Infrastructure vs. Applications
- ✅ **Independent updates** - Change apps without touching infrastructure
- ✅ **Better troubleshooting** - Easy to identify which stage failed
- ✅ **Standard workflow** - Just `terraform apply`, no special scripts
- ✅ **Explicit dependencies** - No hidden complexity
