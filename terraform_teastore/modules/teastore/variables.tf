locals {
  namespace = "teastore"
}

variable "node" {
  description = "NodeSelector Node name"
  type        = string
}

variable "use_kieker" {
  description = "Enable Kieker monitoring with RabbitMQ. When false, RabbitMQ deployment and RABBITMQ_HOST env var are omitted."
  type        = bool
  default     = true
}

variable "image_registry" {
  type = object({
    url                      = string
    path_to_dockerconfigjson = string
  })
}

variable "rabbitmq_resources" {
  type = object({
    limits = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
    requests = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
  })
}

variable "registry_resources" {
  type = object({
    limits = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
    requests = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
  })
}

variable "db_resources" {
  type = object({
    limits = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
    requests = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
  })
}

variable "persistence_resources" {
  type = object({
    limits = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
    requests = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
  })
}

variable "auth_resources" {
  type = object({
    limits = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
    requests = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
  })
}

variable "image_resources" {
  type = object({
    limits = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
    requests = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
  })
}

variable "recommender_resources" {
  type = object({
    limits = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
    requests = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
  })
}

variable "webui_resources" {
  type = object({
    limits = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
    requests = optional(object({
      cpu = optional(string)
      memory = optional(string)
    }))
  })
}
