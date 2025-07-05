terraform {
  required_version = ">= 1.3"
  
  backend "s3" {
    bucket = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key    = "route53-delegate"
    region = "us-east-1"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
    dev_account     = "364082771643"
    network_account = "061154959995"
}

provider "aws" {
  alias  = "network"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${local.network_account}:role/terraform-execute"
  }
}

provider "aws" {
  alias  = "dev"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${local.dev_account}:role/terraform-execute"
  }
}

# 1. Create the delegated hosted zone in dev account
resource "aws_route53_zone" "dev_subdomain" {
  provider = aws.dev
  name     = "dev.foobar.support"
  comment  = "Delegated subdomain hosted zone in dev account"
}

# 2. Data source to get the parent zone in network account
data "aws_route53_zone" "parent" {
  provider = aws.network
  name     = "foobar.support."
  private_zone = false
}

# 3. Create NS record set in the parent zone (network account) delegating to dev hosted zone's NS records
resource "aws_route53_record" "delegation_ns" {
  provider = aws.network
  zone_id  = data.aws_route53_zone.parent.zone_id
  name     = "dev.foobar.support"
  type     = "NS"
  ttl      = 300
  records  = aws_route53_zone.dev_subdomain.name_servers
}
