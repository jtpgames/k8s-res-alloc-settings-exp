# This file can be used in addition to other tfvars files using multiple -var-file options

webui_resources = {
  requests = {
    cpu = "100m"
    memory = "1500Mi"
  }
  limits = {
    memory = "1500Mi"
  }
}
