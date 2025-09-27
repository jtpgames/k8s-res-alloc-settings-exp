resource "kubernetes_deployment_v1" "cpu-load-generator" {
  count      = var.provisioning_cpu_load_generator != 0 ? 1 : 0
  depends_on = [kubernetes_default_service_account_v1.noisy-neighbor]

  metadata {
    labels = {
      "app"        = "cpu-load-generator"
      "deployment" = local.deployment_id
    }
    name      = "cpu-load-generator-${local.deployment_id}"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app"        = "cpu-load-generator"
        "deployment" = local.deployment_id
      }
    }

    template {
      metadata {
        labels = {
          "app"        = "cpu-load-generator"
          "deployment" = local.deployment_id
        }
      }

      spec {
        restart_policy                   = "Always"
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }

        container {
          image                      = "${var.image_registry.url}/experiments:cpu-load-generator"
          image_pull_policy          = "Always"
          name                       = "cpu-load-generator"

          resources {
            limits = var.cpu_load_generator_resources.limits != null ? {
              cpu = var.cpu_load_generator_resources.limits.cpu
            } : {}
            requests = var.cpu_load_generator_resources.requests != null ? {
              cpu = var.cpu_load_generator_resources.requests.cpu
            } : {}
          }
        }
      }
    }
  }

  wait_for_rollout = false
}

resource "kubernetes_service_v1" "cpu-load-generator" {
  count      = var.provisioning_cpu_load_generator != 0 ? 1 : 0
  depends_on = [kubernetes_deployment_v1.cpu-load-generator]

  metadata {
    name      = "cpu-load-generator-svc-${local.deployment_id}"
    namespace = local.namespace
  }
  spec {
    selector = {
      "app"        = "cpu-load-generator"
      "deployment" = local.deployment_id
    }
    port {
      port        = 80
      target_port = 5000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "cpu-load-generator" {
  count      = var.provisioning_cpu_load_generator != 0 ? 1 : 0
  depends_on = [kubernetes_service_v1.cpu-load-generator]

  metadata {
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "nginx.ingress.kubernetes.io/use-regex"        = "true"
      "nginx.ingress.kubernetes.io/rewrite-target"   = "/$2"
    }
    labels = {
      "app"        = "cpu-load-generator"
      "deployment" = local.deployment_id
    }
    name      = "cpu-load-generator-ingress-${local.deployment_id}"
    namespace = local.namespace
  }
  spec {
    rule {
      http {
        path {
          path = "/cpu-load-generator(/|$)(.*)"
          backend {
            service {
              name = "cpu-load-generator-svc-${local.deployment_id}"
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
