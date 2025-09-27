# Example tfvars file for CPU load generator resource configuration
# This file can be used in addition to other tfvars files using multiple -var-file options

cpu_load_generator_resources = {
  requests = {
    cpu = "1m"
  }
  limits = null
}
