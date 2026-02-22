# Roles created by TF_org-user; use terraform-execute in the account where Organization is run (typically mgmt)
variable "aws_assume_role_arn" {
  description = "IAM role ARN for default AWS provider (terraform-execute in mgmt account)"
  type        = string
  default     = "arn:aws:iam::111416589270:role/terraform-execute"
}

variable "dr_assume_role_arn" {
  description = "IAM role ARN for DR AWS provider (terraform-execute in DR/mgmt account)"
  type        = string
  default     = "arn:aws:iam::111416589270:role/terraform-execute"
}
