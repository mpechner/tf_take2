variable "cluster_name" {
  description = "Name of the RKE2 cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "oidc_s3_bucket_name" {
  description = "Name of the S3 bucket for OIDC discovery documents. If empty, will be generated as '{cluster_name}-oidc-{account_id}'"
  type        = string
  default     = ""
}

variable "create_oidc_bucket" {
  description = "Whether to create the OIDC S3 bucket"
  type        = bool
  default     = true
}

variable "ecr_service_account_namespace" {
  description = "Namespace for the ECR service account"
  type        = string
  default     = "default"
}

variable "ecr_service_account_name" {
  description = "Name of the service account for ECR access"
  type        = string
  default     = "ecr-reader"
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs that the role can access"
  type        = list(string)
  default     = ["*"]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
