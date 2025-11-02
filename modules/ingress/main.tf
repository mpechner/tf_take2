terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}

module "traefik" {
  count = var.traefik_enabled ? 1 : 0
  source = "./traefik"

  name             = var.traefik_name
  namespace        = var.traefik_namespace
  create_namespace = var.traefik_create_namespace
  repository       = var.traefik_repository
  chart            = var.traefik_chart
  chart_version    = var.traefik_chart_version
  service_type     = var.traefik_service_type
  set              = var.traefik_set
  values           = var.traefik_values
}

module "external_dns" {
  count = var.external_dns_enabled ? 1 : 0
  source = "./external-dns"

  name             = var.external_dns_name
  namespace        = var.external_dns_namespace
  create_namespace = var.external_dns_create_namespace
  repository       = var.external_dns_repository
  chart            = var.external_dns_chart
  chart_version    = var.external_dns_chart_version
  set = concat(var.external_dns_set, [
    {
      name  = "provider"
      value = "aws"
      type  = "string"
    },
    {
      name  = "aws.region"
      value = var.aws_region
      type  = "string"
    },
    {
      name  = "aws.zoneType"
      value = "public"
      type  = "string"
    },
    {
      name  = "policy"
      value = "upsert-only"
      type  = "string"
    },
    {
      name  = "registry"
      value = "txt"
      type  = "string"
    },
    {
      name  = "txt-owner-id"
      value = "external-dns"
      type  = "string"
    }
  ])
  values           = var.external_dns_values
}

module "cert_manager" {
  count = var.cert_manager_enabled ? 1 : 0
  source = "./cert-manager"

  name             = var.cert_manager_name
  namespace        = var.cert_manager_namespace
  create_namespace = var.cert_manager_create_namespace
  repository       = var.cert_manager_repository
  chart            = var.cert_manager_chart
  chart_version    = var.cert_manager_chart_version
  install_crds     = var.cert_manager_install_crds
  set              = var.cert_manager_set
  values           = var.cert_manager_values
}

# Create ClusterIssuer for Let's Encrypt
resource "kubernetes_manifest" "letsencrypt_issuer" {
  count = var.cert_manager_enabled ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-${var.letsencrypt_environment}"
    }
    spec = {
      acme = {
        server = var.letsencrypt_environment == "staging" ? 
          "https://acme-staging-v02.api.letsencrypt.org/directory" : 
          "https://acme-v02.api.letsencrypt.org/directory"
        email = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-${var.letsencrypt_environment}"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region = var.aws_region
              }
            }
            selector = {
              dnsNames = []
            }
          }
        ]
      }
    }
  }

  depends_on = [module.cert_manager]
}

# Enable Traefik Dashboard
resource "kubernetes_manifest" "traefik_dashboard_middleware" {
  count = var.traefik_enabled ? 1 : 0

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "traefik-auth"
      namespace = var.traefik_namespace
    }
    spec = {
      basicAuth = {
        secret = "traefik-auth-secret"
      }
    }
  }

  depends_on = [module.traefik]
}

# Example IngressRoute for Traefik Dashboard
resource "kubernetes_manifest" "traefik_dashboard_ingressroute" {
  count = var.traefik_enabled ? 1 : 0

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "traefik-dashboard"
      namespace = var.traefik_namespace
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`traefik.${var.route53_domain}`)"
          kind  = "Rule"
          services = [
            {
              name = "api@internal"
              port = 8000
            }
          ]
        }
      ]
      tls = {
        certResolver = "letsencrypt"
      }
    }
  }

  depends_on = [module.traefik]
}


