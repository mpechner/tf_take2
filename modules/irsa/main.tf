# IRSA (IAM Roles for Service Accounts) Module for RKE2
# This module automates the setup of IRSA for self-managed Kubernetes clusters

locals {
  oidc_bucket_name = var.oidc_s3_bucket_name != "" ? var.oidc_s3_bucket_name : "${var.cluster_name}-oidc-${data.aws_caller_identity.current.account_id}"
  oidc_issuer_url  = "https://s3.${var.aws_region}.amazonaws.com/${local.oidc_bucket_name}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Generate OIDC signing keys using local-exec
resource "tls_private_key" "sa_signer" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "sa_signer" {
  private_key_pem = tls_private_key.sa_signer.private_key_pem

  subject {
    common_name  = "${var.cluster_name}-sa-signer"
    organization = "RKE2"
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}

# Create S3 bucket for OIDC discovery documents
resource "aws_s3_bucket" "oidc" {
  count  = var.create_oidc_bucket ? 1 : 0
  bucket = local.oidc_bucket_name

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-oidc"
    Cluster     = var.cluster_name
    Environment = var.environment
  })
}

resource "aws_s3_bucket_public_access_block" "oidc" {
  count  = var.create_oidc_bucket ? 1 : 0
  bucket = aws_s3_bucket.oidc[0].id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "oidc" {
  count  = var.create_oidc_bucket ? 1 : 0
  bucket = aws_s3_bucket.oidc[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.oidc[0].arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.oidc]
}

# Generate OIDC discovery document
locals {
  oidc_discovery = {
    issuer                 = local.oidc_issuer_url
    jwks_uri               = "${local.oidc_issuer_url}/openid/v1/jwks"
    authorization_endpoint = "urn:kubernetes:programmatic_authorization"
    response_types_supported = ["id_token"]
    subject_types_supported  = ["public"]
    id_token_signing_alg_values_supported = ["RS256"]
    claims_supported = [
      "sub",
      "iss"
    ]
  }

  # Generate JWKS from the public key
  jwks = {
    keys = [
      {
        use = "sig"
        kty = "RSA"
        kid = "sa-signer"
        alg = "RS256"
        n   = base64encode(tls_private_key.sa_signer.public_key_pem)
        e   = "AQAB"
      }
    ]
  }
}

# Upload OIDC discovery documents to S3
resource "aws_s3_object" "oidc_discovery" {
  count  = var.create_oidc_bucket ? 1 : 0
  bucket = aws_s3_bucket.oidc[0].id
  key    = ".well-known/openid-configuration"
  content = jsonencode(local.oidc_discovery)
  content_type = "application/json"

  depends_on = [aws_s3_bucket_policy.oidc]
}

resource "aws_s3_object" "oidc_jwks" {
  count  = var.create_oidc_bucket ? 1 : 0
  bucket = aws_s3_bucket.oidc[0].id
  key    = "openid/v1/jwks"
  content = jsonencode(local.jwks)
  content_type = "application/json"

  depends_on = [aws_s3_bucket_policy.oidc]
}

# Create OIDC Provider in AWS IAM
resource "aws_iam_openid_connect_provider" "this" {
  url             = local.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint.certificates[0].sha1_fingerprint]

  depends_on = [aws_s3_object.oidc_discovery]

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-oidc"
    Cluster     = var.cluster_name
    Environment = var.environment
  })
}

# Get the TLS certificate thumbprint for the OIDC provider
data "tls_certificate" "oidc_thumbprint" {
  url = local.oidc_issuer_url

  depends_on = [aws_s3_object.oidc_discovery]
}

# Create IAM Role for ECR Access
resource "aws_iam_role" "ecr" {
  name = "${var.cluster_name}-ecr-role"

  assume_role_policy = templatefile("${path.module}/policies/irsa-assume-role-policy.json.tftpl", {
    oidc_provider_arn = aws_iam_openid_connect_provider.this.arn
    oidc_provider_url = aws_iam_openid_connect_provider.this.url
    namespace           = var.ecr_service_account_namespace
    service_account     = var.ecr_service_account_name
  })

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-ecr-role"
    Cluster     = var.cluster_name
    Environment = var.environment
  })
}

# Attach ECR policy to the role
resource "aws_iam_role_policy" "ecr" {
  name = "${var.cluster_name}-ecr-policy"
  role = aws_iam_role.ecr.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = var.ecr_repository_arns
      }
    ]
  })
}

# Save signing key to S3 for RKE2 nodes to download
resource "aws_s3_object" "sa_signer_key" {
  count  = var.create_oidc_bucket ? 1 : 0
  bucket = aws_s3_bucket.oidc[0].id
  key    = "sa-signer.key"
  content = tls_private_key.sa_signer.private_key_pem
}

resource "aws_s3_object" "sa_signer_pub" {
  count  = var.create_oidc_bucket ? 1 : 0
  bucket = aws_s3_bucket.oidc[0].id
  key    = "sa-signer.pub"
  content = tls_private_key.sa_signer.public_key_pem
}

# Store the service account signing key in AWS Secrets Manager
resource "aws_secretsmanager_secret" "sa_signer" {
  name                    = "${var.cluster_name}/sa-signer-key"
  description             = "Service account signing key for IRSA"
  recovery_window_in_days = 0

  tags = merge(var.tags, {
    Cluster     = var.cluster_name
    Environment = var.environment
  })
}

resource "aws_secretsmanager_secret_version" "sa_signer" {
  secret_id     = aws_secretsmanager_secret.sa_signer.id
  secret_string = tls_private_key.sa_signer.private_key_pem
}
