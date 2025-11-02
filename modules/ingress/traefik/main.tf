terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}

resource "helm_release" "traefik" {
  name             = var.name
  repository       = var.repository
  chart            = var.chart
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  # Common default to expose Traefik
  set {
    name  = "service.type"
    value = var.service_type
  }

  # Enable Dashboard and API
  set {
    name  = "dashboard.enabled"
    value = "true"
  }

  set {
    name  = "api.dashboard"
    value = "true"
  }

  set {
    name  = "api.insecure"
    value = "true"
  }

  # Expose ports
  set {
    name  = "ports.web.expose"
    value = "true"
  }

  set {
    name  = "ports.websecure.expose"
    value = "true"
  }

  dynamic "set" {
    for_each = var.set
    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  values = var.values
}


