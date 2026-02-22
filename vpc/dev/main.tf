module "dev" {
  source = "../modules/vpc"
  region = var.region
  name   = var.name
  vpc_cidr = var.vpc_cidr
  azs    = var.azs
  private_subnets     = var.private_subnets
  private_subnet_names = var.private_subnet_names
  public_subnets      = var.public_subnets
  public_subnet_names = var.public_subnet_names
  db_subnets          = var.db_subnets
  db_subnet_names     = var.db_subnet_names

  enable_nat_gateway  = var.enable_nat_gateway
  single_nat_gateway  = var.single_nat_gateway

  # VPC endpoints for Lambda/private workloads (no NAT). Set enable_vpc_endpoints = true and pass Lambda SG id(s).
  enable_vpc_endpoints   = var.enable_vpc_endpoints
  endpoint_subnet_ids    = var.endpoint_subnet_ids
  private_route_table_ids = var.private_route_table_ids
  allowed_source_sg_ids  = var.allowed_source_sg_ids
  tags                   = var.tags
  vpc_endpoint_services_interface = var.vpc_endpoint_services_interface
  vpc_endpoint_services_gateway   = var.vpc_endpoint_services_gateway
}