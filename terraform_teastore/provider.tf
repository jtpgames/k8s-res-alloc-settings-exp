provider "kubernetes" {
  config_path = "${path.cwd}/config/kube-config"
}

provider "helm" {
  kubernetes {
    config_path = "${path.cwd}/config/kube-config"
  }
}

provider "null" {
  alias = "null-provider"
}
