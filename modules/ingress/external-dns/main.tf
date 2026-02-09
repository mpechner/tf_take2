terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}

# IMPORTANT: External-DNS requires the following IAM permissions:
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": [
#         "route53:ChangeResourceRecordSets"
#       ],
#       "Resource": [
#         "arn:aws:route53:::hostedzone/*"
#       ]
#     },
#     {
#       "Effect": "Allow",
#       "Action": [
#         "route53:ListHostedZones",
#         "route53:ListResourceRecordSets"
#       ],
#       "Resource": [
#         "*"
#       ]
#     }
#   ]
# }
# Attach this policy to the cluster's node IAM role or use IRSA (IAM Roles for Service Accounts)

resource "helm_release" "external_dns" {
  name             = var.name
  repository       = var.repository
  chart            = var.chart
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  set = var.set

  values = var.values
}


