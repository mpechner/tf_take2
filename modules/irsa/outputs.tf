output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC Provider"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider"
  value       = aws_iam_openid_connect_provider.this.url
}

output "oidc_issuer_url" {
  description = "Issuer URL for RKE2 kubelet configuration"
  value       = local.oidc_issuer_url
}

output "ecr_iam_role_arn" {
  description = "ARN of the IAM role for ECR access via IRSA"
  value       = aws_iam_role.ecr.arn
}

output "ecr_service_account_namespace" {
  description = "Namespace for the ECR service account"
  value       = var.ecr_service_account_namespace
}

output "ecr_service_account_name" {
  description = "Name of the ECR service account"
  value       = var.ecr_service_account_name
}

output "sa_signer_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the SA signer key"
  value       = aws_secretsmanager_secret.sa_signer.arn
}

output "sa_signer_key_secret_name" {
  description = "Name of the Secrets Manager secret containing the SA signer key"
  value       = aws_secretsmanager_secret.sa_signer.name
}

output "rke2_kubelet_args" {
  description = "Kubelet arguments to add to RKE2 config for IRSA"
  value       = <<-EOT
    kubelet-arg:
      - "service-account-issuer=${local.oidc_issuer_url}"
      - "service-account-signing-key-file=/etc/rancher/rke2/sa-signer.key"
      - "service-account-key-file=/etc/rancher/rke2/sa-signer.pub"
      - "api-audiences=sts.amazonaws.com"
  EOT
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting OIDC documents"
  value       = var.create_oidc_bucket ? aws_s3_bucket.oidc[0].id : null
}

output "next_steps" {
  description = "Next steps to complete IRSA setup"
  value       = <<-EOT

IRSA Setup Complete! Next steps:

1. Download SA signing key to RKE2 nodes (run on each node):
   aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.sa_signer.name} --query SecretString --output text > /etc/rancher/rke2/sa-signer.key
   aws s3 cp s3://${local.oidc_bucket_name}/sa-signer.pub /etc/rancher/rke2/sa-signer.pub

2. Update RKE2 config (/etc/rancher/rke2/config.yaml) with these kubelet args:
   kubelet-arg:
     - "service-account-issuer=${local.oidc_issuer_url}"
     - "service-account-signing-key-file=/etc/rancher/rke2/sa-signer.key"
     - "service-account-key-file=/etc/rancher/rke2/sa-signer.pub"
     - "api-audiences=sts.amazonaws.com"

3. Restart RKE2:
   sudo systemctl restart rke2-server

4. Install AWS Pod Identity Webhook:
   kubectl apply -k "github.com/aws/amazon-eks-pod-identity-webhook/deploy?ref=master"

5. Create service account with annotation:
   kubectl create serviceaccount ${var.ecr_service_account_name} -n ${var.ecr_service_account_namespace}
   kubectl annotate serviceaccount ${var.ecr_service_account_name} -n ${var.ecr_service_account_namespace} eks.amazonaws.com/role-arn=${aws_iam_role.ecr.arn}

6. Use the service account in your pods to pull from ECR.
  EOT
}
