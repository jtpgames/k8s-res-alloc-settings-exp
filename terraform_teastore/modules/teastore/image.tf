resource "kubernetes_deployment_v1" "image" {
  depends_on = [kubernetes_deployment_v1.auth]

  metadata {
    labels = {
      app = "image"
    }
    name      = "image"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "image"
      }
    }

    template {
      metadata {
        labels = {
          app = "image"
        }
      }

      spec {
        restart_policy = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image = "descartesresearch/teastore-image"
          image_pull_policy = "Always"
          name  = "image"

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
            for_each = var.image_resources.requests != null || var.image_resources.limits != null ? [1] : []
            content {
              limits   = var.image_resources.limits
              requests = var.image_resources.requests
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}
