locals {
  namespace = "noisy-neighbor"
  deployment_id = formatdate("YYYYMMDD-HHmm", timestamp())  # e.g., "20250920-1430"

  memory_allocator_string_list = [for number in range(var.provisioning_memory_allocator) : tostring(number)]
}

variable "node" {
  description = "NodeSelector Node name"
  type        = string
}

variable "image_registry" {
  type = object({
    url                      = string
    path_to_dockerconfigjson = string
  })
}

variable "provisioning_cpu_load_generator" {
  type    = number
}

variable "provisioning_memory_allocator" {
  type    = number
}

