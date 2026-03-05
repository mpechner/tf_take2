
variable "ansible_repo" {
  type    = string
  default = "https://github.com/your-org/your-ansible-repo.git"
}

variable "ansible_playbook" {
  type    = string
  default = "playbook.yml"
}

variable "ec2_ssh_key" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "subnet id names"
}

variable "agent_hostnames" {
  type = list(string)
}
variable "agent_ami" {
  type = string
}

variable "agent_instance_type" {
  type = string
}

variable "server_hostnames" {
  type = list(string)
}
variable "server_ami" {
  type = string
}

variable "server_instance_type" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for security group"
  default     = ""
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR to allow inbound access"
  default     = ""
}

variable "instance_profile_name" {
  type        = string
  description = "Existing IAM instance profile name to attach to instances. If empty, a new one is created."
  default     = ""
}

variable "create_ecr_pull_policy" {
  type        = bool
  description = "When creating a role, also attach a minimal ECR pull inline policy"
  default     = true
}

variable "route53_hosted_zone_ids" {
  type        = list(string)
  description = "Route53 hosted zone IDs the node role may modify (cert-manager DNS-01 + external-dns). ChangeResourceRecordSets is scoped to these zones only. Must not be empty."
  default     = []

  validation {
    condition     = length(var.route53_hosted_zone_ids) > 0
    error_message = "route53_hosted_zone_ids must contain at least one hosted zone ID. ChangeResourceRecordSets will not be scoped to '*'."
  }
}

variable "openvpn_secret_prefix" {
  type        = string
  description = "Secrets Manager path prefix for the OpenVPN cert publisher (e.g. 'openvpn/'). PutSecretValue/CreateSecret are scoped to this prefix."
  default     = "openvpn/"
}

variable "rke_ssh_secret_name" {
  type        = string
  description = "Secrets Manager secret name for the RKE SSH keypair (e.g. 'rke-ssh')."
  default     = "rke-ssh"
}

variable "rke2_token_secret_name" {
  type        = string
  description = "Secrets Manager secret name for the RKE2 cluster join token (e.g. 'dev-rke2-token')."
  default     = "dev-rke2-token"
}

variable "aws_region" {
  type        = string
  description = "AWS region (used to scope the Secrets Manager ARN)."
  default     = "us-west-2"
}

variable "dockerhub_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret containing Docker Hub credentials. If non-empty, nodes are granted GetSecretValue on this secret."
  default     = ""
}

variable "ebs_encrypted" {
  type        = bool
  description = "Encrypt root EBS volumes on all RKE nodes. Defaults to true. Set false only for AMIs that do not support encryption."
  default     = true
}

variable "ebs_kms_key_id" {
  type        = string
  description = "KMS key ARN or ID to use for EBS volume encryption. Leave empty to use the AWS-managed key (aws/ebs). Only used when ebs_encrypted = true."
  default     = ""
}