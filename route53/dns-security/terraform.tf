terraform {
  required_version = ">= 1.3"
  # REQUIRED: Set bucket, region, dynamodb_table for your environment (cannot use variables in backend block). See repo README § Terraform state backend.
  backend "s3" {
    bucket = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key    = "route53-dns-security"
    region = "us-east-1"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID to deploy into"
}

variable "network_account_id" {
  type        = string
  description = "AWS account ID for the network/Route53 parent zone account"
}

provider "aws" {
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.network_account_id}:role/terraform-execute"
  }
}

provider "aws" {
  alias  = "dev"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/terraform-execute"
  }
}