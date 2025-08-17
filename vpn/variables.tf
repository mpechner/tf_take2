variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "ID of your existing VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs to associate with Client VPN"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block of your VPC"
  type        = string
}

variable "client_cidr_block" {
  description = "CIDR block for Client VPN clients (should not overlap with VPC CIDR)"
  type        = string
}
