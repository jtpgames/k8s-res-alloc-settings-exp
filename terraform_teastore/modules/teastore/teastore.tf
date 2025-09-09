resource "kubernetes_namespace_v1" "teastore" {
  provider = kubernetes

  metadata {
    name = local.namespace
  }
}