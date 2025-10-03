resource "kubernetes_deployment_v1" "auth" {
  depends_on = [kubernetes_deployment_v1.persistence]

  metadata {
    labels = {
      app = "auth"
    }
    name      = "auth"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "auth"
      }
    }

    template {
      metadata {
        labels = {
          app = "auth"
        }
      }

      spec {
        restart_policy = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image = "descartesresearch/teastore-auth"
          image_pull_policy = "Always"
          name  = "auth"

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
            for_each = var.auth_resources.requests != null || var.auth_resources.limits != null ? [1] : []
            content {
              limits = var.auth_resources.limits != null ? {
                for k, v in var.auth_resources.limits : k => v if v != null
              } : null
              requests = var.auth_resources.requests != null ? {
                for k, v in var.auth_resources.requests : k => v if v != null
              } : null
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}
