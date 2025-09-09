locals {
  namespace = "teastore"
}

variable "node" {
  description = "NodeSelector Node name"
  type        = string
}

variable "rabbitmq_resources" {
  type = object({
    limits = object({
      memory = string
    })
    requests = object({
      cpu = string
      memory = string
    })
  })
}

variable "registry_resources" {
  type = object({
    limits = object({
      memory = string
    })
    requests = object({
      cpu = string
      memory = string
    })
  })
}

variable "db_resources" {
  type = object({
    limits = object({
      memory = string
    })
    requests = object({
      cpu = string
      memory = string
    })
  })
}

variable "persistence_resources" {
  type = object({
    limits = object({
      memory = string
    })
    requests = object({
      cpu = string
      memory = string
    })
  })
}

variable "auth_resources" {
  type = object({
    limits = object({
      memory = string
    })
    requests = object({
      cpu = string
      memory = string
    })
  })
}

variable "image_resources" {
  type = object({
    limits = object({
      memory = string
    })
    requests = object({
      cpu = string
      memory = string
    })
  })
}

variable "recommender_resources" {
  type = object({
    limits = object({
      memory = string
    })
    requests = object({
      cpu = string
      memory = string
    })
  })
}

variable "webui_resources" {
  type = object({
    limits = object({
      memory = string
    })
    requests = object({
      cpu = string
      memory = string
    })
  })
}