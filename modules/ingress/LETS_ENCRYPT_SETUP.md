# Let's Encrypt Setup Checklist

## Prerequisites

Before deploying the ingress stack, verify you have everything needed for Let's Encrypt:

### 1. AWS Route53 Setup
- [ ] Route53 hosted zone exists for your domain
- [ ] You know your hosted zone ID (e.g., `Z1234567890ABC`)
- [ ] Your domain is using Route53 nameservers

**Verify:**
```bash
# List your hosted zones
aws route53 list-hosted-zones-by-name

# Check nameservers for your domain
aws route53 get-hosted-zone --id Z1234567890ABC
```

### 2. AWS IAM Permissions
- [ ] Cluster nodes have Route53 permissions attached
- [ ] Permissions include: `route53:ChangeResourceRecordSets`, `route53:ListHostedZones`, `route53:GetChange`

**Required Policy:**
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

**Verify permissions:**
```bash
# Check IAM role attached to EC2 nodes
aws ec2 describe-instances --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Verify the role has Route53 permissions
aws iam list-attached-role-policies --role-name YOUR_ROLE_NAME
```

### 3. Email Address
- [ ] Valid email address for Let's Encrypt notifications
- [ ] You'll receive expiration reminders at this email

### 4. Domain Registration
- [ ] Domain is registered (e.g., example.com)
- [ ] Domain is using Route53 as DNS provider
- [ ] Domain nameservers point to Route53

**Verify DNS resolution:**
```bash
# Should return Route53 nameservers
nslookup example.com
```

## Configuration Checklist

### Step 1: Prepare terraform.tfvars

```hcl
# ✅ AWS Configuration
aws_region       = "us-west-2"  # Match your infrastructure
route53_zone_id  = "Z1234567890ABC"  # Your hosted zone ID
route53_domain   = "example.com"     # Your domain

# ✅ Let's Encrypt Configuration
letsencrypt_email       = "admin@example.com"  # Your email
letsencrypt_environment = "staging"            # START WITH STAGING!

# ✅ Enable all components
traefik_enabled      = true
external_dns_enabled = true
cert_manager_enabled = true
```

### Step 2: Verify Terraform Configuration

```bash
# Check variables are defined
cd /Users/mpechner/dev/tf_take2
grep -A 5 "letsencrypt" modules/ingress/variables.tf

# Verify cert-manager is enabled
grep "cert_manager_enabled" modules/ingress/variables.tf
```

### Step 3: Review ClusterIssuer Configuration

The module automatically creates ClusterIssuers:

```bash
# These will be created automatically by Terraform
# letsencrypt-staging (for testing)
# letsencrypt-prod (for production)

# Verify they exist after deployment
kubectl get clusterissuers
kubectl describe clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-prod
```

## Deployment Steps

### Step 1: Deploy with Staging First (IMPORTANT!)

```bash
# Update terraform.tfvars
letsencrypt_environment = "staging"

# Deploy
terraform apply -var-file=terraform.tfvars

# Verify cert-manager is running
kubectl get pods -n cert-manager
kubectl get clusterissuers
```

**Why staging first?**
- Let's Encrypt has rate limits (50 certs per domain/week for production)
- Staging lets you test without hitting limits
- Staging certificates are self-signed (browser warning, but working)

### Step 2: Test Certificate Creation

```bash
# Create a test ingress with staging issuer
kubectl apply -f - << 'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - test.example.com
      secretName: test-tls
  rules:
    - host: test.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 8080
YAML

# Watch certificate creation
kubectl get certificates -w
kubectl describe certificate test-tls

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f
```

### Step 3: Verify Certificate Issued

```bash
# Certificate should show READY=True
kubectl get certificate test-tls

# Check the secret was created
kubectl get secret test-tls
kubectl describe secret test-tls
```

### Step 4: Verify DNS Record Created

```bash
# External-DNS should have created the DNS record
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns -f

# Verify in Route53
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC | grep test.example.com

# Test DNS resolution
nslookup test.example.com
```

