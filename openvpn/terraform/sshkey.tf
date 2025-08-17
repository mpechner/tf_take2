resource "tls_private_key" "openvpn_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_secretsmanager_secret" "openvpn_ssh_keypair" {
  name = "openvpn-ssh"
  recovery_window_in_days = 0  # Delete immediately on destroy
  force_overwrite_replica_secret = true
}

resource "aws_secretsmanager_secret_version" "openvpn_ssh_keypair_version" {
  secret_id = aws_secretsmanager_secret.openvpn_ssh_keypair.id
  secret_string = jsonencode({
    private_key = tls_private_key.openvpn_ssh.private_key_pem
    public_key  = tls_private_key.openvpn_ssh.public_key_openssh
  })
}

resource "aws_key_pair" "openvpn_ssh" {
  key_name   = "openvpn-ssh-keypair"
  public_key = tls_private_key.openvpn_ssh.public_key_openssh
}