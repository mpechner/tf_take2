# Ingress Module Deployment Plan

**Date Created**: November 1, 2025
**Status**: Ready to Deploy
**Target**: Deploy after AWS infrastructure is up

## Overview

This document outlines the complete ingress stack deployment plan for Kubernetes with:
- **Traefik**: Ingress controller and reverse proxy
- **External-DNS**: Automatic Route53 DNS management
- **Cert-Manager**: Automatic Let's Encrypt TLS certificates

## Pre-Deployment Checklist

### Infrastructure Requirements
- [ ] Kubernetes cluster is running (RKE/RKE2)
- [ ] kubectl configured and accessible
- [ ] Helm provider configured for Kubernetes access
- [ ] AWS credentials available with appropriate permissions
- [ ] Route53 hosted zone already created

### AWS Permissions Required

Ensure cluster nodes have these IAM permissions attached:

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

### Information to Gather

Before running terraform apply, collect:

1. **Route53 Hosted Zone ID**
   ```bash
   aws route53 list-hosted-zones-by-name --query 'HostedZones[0].[Id,Name]' --output text
   # Output: /hostedzone/Z1234567890ABC     example.com
   # Use: Z1234567890ABC (remove /hostedzone/ prefix)
   ```

2. **Domain Name**
   - Your registered domain (e.g., example.com)

3. **Let's Encrypt Email**
   - Email for certificate expiration notifications

## Deployment Steps

### Step 1: Prepare Configuration

Create or update `terraform.tfvars`:

```hcl
# Route53 Configuration
aws_region       = "us-west-2"
route53_zone_id  = "Z1234567890ABC"  # Replace with your zone ID
route53_domain   = "example.com"     # Replace with your domain

# Let's Encrypt Configuration
letsencrypt_email       = "admin@example.com"  # Replace with your email
letsencrypt_environment = "prod"               # Use "staging" for testing first

# Component Flags (all enabled by default)
traefik_enabled      = true
external_dns_enabled = true
cert_manager_enabled = true
```

### Step 2: Review Configuration Files

All configuration files are in `modules/ingress/`:

- ✅ `main.tf` - Core module with all providers and resources
- ✅ `variables.tf` - Input variables
- ✅ `outputs.tf` - Output definitions
- ✅ `traefik/main.tf` - Traefik Helm release
- ✅ `external-dns/main.tf` - External-DNS Helm release  
- ✅ `cert-manager/main.tf` - Cert-Manager Helm release

### Step 3: Deploy the Ingress Stack

```bash
cd /Users/mpechner/dev/tf_take2

# Initialize (first time only)
terraform init

# Review the plan
terraform plan -var-file=terraform.tfvars

# Apply the configuration
terraform apply -var-file=terraform.tfvars
```

### Step 4: Verify Installation

```bash
# Check all pods are running
kubectl get pods -n kube-system | grep -E 'traefik|external-dns'
kubectl get pods -n cert-manager

# Get Traefik's public IP/LoadBalancer
kubectl get svc -n kube-system traefik

# Verify ClusterIssuers are ready
kubectl get clusterissuers
```

### Step 5: Create Test Ingress

Once verified, create your first ingress:

```bash
kubectl apply -f - << 'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-dashboard
  namespace: kube-system
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - traefik.example.com
      secretName: traefik-dashboard-tls
  rules:
    - host: traefik.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: traefik
                port:
                  number: 80
YAML
```

(Replace `example.com` with your actual domain)

### Step 6: Monitor Progress

```bash
# Watch certificate creation (should complete in 2-5 minutes)
kubectl get certificates -w

# Watch DNS record creation
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns -f

# Test DNS resolution
nslookup traefik.example.com

# Test HTTPS access
curl https://traefik.example.com
```

## Expected Timeline

| Step | Duration | What's Happening |
|------|----------|------------------|
| Apply terraform | 2-3 min | Helm charts download and install |
| Pods start | 2-5 min | Traefik, External-DNS, Cert-Manager starting |
| ClusterIssuer ready | 1-2 min | Let's Encrypt configuration applied |
| Create ingress | Immediate | Ingress resource created |
| Certificate issuance | 2-10 min | Cert-Manager requests cert, Let's Encrypt validates |
| DNS record creation | 1-2 min | External-DNS creates Route53 record |
| DNS propagation | Variable | 5 min - 48 hours (usually 5-30 min) |
| HTTPS accessible | Variable | Once DNS propagates |

