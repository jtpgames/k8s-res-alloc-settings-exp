resource "kubernetes_namespace_v1" "metric" {
  provider = kubernetes

  metadata {
    name = var.namespace
  }
}