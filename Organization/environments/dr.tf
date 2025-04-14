
module "dr_network" {
  source     = "../modules/network"
  providers  = { aws = aws.dr }

  cidr_block = "10.1.0.0/16"
  azs        = ["us-east-2a", "us-east-2b"]
}
