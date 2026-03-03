variable "account_id" {
  type        = string
  description = "AWS account ID"
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
  type        = string
  description = "IAM role ARN for Terraform to assume"
}
