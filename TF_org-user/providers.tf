
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key    = "TF_exec_role"
    region = "us-east-1"
  }
}