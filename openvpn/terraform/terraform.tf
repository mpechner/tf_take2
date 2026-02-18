# OpenVPN Terraform Configuration
# This file configures Terraform providers and backend

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
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

# AWS Provider: uses your default credentials (e.g. admin).
provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      Project     = "OpenVPN"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Purpose     = "VPN Server"
    }
  }
}

