locals {
  namespace = "noisy-neighbor"
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

variable "enable_ipvs_mode" {
  description = "Enable IPVS mode for kube-proxy instead of iptables"
  type        = bool
  default     = false
}
