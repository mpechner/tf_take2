variable "backingbucket" {
  description = "name of backing bucket"
  default = "mikey-com-terraformstate"
}
variable "backingdb" {
  description = "name of backing db"
  default = "terraform-state"
}

variable "region" {
  default = "us-east-1"
}
variable "profile" {
  default = "default"
}

# If set, assume this role (terraform-execute from TF_org-user) instead of using profile
variable "assume_role_arn" {
  description = "Optional IAM role ARN to assume (e.g. arn:aws:iam::ACCOUNT:role/terraform-execute). When set, profile is ignored."
  type        = string
  default     = ""
}