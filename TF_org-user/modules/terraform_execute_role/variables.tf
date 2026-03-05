variable "principal_account_id" {
  description = "AWS account ID trusted to assume the terraform-execute role (the account where the Terraform operator's IAM user lives)."
  type        = string
}
