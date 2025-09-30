# This file can be used in addition to other tfvars files using multiple -var-file options

webui_resources = {
  requests = {
    cpu = "100m"
    memory = "100Mi"
  }
  limits = {
    memory = "900Mi"
  }
}
