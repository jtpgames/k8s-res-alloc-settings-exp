variable "namespace" {
  type        = string
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

variable "provisioning" {
  type = object({
    cpu_load_generator                = number
    cpu_load_generator_workload_one   = number
    cpu_load_generator_workload_two   = number
    cpu_load_generator_workload_three = number
    memory_allocator                  = number
    memory_allocator_workload_one     = number
    memory_allocator_workload_two     = number
    vpa_memory_allocator              = number
  })
}
