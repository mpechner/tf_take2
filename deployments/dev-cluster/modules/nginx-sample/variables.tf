# Nginx sample site module variables

variable "namespace" {
  type        = string
  default     = "nginx-sample"
  description = "Kubernetes namespace for the nginx deployment"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Whether to create the namespace"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name (displayed on the sample page)"
}

variable "domain" {
  type        = string
  description = "Domain name for the sample site (e.g., dev.foobar.support)"
}

variable "hostname" {
  type        = string
  description = "Full hostname for the ingress (e.g., www.dev.foobar.support)"
}

variable "replicas" {
  type        = number
  default     = 2
  description = "Number of nginx replicas"
}

variable "cluster_issuer" {
  type        = string
  default     = null
  description = "Cert-manager ClusterIssuer name for TLS (e.g., letsencrypt-staging)"
}

variable "ingress_class_name" {
  type        = string
  default     = "traefik"
  description = "Ingress class name"
}

variable "ingress_annotations" {
  type        = map(string)
  default     = {}
  description = "Additional annotations for the ingress"
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Additional labels for all resources"
}
