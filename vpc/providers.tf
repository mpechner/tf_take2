
provider "aws" {
  region = "us-west-2"

}

terraform {
  backend "s3" {
    bucket = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key    = "Network"
    region = "us-east-1"
  }
}