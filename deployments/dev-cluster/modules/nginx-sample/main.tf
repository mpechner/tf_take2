# Nginx sample site module
# Deploys nginx with a sample landing page and creates an ingress

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
  }
}

locals {
  app_name = "nginx-sample"
  labels = merge({
    app         = local.app_name
    environment = var.environment
  }, var.labels)
}

resource "kubernetes_namespace" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name   = var.namespace
    labels = local.labels
  }
}

locals {
  namespace = var.create_namespace ? kubernetes_namespace.this[0].metadata[0].name : var.namespace
}

resource "kubernetes_config_map" "html" {
  metadata {
    name      = "${local.app_name}-html"
    namespace = local.namespace
    labels    = local.labels
  }

  data = {
    "index.html" = templatefile("${path.module}/site/index.html.tftpl", {
      domain      = var.domain
      hostname    = var.hostname
      environment = var.environment
      namespace   = var.namespace
      tls_enabled = var.cluster_issuer != null
    })
  }
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = local.app_name
    namespace = local.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = local.app_name
      }
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.25-alpine"

          port {
            container_port = 80
            protocol       = "TCP"
          }

          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.html.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "this" {
  metadata {
    name      = local.app_name
    namespace = local.namespace
    labels    = local.labels
  }

  spec {
    selector = {
      app = local.app_name
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Ingress for the sample site
resource "kubernetes_ingress_v1" "this" {
  metadata {
    name      = local.app_name
    namespace = local.namespace
    labels    = local.labels
    annotations = merge(
      var.ingress_annotations,
      var.cluster_issuer != null ? {
        "cert-manager.io/cluster-issuer" = var.cluster_issuer
      } : {}
    )
  }

  spec {
    ingress_class_name = var.ingress_class_name

    dynamic "tls" {
      for_each = var.cluster_issuer != null ? [1] : []
      content {
        hosts       = [var.hostname]
        secret_name = "${local.app_name}-tls"
      }
    }

    rule {
      host = var.hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.this.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
