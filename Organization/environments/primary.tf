
module "primary_network" {
  source     = "../modules/network"
  providers  = { aws = aws.primary }

  cidr_block = "10.0.0.0/16"
  azs        = ["us-west-1a", "us-west-1b"]
}
