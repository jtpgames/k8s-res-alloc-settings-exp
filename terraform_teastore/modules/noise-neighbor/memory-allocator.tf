resource "kubernetes_deployment_v1" "memory-allocator" {
  count      = var.provisioning_memory_allocator != 0 ? 1 : 0
  depends_on = [kubernetes_default_service_account_v1.noise-neighbor]

  metadata {
    labels = {
      "app" = "memory-allocator"
    }
    name      = "memory-allocator"
    namespace = local.namespace
  }

  spec {
    replicas = var.provisioning_memory_allocator

    selector {
      match_labels = {
        "app" = "memory-allocator"
      }
    }

    template {
      metadata {
        labels = {
          "app" = "memory-allocator"
        }
      }

      spec {
        restart_policy                   = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image                      = "${var.image_registry.url}/experiments:memory-allocator"
          image_pull_policy          = "Always"
          name                       = "memory-allocator"
        }
      }
    }
  }

  wait_for_rollout = false
}

resource "kubernetes_service_v1" "memory-allocator" {
  count      = var.provisioning_memory_allocator != 0 ? 1 : 0
  depends_on = [kubernetes_deployment_v1.memory-allocator]

  metadata {
    name      = "memory-allocator-svc"
    namespace = local.namespace
  }
  spec {
    selector = {
      app = "memory-allocator"
    }
    port {
      port        = "80"
      target_port = "5000"
      protocol    = "TCP"
    }

    type                     = "LoadBalancer"
    # Since all pods are on same node due to NodeSelector, 
    # "Local" will distribute traffic equally among local pods
    external_traffic_policy  = "Local"
    session_affinity        = "None"
  }
}

resource "kubernetes_ingress_v1" "memory-allocator" {
  count      = var.provisioning_memory_allocator != 0 ? 1 : 0
  depends_on = [kubernetes_service_v1.memory-allocator]

  metadata {
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "nginx.ingress.kubernetes.io/use-regex"        = "true"
      "nginx.ingress.kubernetes.io/rewrite-target"   = "/$2"
    }
    labels = {
      "app" = "memory-allocator"
    }
    name      = "memory-allocator"
    namespace = local.namespace
  }
  spec {
    rule {
      http {
        path {
          path = "/memory-allocator(/|$)(.*)"
          backend {
            service {
              name = "memory-allocator-svc"
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
