resource "kubernetes_namespace_v1" "noisy-neighbor" {
  provider = kubernetes

  metadata {
    name = local.namespace
  }
}

resource "kubernetes_secret_v1" "noisy-neighbor" {
  provider   = kubernetes
  depends_on = [kubernetes_namespace_v1.noisy-neighbor]

  metadata {
    name      = "regcred"
    namespace = local.namespace
  }

  data = {
    ".dockerconfigjson" = file(var.image_registry.path_to_dockerconfigjson)
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_default_service_account_v1" "noisy-neighbor" {
  provider   = kubernetes
  depends_on = [kubernetes_namespace_v1.noisy-neighbor]

  metadata {
    namespace = local.namespace
  }

  image_pull_secret {
    name = "regcred"
  }
}

