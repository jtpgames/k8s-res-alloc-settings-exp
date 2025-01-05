variable "namespace" {
  description = "Name des Namespaces"
  type        = string
}

variable "node" {
  description = "NodeSelector Node name"
  type        = string
}

variable "provisioning" {
  type = object({
    vertical-pod-autoscaler = number
  })
}