### Step 5: Test HTTPS Access

```bash
# Using staging certificate (ignore certificate warning)
curl -k https://test.example.com

# Check certificate details
openssl s_client -connect test.example.com:443 -showcerts
```

### Step 6: Switch to Production

Once staging works:

```hcl
# Update terraform.tfvars
letsencrypt_environment = "prod"

# Apply changes
terraform apply -var-file=terraform.tfvars
```

### Step 7: Update Ingress to Use Production

```bash
# Delete staging test ingress
kubectl delete ingress test-ingress

# Create new ingress with production issuer
kubectl apply -f - << 'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prod-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - myapp.example.com
      secretName: myapp-prod-tls
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
YAML
```

## Troubleshooting Let's Encrypt

### Certificate Pending (Stuck)

```bash
# Check certificate status
kubectl describe certificate myapp-tls

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager | tail -50

# Check certificate request
kubectl get certificaterequests
kubectl describe certificaterequest myapp-tls-1
```

**Common issues:**
- DNS not propagated yet (wait 5-10 minutes)
- Route53 permissions missing
- Hosted zone ID incorrect
- Let's Encrypt rate limit exceeded (use staging)

### DNS Record Not Created

```bash
# Check External-DNS logs
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns | tail -50

# Verify External-DNS has Route53 permissions
kubectl get deployment -n kube-system external-dns -o yaml | grep -A 10 "env:"

# Check if ingress has the right annotations
kubectl get ingress -o yaml
```

### Certificate Shows Wrong Issuer

```bash
# Verify which ClusterIssuer is being used
kubectl describe ingress myapp

# Check annotations
kubectl get ingress myapp -o jsonpath='{.metadata.annotations}'

# Should show: cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

### Let's Encrypt Rate Limited

```bash
# If you hit rate limits, switch to staging
letsencrypt_environment = "staging"

# Wait ~1 week before trying production again
# Or use a different domain subdomain
```

## Verification Checklist - All Done!

- [ ] terraform.tfvars has all required variables
- [ ] Route53 hosted zone ID is correct
- [ ] Route53 domain is configured in terraform
- [ ] Let's Encrypt email is valid
- [ ] AWS IAM permissions are attached to nodes
- [ ] Terraform deployed with `staging` environment
- [ ] Cert-manager pods are running
- [ ] ClusterIssuers exist (`kubectl get clusterissuers`)
- [ ] Test ingress created with staging issuer
- [ ] Certificate issued and ready
- [ ] DNS record created in Route53
- [ ] HTTPS works (staging cert shows warning, that's OK)
- [ ] Switched to production environment
- [ ] Production ingress created and working
- [ ] Browser shows valid certificate

## Next Steps

Once Let's Encrypt is working:

1. **Create more ingresses**: See `example-ingress.yaml`
2. **Monitor certificates**: `kubectl get certificates --all-namespaces`
3. **Setup backups**: Backup cert-manager secrets
4. **Monitor expiration**: Certificates auto-renew, but monitor logs

## References

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Cert-Manager Documentation](https://cert-manager.io/docs)
- [DNS01 Challenge with Route53](https://cert-manager.io/docs/configuration/acme/dns01/route53/)
- [Rate Limits](https://letsencrypt.org/docs/rate-limits/)

## Quick Commands

```bash
# Check everything is working
kubectl get pods -n kube-system | grep -E 'traefik|external-dns'
kubectl get pods -n cert-manager
kubectl get clusterissuers
kubectl get certificates --all-namespaces
kubectl get ingress --all-namespaces

# Monitor in real-time
watch -n 2 'kubectl get certificates && kubectl get clusterissuers'

# Test certificate
openssl s_client -connect myapp.example.com:443 -showcerts

# Verify DNS
nslookup myapp.example.com

# Check all logs
kubectl logs -n cert-manager -l app=cert-manager -f &
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns -f &
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f
```
