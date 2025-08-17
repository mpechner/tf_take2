output "client_vpn_endpoint_id" {
  description = "ID of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.id
}

output "client_vpn_endpoint_dns" {
  description = "DNS name of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.dns_name
}

output "client_vpn_endpoint_arn" {
  description = "ARN of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.arn
}

output "security_group_id" {
  description = "ID of the security group for Client VPN access"
  value       = aws_security_group.client_vpn.id
}
