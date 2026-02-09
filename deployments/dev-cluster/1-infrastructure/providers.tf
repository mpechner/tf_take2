provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = var.aws_assume_role_arn
  }

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Stage       = "1-infrastructure"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

# Data sources to get VPC subnet IDs
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["*pub*"]  # Changed from *public* to *pub*
  }

  filter {
    name   = "cidr-block"
    values = ["10.8.0.0/24", "10.8.64.0/24", "10.8.128.0/24"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["*priv*"]  # Use wildcard on both sides
  }
}
