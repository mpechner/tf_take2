data "aws_subnet" "first" {
  id = element(var.subnet_ids, 0)
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  vpc_id_resolved   = var.vpc_id != "" ? var.vpc_id : data.aws_subnet.first.vpc_id
  aws_account_id    = data.aws_caller_identity.current.account_id
  aws_region        = data.aws_region.current.name
  terraform_role_arn = "arn:aws:iam::${local.aws_account_id}:role/terraform-execute"
}

data "aws_vpc" "selected" {
  id = local.vpc_id_resolved
}

locals {
  vpc_cidr_resolved = var.vpc_cidr != "" ? var.vpc_cidr : data.aws_vpc.selected.cidr_block
}