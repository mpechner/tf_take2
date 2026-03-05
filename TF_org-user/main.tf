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

#mgmt
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