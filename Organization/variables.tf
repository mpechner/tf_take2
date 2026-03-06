# Organization Terraform must run in the management account. Use terraform-execute there (created by TF_org-user).
variable "management_account_id" {
  description = "AWS account ID of the organization management account (where your IAM user lives). terraform-execute in this account is used for both default and DR providers."
  type        = string
  # No default — must be set in terraform.tfvars. See terraform.tfvars.example.
}

variable "aws_assume_role_arn" {
  description = "IAM role ARN for default and primary AWS provider. Derived from management_account_id if unset."
  type        = string
  default     = null
}

variable "dr_assume_role_arn" {
  description = "IAM role ARN for DR AWS provider. Derived from management_account_id if unset."
  type        = string
  default     = null
}
