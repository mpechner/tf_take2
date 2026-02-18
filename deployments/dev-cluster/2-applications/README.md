# Stage 2: Applications

This stage deploys application-level resources that depend on CRDs installed in Stage 1.

## Prerequisites

**You MUST deploy Stage 1 first!**

Stage 2 requires these CRDs to exist:
- `cert-manager.io/v1/ClusterIssuer`
- `cert-manager.io/v1/Issuer`
- `cert-manager.io/v1/Certificate`
- `traefik.io/v1alpha1/IngressRoute`
- `traefik.io/v1alpha1/Middleware`
- `traefik.io/v1alpha1/ServersTransport`

## What Gets Deployed

### ClusterIssuer
- Let's Encrypt configuration (staging or prod)
- DNS-01 challenge via Route53
- Cluster-wide certificate issuer

### Traefik Dashboard
- IngressRoute for Traefik dashboard
- Basic auth middleware (requires `traefik-auth-secret`)
- Internal-only access via internal NLB
- TLS certificate from Let's Encrypt

### Backend TLS Infrastructure
- Self-signed CA per namespace
- Automatic internal service certificates
- Traefik ServersTransport configuration
- Enables encrypted pod-to-pod communication

### Nginx Sample Application
- Kubernetes deployment + service
- Ingress with Let's Encrypt TLS
- Backend TLS enabled
- Public access via external NLB

## Configuration

Edit `terraform.tfvars`:

```hcl
route53_domain   = "dev.foobar.support"

letsencrypt_environment = "staging"  # Use "staging" first, then "prod"
```

## Deployment

```bash
terraform init
terraform apply
```

## Verification

```bash
# Check certificates
kubectl get certificates -A
kubectl get clusterissuers

# Verify ingresses
kubectl get ingress -A

# Check nginx sample
kubectl get pods -n nginx-sample
kubectl get svc -n nginx-sample

# Test access
curl https://nginx.dev.foobar.support
```

## Accessing Services

### Nginx Sample (Public)
- URL: https://nginx.dev.foobar.support
- Access: Internet (via external NLB)
- Certificate: Let's Encrypt (auto-renewed)

### Traefik Dashboard (Public)
- URL: https://traefik.dev.foobar.support/dashboard or https://traefik.dev.foobar.support/api
- Same public NLB as nginx; no VPN required once DNS has synced.
- Certificate: Let's Encrypt (auto-renewed)

### Rancher (Public)
- URL: https://rancher.dev.foobar.support (or your `route53_domain`)
- Same public NLB as nginx; no VPN required.

**If Traefik or Rancher don’t load:** Run 1-infrastructure apply so the public NLB gets `traefik` and `rancher` in external-dns; then wait for external-dns to update Route53 (or restart the external-dns deployment). Check certs: `kubectl get certificate -n traefik` (traefik-dashboard-tls, rancher-tls should be Ready).

## Adding New Applications

**See [ADDING-NEW-APP.md](../ADDING-NEW-APP.md)** for a step-by-step guide. In short: deploy your app, add its hostname to the public NLB in 1-infrastructure (external-dns), then in 2-applications add a Certificate and an IngressRoute in the **traefik** namespace (use `traefik.io/v1alpha1`). Do not rely on the applications module’s `ingresses` map for new apps; use the same explicit Certificate + IngressRoute pattern as nginx and rancher.

## Troubleshooting

### Certificate not issuing

```bash
# Check certificate status
kubectl describe certificate <cert-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

### Ingress not working

```bash
# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# Verify DNS records
dig nginx.dev.foobar.support
```

### Backend TLS errors

```bash
# Check if CA certificates exist
kubectl get secrets -n <namespace> | grep backend-ca

# Verify backend certificates
kubectl get certificates -n <namespace>
```

## Important Notes

- Let's Encrypt staging has high rate limits (use for testing)
- Let's Encrypt prod has strict rate limits (use after testing passes)
- Backend TLS is automatically configured per namespace
- external-dns automatically creates Route53 records for all ingresses
