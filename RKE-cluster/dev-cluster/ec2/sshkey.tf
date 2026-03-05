# SSH key pair for RKE nodes — key is generated externally by scripts/create-rke-ssh-key.sh
# and stored in Secrets Manager before terraform apply is run.
# Terraform reads the public key from the secret and registers it as an EC2 key pair.
# The private key never enters Terraform state.
# The secret must already exist (with a value) before running terraform apply.

data "aws_secretsmanager_secret_version" "rke_ssh_keypair" {
  secret_id = "rke-ssh"
}

resource "aws_key_pair" "rke_ssh" {
  key_name   = "rke-ssh-keypair"
  public_key = jsondecode(data.aws_secretsmanager_secret_version.rke_ssh_keypair.secret_string)["public_key"]
}
