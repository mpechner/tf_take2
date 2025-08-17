# OpenVPN Terraform Configuration
# This file configures Terraform providers and backend

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Backend for state storage
  backend "s3" {
    bucket         = "mikey-com-terraformstate"
    key            = "openvpn/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state"
    encrypt        = true
  }
}

# AWS Provider Configuration
provider "aws" {
  region = "us-west-2"  # Change this to your preferred region

  default_tags {
    tags = {
      Project     = "OpenVPN"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Purpose     = "VPN Server"
    }
  }

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-openvpn"
  }
}

# Provider for ACM certificates (if in different region)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