**Total expected time: 5-30 minutes** (can be up to 48 hours for global DNS propagation)

## Troubleshooting During Deployment

### Check Traefik is Running
```bash
kubectl describe pod -n kube-system -l app.kubernetes.io/name=traefik
```

### Check External-DNS Permissions
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns | tail -50
# Should show successful Route53 API calls, not permission errors
```

### Check Cert-Manager Logs
```bash
kubectl logs -n cert-manager -l app=cert-manager | tail -50
# Should show successful Let's Encrypt interactions
```

### Certificate Pending?
```bash
kubectl describe certificate traefik-dashboard-tls
kubectl get certificaterequests
kubectl describe certificaterequest <name>
```

## Files Modified/Created

### Modified Files
- `modules/ingress/variables.tf` - Added AWS/Route53 variables
- `modules/ingress/main.tf` - Added Kubernetes provider, ClusterIssuer, Dashboard
- `modules/ingress/traefik/main.tf` - Enabled dashboard and API
- `modules/ingress/external-dns/main.tf` - Added IAM documentation

### New Documentation Files
- `modules/ingress/README.md` - Comprehensive documentation
- `modules/ingress/QUICK_START.md` - 5-minute setup guide
- `modules/ingress/example.tfvars` - Variable template
- `modules/ingress/example-ingress.yaml` - Sample ingresses
- `modules/ingress/CONFIGURATION_SUMMARY.md` - Configuration overview
- `INGRESS_DEPLOYMENT_PLAN.md` - This file

## Post-Deployment Tasks

### Create Example Ingresses

See `modules/ingress/example-ingress.yaml` for patterns:
1. Basic IngressRoute
2. Standard Kubernetes Ingress
3. API with path-based routing
4. Multiple hosts
5. With middleware/security headers

### Monitor Certificate Lifecycle

```bash
# View all certificates
kubectl get certificates --all-namespaces

# Watch expiration dates
kubectl get certificates --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.renewalTime}{"\n"}{end}'
```

### Backup Important Data

```bash
# Backup certificates and secrets
kubectl get secret -n cert-manager letsencrypt-prod -o yaml > letsencrypt-prod-backup.yaml

# Backup Traefik configuration
kubectl get configmap -n kube-system -o yaml > traefik-configmap-backup.yaml
```

## Rollback Instructions

If needed to remove the ingress stack:

```bash
# Remove all ingresses first (to avoid orphaned DNS records)
kubectl delete ingress --all-namespaces

# Wait a moment for External-DNS to clean up DNS records
sleep 30

# Destroy Terraform
cd /Users/mpechner/dev/tf_take2
terraform destroy -target=module.ingress
```

## Support Documentation

- Full README: `modules/ingress/README.md`
- Quick start: `modules/ingress/QUICK_START.md`
- Example configurations: `modules/ingress/example-ingress.yaml`
- Configuration summary: `modules/ingress/CONFIGURATION_SUMMARY.md`

## Next Actions

1. **When AWS Infrastructure is Ready**:
   - [ ] Verify Kubernetes cluster is accessible
   - [ ] Verify kubectl can connect to cluster
   - [ ] Confirm Route53 hosted zone exists
   - [ ] Confirm IAM permissions are attached to nodes

2. **Before Running Terraform**:
   - [ ] Gather Route53 Zone ID and Domain name
   - [ ] Prepare Let's Encrypt email address
   - [ ] Create/update terraform.tfvars
   - [ ] Run `terraform plan` to review changes

3. **After Deployment**:
   - [ ] Verify all pods are running
   - [ ] Test Traefik service has public IP
   - [ ] Create test ingress
   - [ ] Monitor certificate and DNS creation
   - [ ] Test HTTPS access

## Contact/Questions

If issues arise during deployment:
1. Check `QUICK_START.md` troubleshooting section
2. Review full `README.md` for detailed configuration
3. Check logs as documented in Troubleshooting section above
4. Review Let's Encrypt rate limits if certificates failing

---

**Ready to deploy!** Execute when AWS infrastructure is available.
