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
