
# This file can be used in addition to other tfvars files using multiple -var-file options

webui_resources = {
  requests = {
    cpu = "50m"
    memory = "2000Mi"
  }
  limits = {
    cpu = "100m"
    memory = "2000Mi"
  }
}
