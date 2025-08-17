# AWS Client VPN
# This creates a Client VPN endpoint for secure access to your VPC

# Client VPN Endpoint
resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "${var.environment}-client-vpn"
  server_certificate_arn = aws_acm_certificate.server.arn
  client_cidr_block     = var.client_cidr_block
  vpc_id                = var.vpc_id
  security_group_ids    = [aws_security_group.client_vpn.id]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.root.arn
  }

  connection_log_options {
    enabled = false
  }

  tags = {
    Name        = "${var.environment}-client-vpn"
    Environment = var.environment
  }
}

# Client VPN Network Association - Associate with your existing VPC subnets
resource "aws_ec2_client_vpn_network_association" "main" {
  count                  = length(var.subnet_ids)
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = var.subnet_ids[count.index]
}

# Authorization Rule - Allow access to your VPC
resource "aws_ec2_client_vpn_authorization_rule" "main" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true
}

# ACM Certificate for Server
resource "aws_acm_certificate" "server" {
  private_key      = file("~/.aws-vpn/server.key")
  certificate_body = file("~/.aws-vpn/server.crt")

  tags = {
    Name        = "${var.environment}-server-cert"
    Environment = var.environment
  }
}

# ACM Certificate for Root CA
resource "aws_acm_certificate" "root" {
  private_key      = file("~/.aws-vpn/ca.key")
  certificate_body = file("~/.aws-vpn/ca.crt")

  tags = {
    Name        = "${var.environment}-root-cert"
    Environment = var.environment
  }
}

# Security Group for Client VPN
resource "aws_security_group" "client_vpn" {
  name        = "${var.environment}-client-vpn-sg"
  description = "Security group for Client VPN access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.client_cidr_block]
    description = "Allow all traffic from Client VPN clients"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-client-vpn-sg"
    Environment = var.environment
  }
}
