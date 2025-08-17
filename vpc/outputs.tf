output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.dev-vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.dev-vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.dev-vpc.public_subnets
}

output "private_subnets_cidr_blocks" {
  description = "List of CIDR blocks of private subnets"
  value       = module.dev-vpc.private_subnets_cidr_blocks
}

output "public_subnets_cidr_blocks" {
  description = "List of CIDR blocks of public subnets"
  value       = module.dev-vpc.public_subnets_cidr_blocks
}

