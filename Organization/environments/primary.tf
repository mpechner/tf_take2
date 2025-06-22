
module "primary_network" {
  source     = "../modules/network"
  providers  = { aws = aws.primary }

  cidr_block = "10.0.0.0/16"
  azs        = ["us-west-2a", "us-west-2b"]
}
