
data "aws_availability_zones" "available" {}

locals {
  name   = var.name
  region = var.region

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Example    = var.name
    GithubRepo = "terraform-aws-vpc"
    GithubOrg  = "terraform-aws-modules"
    ManagedBy = "terraform"
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  cidr = var.vpc_cidr

  azs                 = var.azs
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  database_subnets    = var.db_subnets 
  elasticache_subnets = []
  redshift_subnets    = []
  intra_subnets       = []

  private_subnet_names = var.private_subnet_names
  public_subnet_names  = var.public_subnet_names
  database_subnet_names    = var.db_subnet_names
  elasticache_subnet_names = []
  redshift_subnet_names    = []
  intra_subnet_names       = []

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  customer_gateways = {}

  enable_vpn_gateway = false

  enable_dhcp_options              = true
  #dhcp_options_domain_name         = "ec2.internal"

  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  vpc_flow_log_iam_role_name            = "vpc-flow-role"
  vpc_flow_log_iam_role_use_name_prefix = false
  enable_flow_log                       = true
  create_flow_log_cloudwatch_log_group  = true
  create_flow_log_cloudwatch_iam_role   = true
  flow_log_max_aggregation_interval     = 60

  tags = local.tags
}

################################################################################
# VPC Endpoints Module
################################################################################

#module "vpc_endpoints" {
#  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
#
#  vpc_id = module.vpc.vpc_id
#
#  create_security_group      = true
#  security_group_name_prefix = "${local.name}-vpc-endpoints-"
#  security_group_description = "VPC endpoint security group"
#  security_group_rules = {
#    ingress_https = {
#      description = "HTTPS from VPC"
#      cidr_blocks = [module.vpc.vpc_cidr_block]
#    }
#  }
#
#  endpoints = {
#    s3 = {
#      service             = "s3"
#      private_dns_enabled = true
#      dns_options = {
#        private_dns_only_for_inbound_resolver_endpoint = false
#      }
#      tags = { Name = "s3-vpc-endpoint" }
#    },
#    dynamodb = {
#      service         = "dynamodb"
#      service_type    = "Gateway"
#      route_table_ids = flatten([module.vpc.intra_route_table_ids, module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])
#      policy          = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
#      tags            = { Name = "dynamodb-vpc-endpoint" }
#    },
#    ecs = {
#      service             = "ecs"
#      private_dns_enabled = true
#      subnet_ids          = module.vpc.private_subnets
#      subnet_configurations = [
#        for v in module.vpc.private_subnet_objects :
#        {
#          ipv4      = cidrhost(v.cidr_block, 10)
#          subnet_id = v.id
#        }
#      ]
#    },
#    ecs_telemetry = {
#      create              = false
#      service             = "ecs-telemetry"
#      private_dns_enabled = true
#      subnet_ids          = module.vpc.private_subnets
#    },
#    ecr_api = {
#      service             = "ecr.api"
#      private_dns_enabled = true
#      subnet_ids          = module.vpc.private_subnets
#      policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
#    },
#    ecr_dkr = {
#      service             = "ecr.dkr"
#      private_dns_enabled = true
#      subnet_ids          = module.vpc.private_subnets
#      policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
#    },
#    rds = {
#      service             = "rds"
#      private_dns_enabled = true
#      subnet_ids          = module.vpc.private_subnets
#      security_group_ids  = [aws_security_group.rds.id]
#    },
#  }
#
#  tags = merge(local.tags, {
#    Project  = "Secret"
#    Endpoint = "true"
#  })
#}

module "vpc_endpoints_nocreate" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  create = false
}

################################################################################
# Supporting Resources
################################################################################

#data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
#  statement {
#    effect    = "Deny"
#    actions   = ["dynamodb:*"]
#    resources = ["*"]
#
#    principals {
#      type        = "*"
#      identifiers = ["*"]
#    }
#
#    condition {
#      test     = "StringNotEquals"
#      variable = "aws:sourceVpc"
#
#      values = [module.vpc.vpc_id]
#    }
#  }
#}
#
#data "aws_iam_policy_document" "generic_endpoint_policy" {
#  statement {
#    effect    = "Deny"
#    actions   = ["*"]
#    resources = ["*"]
#
#    principals {
#      type        = "*"
#      identifiers = ["*"]
#    }
#
#    condition {
#      test     = "StringNotEquals"
#      variable = "aws:SourceVpc"
#
#      values = [module.vpc.vpc_id]
#    }
#  }
#}
#
#resource "aws_security_group" "rds" {
#  name_prefix = "${local.name}-rds"
#  description = "Allow PostgreSQL inbound traffic"
#  vpc_id      = module.vpc.vpc_id
#
#  ingress {
#    description = "TLS from VPC"
#    from_port   = 5432
#    to_port     = 5432
#    protocol    = "tcp"
#    cidr_blocks = [module.vpc.vpc_cidr_block]
#  }
#
#  tags = local.tags
#}