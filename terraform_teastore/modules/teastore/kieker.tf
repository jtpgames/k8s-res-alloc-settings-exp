resource "kubernetes_deployment_v1" "registry" {
  depends_on = [kubernetes_deployment_v1.rabbitmq]

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

resource "kubernetes_deployment_v1" "db" {
  depends_on = [kubernetes_deployment_v1.registry]

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
          name  = "registry"

          port {
            container_port = 3306
          }

          dynamic "resources" {
            for_each = var.db_resources.requests != null || var.db_resources.limits != null ? [1] : []
            content {
              limits   = var.db_resources.limits
              requests = var.db_resources.requests
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}

resource "kubernetes_deployment_v1" "persistence" {
  depends_on = [kubernetes_deployment_v1.db]

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

          env {
            name  = "HOST_NAME"
            value = "persistence"
          }

          env {
            name  = "REGISTRY_HOST"
            value = "registry"
          }

          env {
            name  = "DB_HOST"
            value = "db"
          }

          env {
            name  = "DB_PORT"
            value = "3306"
          }

          env {
            name  = "RABBITMQ_HOST"
            value = "rabbitmq"
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

          env {
            name  = "HOST_NAME"
            value = "auth"
          }

          env {
            name  = "REGISTRY_HOST"
            value = "registry"
          }

          env {
            name  = "RABBITMQ_HOST"
            value = "rabbitmq"
          }

          dynamic "resources" {
            for_each = var.auth_resources.requests != null || var.auth_resources.limits != null ? [1] : []
            content {
              limits   = var.auth_resources.limits
              requests = var.auth_resources.requests
            }
          }
        }
      }
    }
  }

  wait_for_rollout = true
}

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

          env {
            name  = "HOST_NAME"
            value = "image"
          }

          env {
            name  = "REGISTRY_HOST"
            value = "registry"
          }

          env {
            name  = "RABBITMQ_HOST"
            value = "rabbitmq"
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

          env {
            name  = "HOST_NAME"
            value = "recommender"
          }

          env {
            name  = "REGISTRY_HOST"
            value = "registry"
          }

          env {
            name  = "RABBITMQ_HOST"
            value = "rabbitmq"
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

          env {
            name  = "HOST_NAME"
            value = "webui"
          }

          env {
            name  = "REGISTRY_HOST"
            value = "registry"
          }

          env {
            name  = "RABBITMQ_HOST"
            value = "rabbitmq"
          }

          dynamic "resources" {
            for_each = var.webui_resources.requests != null || var.webui_resources.limits != null ? [1] : []
            content {
              limits   = var.webui_resources.limits
              requests = var.webui_resources.requests
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
      port        = "8080"
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
      "nginx.ingress.kubernetes.io/use-regex"        = "true"
      "nginx.ingress.kubernetes.io/rewrite-target"   = "/$2"
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
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}
