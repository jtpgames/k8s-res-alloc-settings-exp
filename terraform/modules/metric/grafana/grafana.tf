resource "helm_release" "grafana" {
  provider      = helm

  name          = "grafana"
  namespace     = var.namespace
  repository    = "https://grafana.github.io/helm-charts"
  chart         = "grafana"
# Grafana darf nicht auf Version 11 aktualisiert werden, da der Angular Support für unsere Dashboards wegfällt
# https://grafana.com/docs/grafana/latest/developers/angular_deprecation/
  version       = "7.3.9"
  max_history   = 1
  atomic        = true
  wait_for_jobs = true
  recreate_pods = true
  verify        = false

  values = [templatefile("${path.module}/grafana_values.yml", {
    node                    = var.node
    user                    = var.auth.user
    password                = var.auth.password
    dashboard_config_mounts = indent(2, local.dashboard_config_mounts)
  })]
}

resource "kubernetes_ingress_v1" "grafana" {
  provider = kubernetes
  depends_on = [helm_release.grafana]

  metadata {
    name      = "grafana"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      http {
        path {
          path = "/"
          backend {
            service {
              name = "grafana"
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

resource "kubernetes_config_map" "dashboards" {
  for_each = local.dashboard_files

  metadata {
    name      = "dashboard-${replace(each.key, ".json", "")}"
    namespace = var.namespace
  }

  data = {
    "${each.key}" = file("${path.module}/${local.dashboards_dir}/${each.key}")
  }
}
