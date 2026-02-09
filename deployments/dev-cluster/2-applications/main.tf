# Stage 2: Applications - Kubernetes Manifests and Workloads
#
# This stage deploys application-level resources that depend on CRDs
# installed in Stage 1.
#
# IMPORTANT: You MUST deploy Stage 1 first!
#
# Deployed components:
#   - ClusterIssuer: Let's Encrypt certificate issuer
#   - Backend TLS: Internal service certificates
#   - Traefik Dashboard: IngressRoute with authentication
#   - Rancher: Kubernetes management UI
#   - Nginx Sample: Demo application with TLS

# Create namespaces
resource "kubernetes_namespace_v1" "nginx_sample" {
  metadata {
    name = "nginx-sample"
    labels = {
      app         = "nginx-sample"
      environment = var.environment
    }
  }
}

resource "kubernetes_namespace_v1" "cattle_system" {
  metadata {
    name = "cattle-system"
    labels = {
      app = "rancher"
    }
  }
}

# Traefik Dashboard Certificate
resource "kubernetes_manifest" "traefik_dashboard_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "traefik-dashboard-tls"
      namespace = "traefik"
    }
    spec = {
      secretName = "traefik-dashboard-tls"
      dnsNames = [
        "traefik.${var.route53_domain}"
      ]
      issuerRef = {
        name  = "letsencrypt-${var.letsencrypt_environment}"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }

  depends_on = [module.applications]
}

# Traefik Dashboard IngressRoute
resource "kubernetes_manifest" "traefik_dashboard_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "traefik-dashboard"
      namespace = "traefik"
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
              kind = "TraefikService"
            }
          ]
        }
      ]
      tls = {
        secretName = "traefik-dashboard-tls"
      }
    }
  }

  depends_on = [kubernetes_manifest.traefik_dashboard_cert]
}

# Rancher Helm Chart
resource "helm_release" "rancher" {
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/latest"
  chart            = "rancher"
  namespace        = kubernetes_namespace_v1.cattle_system.metadata[0].name
  create_namespace = false

  set = [
    {
      name  = "hostname"
      value = "rancher.${var.route53_domain}"
    },
    {
      name  = "bootstrapPassword"
      value = "admin"
    },
    {
      name  = "ingress.enabled"
      value = "false"
    },
    {
      name  = "tls"
      value = "ingress"
    },
    {
      name  = "replicas"
      value = "1"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.cattle_system,
    module.applications
  ]
}

# Rancher Certificate
resource "kubernetes_manifest" "rancher_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "rancher-tls"
      namespace = kubernetes_namespace_v1.cattle_system.metadata[0].name
    }
    spec = {
      secretName = "rancher-tls"
      dnsNames = [
        "rancher.${var.route53_domain}"
      ]
      issuerRef = {
        name  = "letsencrypt-${var.letsencrypt_environment}"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }

  depends_on = [
    helm_release.rancher,
    module.applications
  ]
}

# Rancher IngressRoute
resource "kubernetes_manifest" "rancher_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "rancher"
      namespace = kubernetes_namespace_v1.cattle_system.metadata[0].name
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`rancher.${var.route53_domain}`)"
          kind  = "Rule"
          services = [
            {
              name = "rancher"
              port = 80
            }
          ]
        }
      ]
      tls = {
        secretName = "rancher-tls"
      }
    }
  }

  depends_on = [
    helm_release.rancher,
    kubernetes_manifest.rancher_cert
  ]
}

# Applications module - Creates certificates and ingresses
module "applications" {
  source = "./modules/ingress-applications"

  route53_domain          = var.route53_domain
  letsencrypt_environment = var.letsencrypt_environment
  traefik_namespace       = "traefik"

  # Managed ingresses (including nginx-sample)
  ingresses = {
    nginx-sample = {
      namespace           = "nginx-sample"
      host                = "nginx.${var.route53_domain}"
      service_name        = "nginx-sample"
      service_port        = 443
      cluster_issuer      = "letsencrypt-${var.letsencrypt_environment}"
      backend_tls_enabled = true
    }
  }

  depends_on = [kubernetes_namespace_v1.nginx_sample]
}

# Nginx sample site - Deploy after certificates are ready
module "nginx_sample" {
  source = "../modules/nginx-sample"

  namespace        = kubernetes_namespace_v1.nginx_sample.metadata[0].name
  create_namespace = false  # Namespace already created above
  environment      = var.environment
  domain           = var.route53_domain
  hostname         = "nginx.${var.route53_domain}"

  depends_on = [module.applications]
}
