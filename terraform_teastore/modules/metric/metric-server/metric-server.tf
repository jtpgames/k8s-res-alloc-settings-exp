resource "helm_release" "metric_server" {
  provider   = helm

  name       = "metric-server"
  namespace  = var.namespace
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  # App version: 0.7.1
  version       = "3.12.1"
  max_history   = 1
  recreate_pods = true

  set {
    name = "nodeSelector.kubernetes\\.io/hostname"
    value = var.node
  }
}
