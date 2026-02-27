# IRSA (IAM Roles for Service Accounts) Module for RKE2

This Terraform module automates the setup of IRSA (IAM Roles for Service Accounts) for self-managed RKE2 clusters on AWS. IRSA allows fine-grained IAM access at the pod level, rather than node-level access.

## Overview

IRSA enables Kubernetes service accounts to assume IAM roles via OIDC, allowing:
- Pod-level IAM permissions (not node-level)
- Fine-grained access control
- No need for the `ecr-credential-provider` binary
- AWS SDK credential chain support

## What This Module Creates

1. **OIDC Signing Keys** - RSA keypair for signing service account tokens
2. **S3 Bucket** - Public S3 bucket hosting OIDC discovery documents
3. **OIDC Provider** - AWS IAM OIDC provider pointing to the S3 bucket
4. **IAM Role** - Role for ECR access with trust policy for the OIDC provider
5. **Secrets Manager Secret** - Secure storage of the signing key for RKE2 nodes

## Usage

### Basic Example

```hcl
module "irsa" {
  source = "../../modules/irsa"

  cluster_name = "dev"
  environment  = "dev"
  aws_region   = "us-west-2"

  ecr_service_account_namespace = "default"
  ecr_service_account_name      = "ecr-reader"
  ecr_repository_arns           = [
    "arn:aws:ecr:us-west-2:123456789:repository/my-app"
  ]

  tags = {
    Environment = "dev"
    Project     = "rke2"
  }
}
```

### Using the Output

```hcl
output "irsa_setup" {
  value = module.irsa.next_steps
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |
| tls | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |
| tls | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the RKE2 cluster | `string` | n/a | yes |
| environment | Environment name | `string` | `"dev"` | no |
| aws_region | AWS region | `string` | `"us-west-2"` | no |
| oidc_s3_bucket_name | S3 bucket name for OIDC (auto-generated if empty) | `string` | `""` | no |
| create_oidc_bucket | Whether to create the OIDC S3 bucket | `bool` | `true` | no |
| ecr_service_account_namespace | Namespace for ECR service account | `string` | `"default"` | no |
| ecr_service_account_name | Name of ECR service account | `string` | `"ecr-reader"` | no |
| ecr_repository_arns | ECR repository ARNs to allow access | `list(string)` | `["*"]` | no |
| tags | Tags for resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| oidc_provider_arn | ARN of the IAM OIDC Provider |
| oidc_provider_url | URL of the OIDC Provider |
| oidc_issuer_url | Issuer URL for RKE2 kubelet config |
| ecr_iam_role_arn | ARN of the IAM role for ECR access |
| sa_signer_key_secret_name | Secrets Manager secret name for signing key |
| rke2_kubelet_args | Kubelet arguments to add to RKE2 config |
| next_steps | Instructions for completing IRSA setup |

## Post-Deployment Steps

After running this module, complete the setup:

### 1. Configure RKE2 Nodes

On each RKE2 server node, run:

```bash
# Download signing key from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw sa_signer_key_secret_name) \
  --query SecretString --output text > /etc/rancher/rke2/sa-signer.key

# Download public key from S3
aws s3 cp s3://$(terraform output -raw s3_bucket_name)/sa-signer.pub /etc/rancher/rke2/sa-signer.pub

# Set permissions
chmod 600 /etc/rancher/rke2/sa-signer.key
chmod 644 /etc/rancher/rke2/sa-signer.pub
```

### 2. Update RKE2 Configuration

Edit `/etc/rancher/rke2/config.yaml` and add:

```yaml
kubelet-arg:
  - "service-account-issuer=$(terraform output -raw oidc_issuer_url)"
  - "service-account-signing-key-file=/etc/rancher/rke2/sa-signer.key"
  - "service-account-key-file=/etc/rancher/rke2/sa-signer.pub"
  - "api-audiences=sts.amazonaws.com"
```

Restart RKE2:
```bash
sudo systemctl restart rke2-server
```

### 3. Install AWS Pod Identity Webhook

```bash
kubectl apply -k "github.com/aws/amazon-eks-pod-identity-webhook/deploy?ref=master"
```

### 4. Create Service Account

```bash
# Create service account
kubectl create serviceaccount ecr-reader -n default

# Annotate with IAM role
kubectl annotate serviceaccount ecr-reader -n default \
  eks.amazonaws.com/role-arn=$(terraform output -raw ecr_iam_role_arn)
```

### 5. Use in Your Application

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      serviceAccountName: ecr-reader
      containers:
        - name: app
          image: 123456789.dkr.ecr.us-west-2.amazonaws.com/my-app:latest
```

## How It Works

1. **Key Generation**: Terraform generates RSA keypair for signing service account tokens
2. **S3 Hosting**: OIDC discovery documents (.well-known/openid-configuration and JWKS) are hosted on public S3
3. **OIDC Provider**: AWS IAM OIDC provider is created pointing to the S3 bucket
4. **Trust Relationship**: IAM role has trust policy allowing specific service accounts to assume it
5. **Token Signing**: RKE2 uses the private key to sign service account tokens
6. **AWS STS**: When pod calls AWS API, AWS validates token signature against OIDC JWKS

## Security Considerations

- The S3 bucket is public-read for OIDC discovery (required by AWS)
- The private signing key is stored in AWS Secrets Manager
- Keys are rotated by tainting and re-applying the module
- Service account tokens are time-limited (1 hour default)
- Each service account can only assume its designated IAM role

## Troubleshooting

### OIDC Provider Not Found

Ensure S3 bucket objects are created before the OIDC provider:
```bash
terraform apply -target=aws_s3_object.oidc_discovery -target=aws_s3_object.oidc_jwks
```

### Token Signature Invalid

Verify the signing key is correctly downloaded on RKE2 nodes:
```bash
openssl rsa -in /etc/rancher/rke2/sa-signer.key -check
```

### Pods Can't Assume Role

Check the service account annotation:
```bash
kubectl get serviceaccount <sa-name> -o yaml
```

Verify the IAM role trust policy matches the service account.

## References

- [RKE2 IRSA Discussion](https://github.com/rancher/rke2/discussions/7691)
- [AWS Pod Identity Webhook](https://github.com/aws/amazon-eks-pod-identity-webhook)
- [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Self-managed Kubernetes IRSA](https://blog.kubernauts.io/iam-roles-for-service-accounts-in-self-managed-kubernetes-clusters-on-aws-7ab6b8d76c42)
