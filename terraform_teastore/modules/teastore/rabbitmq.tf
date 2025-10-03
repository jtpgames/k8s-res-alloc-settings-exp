resource "kubernetes_deployment_v1" "rabbitmq" {
  depends_on = [kubernetes_default_service_account_v1.teastore]

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
          app = "rabbitmq"
        }
      }

      spec {
        restart_policy = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image             = "${var.image_registry.url}/experiments:tools.descartes.teastore.kieker.rabbitmq"
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
              limits = var.rabbitmq_resources.limits != null ? {
                for k, v in var.rabbitmq_resources.limits : k => v if v != null
              } : null
              requests = var.rabbitmq_resources.requests != null ? {
                for k, v in var.rabbitmq_resources.requests : k => v if v != null
              } : null
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}

resource "kubernetes_service" "rabbitmq" {
  depends_on = [kubernetes_deployment_v1.rabbitmq]

  metadata {
    name = "rabbitmq-svc"
    namespace = local.namespace
  }

  spec {
    selector = {
      app = "rabbitmq"
    }

    port {
      name       = "web-ui"
      port       = 8080
      target_port = 8080
    }

    port {
      name       = "amqp"
      port       = 5672
      target_port = 5672
    }

    port {
      name       = "management"
      port       = 15672
      target_port = 15672
    }

    type = "ClusterIP"
  }
}
