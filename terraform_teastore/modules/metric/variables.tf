locals {
  namespace = "metric"
}

variable "node" {
  description = "NodeSelector Node name"
  type        = string
}

variable "grafana_auth" {
  description = "Authentifizierungdaten für den Admin von Grafana"
  type = object({
    user     = string
    password = string
  })
  sensitive = true
}
