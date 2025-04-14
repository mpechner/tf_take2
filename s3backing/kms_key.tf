resource "aws_kms_key" "org_shared_key" {
  description             = "KMS key for use by all accounts in Org r-u7bj"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "org-wide-kms-key-policy",
    Statement = [
      {
        Sid       = "EnableRootAccountPermissions",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "AllowUseForAllOrgAccounts",
        Effect    = "Allow",
        Principal = "*",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource  = "*",
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = "r-u7bj"
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "org_shared_key_alias" {
  name          = "alias/org-shared-s3-key"
  target_key_id = aws_kms_key.org_shared_key.key_id
}

data "aws_caller_identity" "current" {}
