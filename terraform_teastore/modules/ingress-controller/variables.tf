locals {
  namespace = "ingress-nginx"
}

variable "node" {
  description = "NodeSelector Node name"
  type        = string
}
