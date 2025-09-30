resource "kubernetes_deployment_v1" "webui" {
  depends_on = [kubernetes_deployment_v1.recommender]

  metadata {
    labels = {
      app = "webui"
    }
    name      = "webui"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "webui"
      }
    }

    template {
      metadata {
        labels = {
          app = "webui"
        }
      }

      spec {
        restart_policy = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image = "descartesresearch/teastore-webui"
          image_pull_policy = "Always"
          name  = "webui"

          port {
            container_port = 8080
          }

          env {
            name  = "USE_POD_IP"
            value = "true"
          }

          env {
            name  = "REGISTRY_HOST"
            value = "registry-svc"
          }

          env {
            name  = "RABBITMQ_HOST"
            value = "rabbitmq-svc"
          }

          dynamic "resources" {
            for_each = var.webui_resources.requests != null || var.webui_resources.limits != null ? [1] : []
            content {
              limits = var.webui_resources.limits != null ? {
                for k, v in var.webui_resources.limits : k => v if v != null
              } : null
              requests = var.webui_resources.requests != null ? {
                for k, v in var.webui_resources.requests : k => v if v != null
              } : null
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}

resource "kubernetes_service_v1" "webui" {
  depends_on = [kubernetes_deployment_v1.webui]

  metadata {
    name      = "webui-svc"
    namespace = local.namespace
  }
  spec {
    selector = {
      app = "webui"
    }
    port {
      port        = "80"
      target_port = "8080"
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "webui" {
  depends_on = [kubernetes_service_v1.webui]

  metadata {
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
#      "nginx.ingress.kubernetes.io/use-regex"        = "true"
#      "nginx.ingress.kubernetes.io/rewrite-target"   = "/$2"
    }
    labels = {
      "app" = "webui"
    }
    name      = "webui"
    namespace = local.namespace
  }
  spec {
    rule {
      http {
        path {
          path = "/"
          backend {
            service {
              name = "webui-svc"
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
