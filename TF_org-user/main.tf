# dev
provider "aws" {
  alias  = "dev"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.dev_account_id}:role/OrganizationAccountAccessRole"
  }
}

module "terraform_execute_dev1" {
  source = "./modules/terraform_execute_role"
  providers = {
    aws = aws.dev
  }
  principal_account_id = var.mgmt_account_id
}

#mgmt member account (management OU account)
provider "aws" {
  alias  = "mgmt"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.mgmt_org_account_id}:role/OrganizationAccountAccessRole"
  }
}

module "terraform_execute_mgmt" {
  source = "./modules/terraform_execute_role"
  providers = {
    aws = aws.mgmt
  }
  principal_account_id = var.mgmt_account_id
}

# network
provider "aws" {
  alias  = "network"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.network_account_id}:role/OrganizationAccountAccessRole"
  }
}

module "terraform_execute_network" {
  source = "./modules/terraform_execute_role"
  providers = {
    aws = aws.network
  }
  principal_account_id = var.mgmt_account_id
}

# prod
provider "aws" {
  alias  = "prod"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.prod_account_id}:role/OrganizationAccountAccessRole"
  }
}

module "terraform_execute_prod" {
  source = "./modules/terraform_execute_role"
  providers = {
    aws = aws.prod
  }
  principal_account_id = var.mgmt_account_id
}

# org root (management account — where IAM user lives, no assume_role needed)
# This creates terraform-execute in the org management account (var.mgmt_account_id)
# so Organization/ can run without bootstrap mode.
provider "aws" {
  alias  = "org_root"
  region = "us-west-2"
}

module "terraform_execute_org_root" {
  source = "./modules/terraform_execute_role"
  providers = {
    aws = aws.org_root
  }
  principal_account_id = var.mgmt_account_id
}