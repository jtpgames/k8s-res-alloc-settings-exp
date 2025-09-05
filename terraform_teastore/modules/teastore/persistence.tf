resource "kubernetes_deployment_v1" "persistence" {
  depends_on = [kubernetes_service.db]

  metadata {
    labels = {
      app = "persistence"
    }
    name      = "persistence"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "persistence"
      }
    }

    template {
      metadata {
        labels = {
          app = "persistence"
        }
      }

      spec {
        restart_policy = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image = "descartesresearch/teastore-persistence"
          image_pull_policy = "Always"
          name  = "persistence"

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
            name  = "DB_HOST"
            value = "db-svc"
          }

          env {
            name  = "DB_PORT"
            value = "3306"
          }

          env {
            name  = "RABBITMQ_HOST"
            value = "rabbitmq-svc"
          }

          dynamic "resources" {
            for_each = var.persistence_resources.requests != null || var.persistence_resources.limits != null ? [1] : []
            content {
              limits   = var.persistence_resources.limits
              requests = var.persistence_resources.requests
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}
