
provider "aws" {
  alias  = "primary"
  region = "us-west-1"
}

provider "aws" {
  alias  = "dr"
  region = "us-east-2"
}
