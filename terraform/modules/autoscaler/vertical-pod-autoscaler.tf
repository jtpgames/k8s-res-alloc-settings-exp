resource "helm_release" "vertical_pod_autoscaler" {
  count      = var.provisioning.vertical-pod-autoscaler != 0 ? 1 : 0
  depends_on = [kubernetes_namespace_v1.autoscaler]
  provider   = helm

  name       = "vertical-pod-autoscaler"
  namespace  = var.namespace
  repository = "https://cowboysysop.github.io/charts/"
  chart      = "vertical-pod-autoscaler"
  # App version: 1.1.2
  version       = "9.8.2"
  max_history   = 1
  recreate_pods = true

  values = [templatefile("${path.module}/vpa_values.yml", {
    node        = var.node
    })
  ]
}
