resource "kubernetes_deployment_v1" "cpu-load-generator-workload-one" {
  count      = var.provisioning.cpu_load_generator_workload_one != 0 ? 1 : 0
  depends_on = [kubernetes_default_service_account_v1.workload]

  metadata {
    labels = {
      "app" = "cpu-load-generator-workload-one"
    }
    name      = "cpu-load-generator-workload-one"
    namespace = var.namespace
  }
  spec {
    min_ready_seconds         = 0
    paused                    = false
    progress_deadline_seconds = 600
    replicas                  = var.provisioning.cpu_load_generator_workload_one
    revision_history_limit    = 10
    selector {
      match_labels = {
        "app" = "cpu-load-generator-workload-one"
      }
    }
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "25%"
        max_unavailable = "25%"
      }
    }
    template {
      metadata {
        labels = {
          "app" = "cpu-load-generator-workload-one"
        }
      }
      spec {
        dns_policy                       = "ClusterFirst"
        enable_service_links             = false
        host_ipc                         = false
        host_network                     = false
        host_pid                         = false
        restart_policy                   = "Always"
        share_process_namespace          = false
        termination_grace_period_seconds = 30
        node_selector = {
          "kubernetes.io/hostname" = var.node
        }
        container {
          image                      = "${var.image_registry.url}/experiments:cpu-load-generator"
          image_pull_policy          = "Always"
          name                       = "cpu-load-generator-workload-one"
          stdin                      = false
          stdin_once                 = false
          termination_message_path   = "/dev/termination-log"
          termination_message_policy = "File"
          tty                        = false
#          resources {
#            limits = {
#              cpu    = "75m"
#              memory = "100Mi"
#            }
#            requests = {
#              cpu    = "630m"
#              memory = "50Mi"
#            }
#          }
          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
  wait_for_rollout = false
}

resource "kubernetes_service_v1" "cpu-load-generator-workload-one" {
  count      = var.provisioning.cpu_load_generator_workload_one != 0 ? 1 : 0
  depends_on = [kubernetes_deployment_v1.cpu-load-generator-workload-one]

  metadata {
    name      = "cpu-load-generator-workload-one-svc"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "cpu-load-generator-workload-one"
    }
    port {
      port        = "80"
      target_port = "5000"
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "cpu-load-generator-workload-one" {
  count      = var.provisioning.cpu_load_generator_workload_one != 0 ? 1 : 0
  depends_on = [kubernetes_service_v1.cpu-load-generator-workload-one]

  metadata {
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "nginx.ingress.kubernetes.io/use-regex"        = "true"
      "nginx.ingress.kubernetes.io/rewrite-target"   = "/$2"
    }
    labels = {
      "app" = "cpu-load-generator-workload-one"
    }
    name      = "cpu-load-generator-workload-one"
    namespace = var.namespace
  }
  spec {
    rule {
      http {
        path {
          path = "/cpu-load-generator-workload-one(/|$)(.*)"
          backend {
            service {
              name = "cpu-load-generator-workload-one-svc"
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
