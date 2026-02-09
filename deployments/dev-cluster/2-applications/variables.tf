variable "account_id" {
  type    = string
  default = "364082771643"
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_assume_role_arn" {
  type    = string
  default = "arn:aws:iam::364082771643:role/terraform-execute"
}

variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "route53_domain" {
  type        = string
  description = "Route53 hosted zone domain name"
}

variable "letsencrypt_environment" {
  type        = string
  default     = "staging"
  description = "prod or staging"
}
