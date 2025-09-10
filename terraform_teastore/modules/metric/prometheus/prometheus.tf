resource "helm_release" "prometheus" {
  provider      = helm

  name          = "prometheus"
  namespace     = var.namespace
  repository    = "https://prometheus-community.github.io/helm-charts"
  chart         = "prometheus"
  version       = "25.20.0"
  max_history   = 1
  atomic        = true
  wait_for_jobs = true
  recreate_pods = true

  values = [templatefile("${path.module}/prometheus_values.yml", {
    namespace   = var.namespace
    node        = var.node
    })
  ]
}