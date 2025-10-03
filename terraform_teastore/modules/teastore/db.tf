resource "kubernetes_deployment_v1" "db" {
  depends_on = [kubernetes_service.registry]

  metadata {
    labels = {
      app = "db"
    }
    name      = "db"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "db"
      }
    }

    template {
      metadata {
        labels = {
          app = "db"
        }
      }

      spec {
        restart_policy = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image = "descartesresearch/teastore-db"
          image_pull_policy = "Always"
          name  = "db"

          port {
            container_port = 3306
          }

          dynamic "resources" {
            for_each = var.db_resources.requests != null || var.db_resources.limits != null ? [1] : []
            content {
              limits = var.db_resources.limits != null ? {
                for k, v in var.db_resources.limits : k => v if v != null
              } : null
              requests = var.db_resources.requests != null ? {
                for k, v in var.db_resources.requests : k => v if v != null
              } : null
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}

resource "kubernetes_service" "db" {
  depends_on = [kubernetes_deployment_v1.registry]

  metadata {
    name      = "db-svc"
    namespace = local.namespace
  }

  spec {
    selector = {
      app = "db"
    }

    port {
      port        = 3306
      target_port = 3306
    }

    type = "ClusterIP"
  }
}
