
provider "aws" {
  region = "us-west-2"

  assume_role {
    role_arn = var.aws_assume_role_arn
  }
}

provider "aws" {
  alias  = "primary"
  region = "us-west-2"

  assume_role {
    role_arn = var.aws_assume_role_arn
  }
}

provider "aws" {
  alias  = "dr"
  region = "us-east-2"

  assume_role {
    role_arn = var.dr_assume_role_arn
  }
}
terraform {
  # REQUIRED: Set bucket, region, dynamodb_table for your environment (cannot use variables in backend block). See repo README § Terraform state backend.
  backend "s3" {
    bucket = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key    = "Organizartion"
    region = "us-east-1"
  }
}