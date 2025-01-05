resource "kubernetes_namespace_v1" "autoscaler" {
  provider = kubernetes

  metadata {
    name = var.namespace
  }
}