# OpenVPN Terraform Variables

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "ami_id" {
  description = "AMI ID for OpenVPN Access Server"
  type        = string
  default     = "ami-0e64010cd8a5abec7"
}

variable "account_id" {
  description = "AWS account ID to assume into for deploying OpenVPN"
  type        = string
  default     = "364082771643"
}

variable "subnet_id" {
  description = "Subnet ID where the OpenVPN server will be deployed. If set, use this (and set vpc_id when deploying in a different account than VPC state)."
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID for the security group. Set when deploying in a different account than the VPC remote state (so the state's vpc_id does not exist in this account)."
  type        = string
  default     = ""
}


variable "ssh_username" {
  description = "SSH username for the OpenVPN Access Server AMI (commonly 'openvpnas' or 'ubuntu')"
  type        = string
  default     = "openvpnas"
}

variable "instance_type" {
  description = "EC2 instance type for OpenVPN server"
  type        = string
  default     = "t3.small"  # Recommended for OpenVPN Access Server
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "comcast_ip" {
  description = "Your public IP address for restricted access (CIDR format). Leave empty to auto-detect your current IP."
  type        = string
  default     = ""  # Empty = auto-detect, or specify like "1.2.3.4/32"
}

# VPC remote state (used to read subnet/VPC IDs; set to your own state bucket if different)
variable "vpc_state_bucket" {
  description = "S3 bucket containing the VPC Terraform state (used by data.terraform_remote_state.vpc)"
  type        = string
  default     = "mikey-com-terraformstate"
}

variable "vpc_state_key" {
  description = "S3 object key for the VPC Terraform state (e.g. Network, vpc/terraform.tfstate)"
  type        = string
  default     = "Network"
}

variable "vpc_state_region" {
  description = "AWS region where the VPC state bucket lives"
  type        = string
  default     = "us-east-1"
}

