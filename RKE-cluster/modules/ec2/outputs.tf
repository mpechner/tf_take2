# EC2 Module Outputs

output "server_instance_ids" {
  description = "List of server instance IDs"
  value       = [for instance in aws_instance.server_rke_nodes : instance.id]
}

output "agent_instance_ids" {
  description = "List of agent instance IDs"
  value       = [for instance in aws_instance.agent_rke_nodes : instance.id]
}

output "server_instance_ips" {
  description = "List of server instance public IPs"
  value       = [for instance in aws_instance.server_rke_nodes : instance.public_ip]
}

output "agent_instance_ips" {
  description = "List of agent instance public IPs"
  value       = [for instance in aws_instance.agent_rke_nodes : instance.public_ip]
}

output "server_instance_private_ips" {
  description = "List of server instance private IPs"
  value       = [for instance in aws_instance.server_rke_nodes : instance.private_ip]
}

output "agent_instance_private_ips" {
  description = "List of agent instance private IPs"
  value       = [for instance in aws_instance.agent_rke_nodes : instance.private_ip]
}
