resource "kubernetes_namespace_v1" "ingress_controller" {
  provider = kubernetes

  metadata {
    name = local.namespace
  }
}

resource "helm_release" "ingress_controller" {
  provider   = helm
  depends_on = [kubernetes_namespace_v1.ingress_controller]

  name       = "ingress-nginx"
  namespace  = local.namespace
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  # App version: 1.10.1
  version       = "4.10.1"
  max_history   = 1
  recreate_pods = true

  values = [templatefile("${path.module}/values.yml", {
    node = var.node
  })]

  set {
    name  = "controller.extraArgs.enable-ssl-passthrough"
    value = ""
  }
}
