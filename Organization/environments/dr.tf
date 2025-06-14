
module "dr_network" {
  source     = "../modules/network"
  providers  = { aws = aws.dr }

  cidr_block = "10.1.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]
}
