resource "kubernetes_namespace_v1" "workload" {
  provider = kubernetes

  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "workload" {
  provider   = kubernetes
  depends_on = [kubernetes_namespace_v1.workload]

  metadata {
    name      = "regcred"
    namespace = var.namespace
  }

  data = {
    ".dockerconfigjson" = templatefile(var.image_registry.path_to_dockerconfigjson, {
      GSImageUser = var.image_registry.user,
      GSImagePW   = var.image_registry.password,
      Auth        = base64encode("${var.image_registry.user}:${var.image_registry.password}")
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_default_service_account_v1" "workload" {
  provider   = kubernetes
  depends_on = [kubernetes_namespace_v1.workload]

  metadata {
    namespace = var.namespace
  }

  image_pull_secret {
    name = "regcred"
  }
}

