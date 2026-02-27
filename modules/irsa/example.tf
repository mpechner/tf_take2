# Example: Using the IRSA module with RKE2 cluster

# First, deploy your RKE2 cluster using the server and agent modules
# Then, deploy IRSA:

module "irsa" {
  source = "../../modules/irsa"

  cluster_name = "dev"
  environment  = "dev"
  aws_region   = "us-west-2"

  # Optionally specify a custom S3 bucket name
  # oidc_s3_bucket_name = "my-custom-oidc-bucket"

  # Service account configuration
  ecr_service_account_namespace = "default"
  ecr_service_account_name      = "ecr-reader"

  # Restrict to specific ECR repositories (recommended for production)
  # ecr_repository_arns = [
  #   "arn:aws:ecr:us-west-2:123456789:repository/my-app",
  #   "arn:aws:ecr:us-west-2:123456789:repository/my-api"
  # ]

  tags = {
    Environment = "dev"
    Project     = "rke2"
  }
}

# Output the setup instructions
output "irsa_setup_instructions" {
  description = "Instructions for completing IRSA setup"
  value       = module.irsa.next_steps
}

# Output the IAM role ARN for reference
output "irsa_ecr_role_arn" {
  description = "ARN of the IAM role for ECR access"
  value       = module.irsa.ecr_iam_role_arn
}

# Example Kubernetes manifest for the service account
# Save this as service-account.yaml and apply after IRSA setup:
#
# apiVersion: v1
# kind: ServiceAccount
# metadata:
#   name: ecr-reader
#   namespace: default
#   annotations:
#     eks.amazonaws.com/role-arn: <module.irsa.ecr_iam_role_arn output>
#
# ---
# apiVersion: apps/v1
# kind: Deployment
# metadata:
#   name: my-app
# spec:
#   replicas: 1
#   selector:
#     matchLabels:
#       app: my-app
#   template:
#     metadata:
#       labels:
#         app: my-app
#     spec:
#       serviceAccountName: ecr-reader
#       containers:
#       - name: my-app
#         image: 123456789.dkr.ecr.us-west-2.amazonaws.com/my-app:latest
