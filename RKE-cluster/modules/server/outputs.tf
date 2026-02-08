# RKE Server Module Outputs
# Note: Security group is managed by the EC2 module, not here

output "iam_role_arn" {
  description = "ARN of the IAM role created for RKE server nodes"
  value       = aws_iam_role.rke_server.arn
}

output "instance_profile_arn" {
  description = "ARN of the instance profile for RKE server nodes"
  value       = aws_iam_instance_profile.rke_server.arn
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = "/opt/rke/kube_config_cluster.yml"
}

output "cluster_token" {
  description = "Token for joining nodes to the cluster"
  value       = "Use 'rke up --config cluster.yml' to generate the token"
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.rke_oidc[0].arn : null
}

output "oidc_provider_id" {
  description = "ID of the OIDC provider"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.rke_oidc[0].id : null
}

output "cluster_admin_service_account_role_arn" {
  description = "ARN of the cluster admin service account role"
  value       = var.enable_irsa ? aws_iam_role.cluster_admin_service_account[0].arn : null
}

output "monitoring_service_account_role_arn" {
  description = "ARN of the monitoring service account role"
  value       = var.enable_irsa ? aws_iam_role.monitoring_service_account[0].arn : null
} 