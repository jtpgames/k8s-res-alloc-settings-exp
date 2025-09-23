resource "kubernetes_deployment_v1" "memory-allocator" {
  metadata {
    labels = {
      "app"        = "memory-allocator-${var.deployment_count}"
      "deployment" = var.deployment_id
    }
    name      = "memory-allocator-${var.deployment_count}-${var.deployment_id}"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app"        = "memory-allocator-${var.deployment_count}"
        "deployment" = var.deployment_id
      }
    }

    template {
      metadata {
        labels = {
          "app"        = "memory-allocator-${var.deployment_count}"
          "deployment" = var.deployment_id
        }
      }

      spec {
        restart_policy = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image             = "${var.image_registry_url}/experiments:memory-allocator"
          image_pull_policy = "Always"
          name              = "memory-allocator"
        }
      }
    }
  }

  wait_for_rollout = false
}

resource "kubernetes_service_v1" "memory-allocator" {
  depends_on = [kubernetes_deployment_v1.memory-allocator]

  metadata {
    name      = "memory-allocator-svc-${var.deployment_count}-${var.deployment_id}"
    namespace = var.namespace
  }

  spec {
    selector = {
      "app"        = "memory-allocator-${var.deployment_count}"
      "deployment" = var.deployment_id
    }
    port {
      port        = 80
      target_port = 5000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "memory-allocator" {
  depends_on = [kubernetes_service_v1.memory-allocator]

  metadata {
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
    }
    labels = {
      "app"        = "memory-allocator-${var.deployment_count}"
      "deployment" = var.deployment_id
    }
    name      = "memory-allocator-ingress-${var.deployment_count}-${var.deployment_id}"
    namespace = var.namespace
  }

  spec {
    rule {
      http {
        path {
          path = "/memory-allocator-${var.deployment_count}(/|$)(.*)"
          backend {
            service {
              name = "memory-allocator-svc-${var.deployment_count}-${var.deployment_id}"
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
