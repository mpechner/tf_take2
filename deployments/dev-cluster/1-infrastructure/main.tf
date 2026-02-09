# Stage 1: Infrastructure - Helm Charts and Load Balancers
#
# This stage deploys the foundational infrastructure that installs
# Custom Resource Definitions (CRDs) needed by Stage 2.
#
# Deployed components:
#   - cert-manager: Certificate management and Let's Encrypt integration
#   - external-dns: Automatic Route53 DNS record management
#   - Traefik: Ingress controller with public and internal load balancers

# Deploy cert-manager
module "cert_manager" {
  source = "../../../modules/ingress/cert-manager"

  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  chart_version    = "v1.15.3"
  install_crds     = true
  set              = []
  values           = []
}

# Deploy external-dns in its own namespace
module "external_dns" {
  source = "../../../modules/ingress/external-dns"

  name             = "external-dns"
  namespace        = "external-dns"
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  chart_version    = "1.15.0"
  set = [
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
  ]
  values = []
}

# Deploy Traefik ingress controller in its own namespace
module "traefik" {
  source = "../../../modules/ingress/traefik"

  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  chart_version    = "24.0.0"
  service_type     = "LoadBalancer"
  set = [
    {
      name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
      type  = "string"
    },
    {
      name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
      value = "internet-facing"
      type  = "string"
    }
  ]
  values = [yamlencode({
    service = {
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-subnets" = join(",", data.aws_subnets.public.ids)
      }
      spec = {
        loadBalancerClass = "service.k8s.aws/nlb"
      }
    }
  })]
}

# Additional internal service for Traefik dashboard and RKE server access
resource "kubernetes_service_v1" "traefik_internal" {
  metadata {
    name      = "traefik-internal"
    namespace = "traefik"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"                = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-internal"            = "true"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"              = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-subnets"             = join(",", data.aws_subnets.private.ids)
      "external-dns.alpha.kubernetes.io/hostname"                        = "traefik.${var.route53_domain},rke.${var.route53_domain}"
    }
  }

  spec {
    type                = "LoadBalancer"
    load_balancer_class = "service.k8s.aws/nlb"
    selector = {
      "app.kubernetes.io/name"     = "traefik"
      "app.kubernetes.io/instance" = "traefik"
    }
    port {
      name        = "web"
      port        = 80
      target_port = "web"
      protocol    = "TCP"
    }
    port {
      name        = "websecure"
      port        = 443
      target_port = "websecure"
      protocol    = "TCP"
    }
  }

  depends_on = [module.traefik]
}
