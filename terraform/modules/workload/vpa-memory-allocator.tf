resource "kubernetes_manifest" "memory_allocator_vpa" {
  count      = var.provisioning.vpa_memory_allocator != 0 ? 1 : 0
  depends_on = [kubernetes_default_service_account_v1.workload]

  manifest = {
    apiVersion = "autoscaling.k8s.io/v1"
    kind       = "VerticalPodAutoscaler"
    metadata = {
      name = "memory-allocator-vpa"
      namespace = var.namespace
    }
    spec = {
      targetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = "memory-allocator"
      }
      updatePolicy = {
        updateMode  = "Auto"
        minReplicas = 1
      }
      resourcePolicy = {
        containerPolicies = [{
          containerName = "*"
          minAllowed = {
            cpu = "1m"
            memory = "1Mi"
          }
#          maxAllowed = {
#            cpu = "1"
#            memory = "500Mi"
#          }
          controlledResources = ["cpu", "memory"]
        }]
      }
    }
  }
}

resource "kubernetes_deployment_v1" "memory_allocator" {
  count      = var.provisioning.vpa_memory_allocator != 0 ? 1 : 0
  depends_on = [kubernetes_manifest.memory_allocator_vpa]

  metadata {
    name      = "memory-allocator"
    namespace = var.namespace
  }
  spec {
    replicas = 1
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
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }
        container {
          name                       = "memory-allocator"
          image                      = "${var.image_registry.url}/memory-allocator:latest"
          image_pull_policy          = "Always"
          resources {
            requests = {
              cpu    = "100m"
              memory = "300Mi"
            }
#            limits = {
#              memory = "300Mi"
#            }
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 3
            period_seconds        = 3
          }
          lifecycle {
            pre_stop {
              http_get {
                path = "/health"
                port = 5000
              }
            }
          }
        }
      }
    }
  }
  wait_for_rollout = false
}

resource "kubernetes_service_v1" "memory_allocator_service" {
  count      = var.provisioning.vpa_memory_allocator != 0 ? 1 : 0
  depends_on = [kubernetes_deployment_v1.memory_allocator]

  metadata {
    name      = "memory-allocator-svc"
    namespace = var.namespace
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

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "memory_allocator_ingress" {
  count      = var.provisioning.vpa_memory_allocator != 0 ? 1 : 0
  depends_on = [kubernetes_service_v1.memory_allocator_service]

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
    namespace = var.namespace
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