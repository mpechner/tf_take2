variable "aws_region" {
  default = "us-west-2"
}

variable "route53_hosted_zone_ids" {
  type        = list(string)
  description = "Route53 hosted zone IDs the node role may modify. Typically the cluster domain zone + the VPN domain zone."
  default     = ["Z06437531SIUA7T3WCKTM"]
}

variable "dockerhub_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret containing Docker Hub credentials. Passed to EC2 module so nodes can read it."
  default     = ""
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window in days. Use 0 for dev (immediate deletion on destroy), 30 for production."
  type        = number
  default     = 0
}
