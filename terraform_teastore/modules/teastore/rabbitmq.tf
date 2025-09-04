resource "kubernetes_deployment_v1" "rabbitmq" {
  depends_on = [kubernetes_namespace_v1.teastore]

  metadata {
    labels = {
      app = "rabbitmq"
    }
    name      = "rabbitmq"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          app = "registry"
        }
      }

      spec {
        restart_policy = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image             = "descartesresearch/teastore-kieker-rabbitmq"
          image_pull_policy = "Always"
          name              = "rabbitmq"

          port {
            container_port = 8080
          }
          port {
            container_port = 5672
          }
          port {
            container_port = 15672
          }

          dynamic "resources" {
            for_each = var.rabbitmq_resources.requests != null || var.rabbitmq_resources.limits != null ? [1] : []
            content {
              limits   = var.rabbitmq_resources.limits
              requests = var.rabbitmq_resources.requests
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}
