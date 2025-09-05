resource "kubernetes_deployment_v1" "recommender" {
  depends_on = [kubernetes_deployment_v1.image]

  metadata {
    labels = {
      app = "recommender"
    }
    name      = "recommender"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "recommender"
      }
    }

    template {
      metadata {
        labels = {
          app = "recommender"
        }
      }

      spec {
        restart_policy = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image = "descartesresearch/teastore-recommender"
          image_pull_policy = "Always"
          name  = "recommender"

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
            for_each = var.recommender_resources.requests != null || var.recommender_resources.limits != null ? [1] : []
            content {
              limits   = var.recommender_resources.limits
              requests = var.recommender_resources.requests
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}
