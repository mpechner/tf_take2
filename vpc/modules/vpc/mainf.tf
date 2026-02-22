
data "aws_availability_zones" "available" {}

locals {
  name   = var.name
  region = var.region

  vpc_cidr = var.vpc_cidr
  azs      = var.azs

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

  # Disable auto-assign public IP on private subnets
  map_public_ip_on_launch = false

  private_subnet_names = var.private_subnet_names
  public_subnet_names  = var.public_subnet_names
  database_subnet_names    = var.db_subnet_names
  elasticache_subnet_names = []
  redshift_subnet_names    = []
  intra_subnet_names       = []

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  # Required for AWS Load Balancer Controller (NLB) subnet discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

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

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])
      tags            = { Name = "${local.name}-s3-gateway-endpoint" }
    }
  }

  tags = merge(local.tags, {
    Endpoint = "true"
  })
}

# Placeholder module (keeping for compatibility)
module "vpc_endpoints_nocreate" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  create = false
}

################################################################################
# VPC Endpoints for Lambda / private workloads (no NAT)
# Enabled when enable_vpc_endpoints = true. S3 gateway already above.
################################################################################

locals {
  # Interface endpoints allow only one subnet per AZ. Default: one private subnet per AZ (VPC module orders subnets by AZ).
  endpoint_subnet_ids          = length(var.endpoint_subnet_ids) > 0 ? var.endpoint_subnet_ids : slice(module.vpc.private_subnets, 0, min(length(module.vpc.private_subnets), length(var.azs)))
  endpoint_private_route_ids   = length(var.private_route_table_ids) > 0 ? var.private_route_table_ids : module.vpc.private_route_table_ids
  endpoint_tags                = merge(local.tags, var.tags, { Endpoint = "true" })
  # Gateway endpoints to create: only those in var list that are not s3 (S3 already exists)
  endpoint_gateway_services    = [for s in var.vpc_endpoint_services_gateway : s if s != "s3"]
}

# Security group for interface endpoints. Inbound 443 from Lambda SG(s) or private subnet CIDRs.
resource "aws_security_group" "vpc_endpoints_interface" {
  count       = var.enable_vpc_endpoints ? 1 : 0
  name_prefix = "${local.name}-vpc-endpoints-"
  description = "Allow HTTPS from Lambda (or private subnets) to VPC interface endpoints"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_source_sg_ids) > 0 ? [1] : []
    content {
      description     = "HTTPS from allowed security groups (e.g. Lambda)"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      security_groups = var.allowed_source_sg_ids
    }
  }
  dynamic "ingress" {
    for_each = length(var.allowed_source_sg_ids) == 0 ? [1] : []
    content {
      description = "HTTPS from private subnets (fallback when no allowed_source_sg_ids)"
      from_port    = 443
      to_port      = 443
      protocol     = "tcp"
      cidr_blocks  = module.vpc.private_subnets_cidr_blocks
    }
  }

  egress {
    description = "Allow all outbound; endpoints need to reach AWS and VPC DNS."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.endpoint_tags, { Name = "${local.name}-vpc-endpoints-sg" })
}

# Interface endpoints (PrivateLink): ECR, Secrets Manager, KMS, Logs, SSM trio, STS.
# One per AZ in endpoint_subnet_ids; Private DNS enabled so SDK resolves to endpoint IPs.
resource "aws_vpc_endpoint" "interface" {
  for_each            = var.enable_vpc_endpoints ? toset(var.vpc_endpoint_services_interface) : toset([])
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints_interface[0].id]
  private_dns_enabled = true

  tags = merge(local.endpoint_tags, { Name = "${local.name}-${each.key}" })
}

# Gateway endpoints: DynamoDB (S3 already exists in module.vpc_endpoints).
resource "aws_vpc_endpoint" "gateway" {
  for_each          = var.enable_vpc_endpoints ? toset(local.endpoint_gateway_services) : toset([])
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.endpoint_private_route_ids

  tags = merge(local.endpoint_tags, { Name = "${local.name}-${each.key}-gateway" })
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