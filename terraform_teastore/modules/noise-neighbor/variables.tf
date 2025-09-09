locals {
  namespace = "noise-neighbor"
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
