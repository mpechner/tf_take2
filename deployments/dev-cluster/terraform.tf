terraform {
  required_version = ">= 1.3"

  backend "s3" {
    bucket         = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key            = "ingress_dev/ingress"
    region         = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}
