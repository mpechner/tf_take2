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

### Traefik Dashboard (Internal)
- URL: https://traefik.dev.foobar.support
- Access: VPN/internal network only (via internal NLB)
- Certificate: Let's Encrypt (auto-renewed)
- Auth: Basic auth (requires `traefik-auth-secret` to be created separately)

## Adding New Applications

To add a new application with automatic TLS:

1. Deploy your application to a namespace
2. Add an ingress configuration in `main.tf`:

```hcl
module "applications" {
  source = "./modules/ingress-applications"
  
  ingresses = {
    my-app = {
      namespace           = "my-namespace"
      host                = "myapp.dev.foobar.support"
      service_name        = "my-service"
      service_port        = 443
      cluster_issuer      = "letsencrypt-staging"
      backend_tls_enabled = true
    }
  }
}
```

3. Apply: `terraform apply`

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
