variable "mgmt_account_id" {
  description = "AWS account ID for the management/org account (where mpechner IAM user lives). This account is trusted to assume terraform-execute in all target accounts."
  type        = string
}

variable "dev_account_id" {
  description = "AWS account ID for the dev account."
  type        = string
}

variable "mgmt_org_account_id" {
  description = "AWS account ID for the mgmt org account."
  type        = string
}

variable "network_account_id" {
  description = "AWS account ID for the network account."
  type        = string
}

variable "prod_account_id" {
  description = "AWS account ID for the prod account."
  type        = string
}
