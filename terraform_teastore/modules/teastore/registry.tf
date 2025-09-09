resource "kubernetes_deployment_v1" "registry" {
  depends_on = [kubernetes_service.rabbitmq]

  metadata {
    labels = {
      app = "registry"
    }
    name      = "registry"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "registry"
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
          image = "descartesresearch/teastore-registry"
          image_pull_policy = "Always"
          name  = "registry"

          port {
            container_port = 8080
          }

          env {
            name  = "USE_POD_IP"
            value = "true"
          }

          dynamic "resources" {
            for_each = var.registry_resources.requests != null || var.registry_resources.limits != null ? [1] : []
            content {
              limits   = var.registry_resources.limits
              requests = var.registry_resources.requests
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}

resource "kubernetes_service" "registry" {
  depends_on = [kubernetes_deployment_v1.registry]

  metadata {
    name      = "registry-svc"
    namespace = local.namespace
  }

  spec {
    selector = {
      app = "registry"
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}
