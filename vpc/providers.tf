
provider "aws" {
  region = "us-west-2"

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/terraform-execute"
  }
}

terraform {
  # REQUIRED: Set bucket, region, dynamodb_table for your environment (cannot use variables in backend block). See repo README § Terraform state backend.
  backend "s3" {
    bucket = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key    = "Network"
    region = "us-east-1"
  }
}