
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # REQUIRED: Set bucket, region, dynamodb_table for your environment (cannot use variables in backend block). See repo README § Terraform state backend.
  backend "s3" {
    bucket = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key    = "TF_exec_role"
    region = "us-east-1"
  }
}