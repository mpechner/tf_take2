data "aws_subnet" "first" {
  id = element(var.subnet_ids, 0)
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_kms_key" "ebs_default" {
  key_id = "alias/aws/ebs"
}

locals {
  vpc_id_resolved    = var.vpc_id != "" ? var.vpc_id : data.aws_subnet.first.vpc_id
  aws_account_id     = data.aws_caller_identity.current.account_id
  aws_region         = data.aws_region.current.name
  terraform_role_arn = "arn:aws:iam::${local.aws_account_id}:role/terraform-execute"
  # Use the caller-supplied CMK if provided, otherwise fall back to the
  # AWS-managed EBS key for this account/region (explicit rather than null).
  ebs_kms_key_id = var.ebs_kms_key_id != "" ? var.ebs_kms_key_id : data.aws_kms_key.ebs_default.arn
}

data "aws_vpc" "selected" {
  id = local.vpc_id_resolved
}

locals {
  vpc_cidr_resolved = var.vpc_cidr != "" ? var.vpc_cidr : data.aws_vpc.selected.cidr_block
}