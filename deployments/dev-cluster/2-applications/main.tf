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
#   - Nginx Sample: Demo application with TLS

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
}

# Nginx sample site
module "nginx_sample" {
  source = "../../modules/nginx-sample"

  namespace   = "nginx-sample"
  environment = var.environment
  domain      = var.route53_domain
  hostname    = "nginx.${var.route53_domain}"

  depends_on = [module.applications]
}
