variable "aws_region" {
  default = "us-west-2"
}

# EC2 remote state (used by data.terraform_remote_state.ec2; set to your state bucket if different)
variable "ec2_state_bucket" {
  description = "S3 bucket containing the RKE EC2 Terraform state"
  type        = string
  default     = "mikey-com-terraformstate"
}

variable "ec2_state_key" {
  description = "S3 object key for the RKE EC2 state"
  type        = string
  default     = "RKE-cluster_dev/ec2"
}

variable "ec2_state_region" {
  description = "AWS region where the EC2 state bucket lives"
  type        = string
  default     = "us-east-1"
}
variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window in days. Use 0 for dev (immediate deletion on destroy), 30 for production."
  type        = number
  default     = 0
}

variable "dockerhub_secret_arn" {
  description = "ARN of Secrets Manager secret containing Docker Hub credentials ({\"user\":\"...\",\"token\":\"...\"}). Leave empty to skip Docker Hub auth."
  type        = string
  default     = ""
}

variable "registry_mirror" {
  description = "Optional alternate registry mirror URL (e.g. ECR pull-through cache endpoint). When set, all docker.io pulls are redirected through this registry."
  type        = string
  default     = ""
}
