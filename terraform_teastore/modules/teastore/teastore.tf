resource "kubernetes_namespace_v1" "teastore" {
  provider = kubernetes

  metadata {
    name = local.namespace
  }
}

resource "kubernetes_secret_v1" "teastore" {
  provider   = kubernetes
  depends_on = [kubernetes_namespace_v1.teastore]

  metadata {
    name      = "regcred"
    namespace = local.namespace
  }

  data = {
    ".dockerconfigjson" = file(var.image_registry.path_to_dockerconfigjson)
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_default_service_account_v1" "teastore" {
  provider   = kubernetes
  depends_on = [kubernetes_namespace_v1.teastore]

  metadata {
    namespace = local.namespace
  }

  image_pull_secret {
    name = "regcred"
  }
}

