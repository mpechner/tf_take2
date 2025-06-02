variable "backingbucket" {
  description = "name of backing bucket"
  default = "mikey-com-terraformstate"
}
variable "backingdb" {
  description = "name of backing db"
  default = "terraform-state"
}

variable "region" {
  default = "us-east-1"
}
variable "profile" {
  default = "default"
}