# Ingress Module - Quick Start Guide

## 5-Minute Setup

### 1. Get Your Route53 Information
```bash
# Find your hosted zone ID
aws route53 list-hosted-zones-by-name --query 'HostedZones[0].[Id,Name]' --output text
```
Note the Zone ID (remove `/hostedzone/` prefix) and domain name.

### 2. Configure Variables
Create/update your terraform variables (or terraform.tfvars):
```hcl
module "ingress" {
  source = "./modules/ingress"

  # Your AWS setup
  aws_region       = "us-west-2"
  route53_zone_id  = "Z123456789ABC"     # From above
  route53_domain   = "example.com"       # Your domain

  # Let's Encrypt setup
  letsencrypt_email       = "you@example.com"
  letsencrypt_environment = "prod"

  # All enabled by default
  traefik_enabled      = true
  external_dns_enabled = true
  cert_manager_enabled = true
}
```

### 3. Configure IAM Permissions
Ensure your Kubernetes cluster nodes have these IAM permissions. Add to your node role:

**Policy**: Route53 Access
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:GetChange",
        "route53:ListHostedZonesByName"
      ],
      "Resource": "*"
    }
  ]
}
```

### 4. Deploy
```bash
cd modules/ingress
terraform init
terraform apply
```

### 5. Verify Installation
```bash
# Check services are running
kubectl get pods -n kube-system | grep -E 'traefik|external-dns'
kubectl get pods -n cert-manager

# Get Traefik's public IP
kubectl get svc -n kube-system traefik
```

## Creating Your First Ingress

### Option A: Quick & Simple (Recommended)

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - myapp.example.com
      secretName: myapp-tls
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 8080
EOF
```

Replace:
- `myapp.example.com` with your subdomain
- `my-service` with your service name
- `8080` with your service port

### Option B: Using Traefik IngressRoute

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.example.com`)
      kind: Rule
      services:
        - name: my-service
          port: 8080
  tls:
    certResolver: letsencrypt-prod
EOF
```

## What Happens Automatically

1. **Traefik** sees your ingress
2. **Cert-Manager** requests a certificate from Let's Encrypt
3. **Let's Encrypt** validates via DNS challenge using your Route53 zone
4. **External-DNS** creates an A record in Route53 for your subdomain
5. Traffic flows: `https://myapp.example.com` → **Traefik** → Your service

This all happens automatically in ~2-5 minutes! ✨

## Monitoring Progress

### Watch Certificate Creation
```bash
kubectl get certificates -w
kubectl describe certificate myapp-tls
```

### Watch DNS Record Creation
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns -f
```

### Check Traefik Dashboard
```bash
# Port-forward to dashboard
kubectl port-forward -n kube-system svc/traefik 8080:8080

# Open browser to: http://localhost:8080/dashboard
```

## Troubleshooting Quick Checks

### Certificate Stuck Pending?
```bash
kubectl describe certificate myapp-tls
kubectl get certificaterequests
```

### DNS Not Created?
```bash
# Check External-DNS has Route53 permissions
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns | tail -20

# Verify hosted zone ID is correct
kubectl get deployment -n kube-system external-dns -o yaml | grep zone
```

### Service Unreachable?
```bash
# Verify Traefik has a public IP
kubectl get svc -n kube-system traefik

# Test with curl (use staging cert first to avoid rate limits)
curl -k https://myapp.example.com
```

## Accessing Your Apps

Once everything is set up:

```bash
# Your app
curl https://myapp.example.com

# Traefik Dashboard (port-forward first)
curl http://localhost:8080/dashboard

# Check DNS is resolving
nslookup myapp.example.com
```

## Common Issues & Fixes

| Issue | Check |
|-------|-------|
| Certificate not issuing | `kubectl logs -n cert-manager -l app=cert-manager` |
| DNS records not created | IAM permissions on nodes, `kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns` |
| Service stuck pending | `traefik_service_type = "NodePort"` if LoadBalancer not available |
| Too many redirects | Check if backend service is actually running |
| 502 Bad Gateway | Service not found or port incorrect in ingress |

## Next Steps

- Read the full [README.md](README.md) for advanced configuration
- Check [example-ingress.yaml](example-ingress.yaml) for more ingress patterns
- Explore [Traefik documentation](https://doc.traefik.io) for advanced routing
- Set up multiple environments using Helm values files

## Using Let's Encrypt Staging First (RECOMMENDED)

For testing, use staging to avoid rate limits:

```hcl
letsencrypt_environment = "staging"
```

Then in your ingress, reference `letsencrypt-staging`:
```yaml
tls:
  certResolver: letsencrypt-staging
```

Once working, switch to `prod`.
