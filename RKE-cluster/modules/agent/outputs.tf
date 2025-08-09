# RKE Agent Module Outputs

output "security_group_id" {
  description = "ID of the security group created for RKE agent nodes"
  value       = aws_security_group.rke_agent.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role created for RKE agent nodes"
  value       = aws_iam_role.rke_agent.arn
}

output "launch_template_id" {
  description = "ID of the launch template created for RKE agent nodes"
  value       = aws_launch_template.rke_agent.id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group for RKE agent nodes"
  value       = aws_autoscaling_group.rke_agent.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group for RKE agent nodes"
  value       = aws_autoscaling_group.rke_agent.arn
}

output "instance_profile_arn" {
  description = "ARN of the instance profile for RKE agent nodes"
  value       = aws_iam_instance_profile.rke_agent.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.rke_oidc[0].arn : null
}

output "default_service_account_role_arn" {
  description = "ARN of the default service account role"
  value       = var.enable_irsa ? aws_iam_role.default_service_account[0].arn : null
}

output "app_service_account_role_arn" {
  description = "ARN of the application service account role"
  value       = var.enable_irsa ? aws_iam_role.app_service_account[0].arn : null
} 