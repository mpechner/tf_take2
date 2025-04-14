terraform {
  backend "s3" {
    bucket = "mikey-com-terraformstate"
    dynamodb_table = "terraform-state"
    key    = "s3backing"
    region = "us-east-1"
  }
}