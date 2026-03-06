locals {
  terraform_execute_role_arn = "arn:aws:iam::${var.management_account_id}:role/terraform-execute"
  default_role_arn           = coalesce(var.aws_assume_role_arn, local.terraform_execute_role_arn)
  dr_role_arn                = coalesce(var.dr_assume_role_arn, local.terraform_execute_role_arn)
}

# AWS Organizations is a global service — region only affects STS endpoint for assume_role.
# us-east-1 is used because STS is not activated in us-west-2 for the management account.
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn = local.default_role_arn
  }
}

provider "aws" {
  alias  = "primary"
  region = "us-east-1"

  assume_role {
    role_arn = local.default_role_arn
  }
}

provider "aws" {
  alias  = "dr"
  region = "us-east-2"

  assume_role {
    role_arn = local.dr_role_arn
  }
}

terraform {
  # REQUIRED: Set bucket, region, dynamodb_table for your environment (cannot use variables in backend block). See repo README § Terraform state backend.
  backend "s3" {
    bucket         = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key            = "Organizartion"
    region         = "us-east-1"
  }
}
