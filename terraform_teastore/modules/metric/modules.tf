module "metric-server" {
  depends_on = [kubernetes_namespace_v1.metric]
  source     = "metric-server"

  namespace  = local.namespace
  node       = var.node
}

module "prometheus" {
  depends_on = [kubernetes_namespace_v1.metric]
  source     = "prometheus"

  namespace  = local.namespace
  node       = var.node
}

module "grafana" {
  depends_on = [kubernetes_namespace_v1.metric]
  source     = "grafana"

  namespace  = local.namespace
  node       = var.node
  auth       = var.grafana_auth
}
