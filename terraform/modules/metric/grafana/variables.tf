locals {
  dashboards_dir = "dashboards"

  dashboard_files = fileset("${path.module}/${local.dashboards_dir}", "*.json")

  dashboard_config_strings = [for file in local.dashboard_files : {
    name      = "dashboard-${replace(basename(file), ".json", "")}"
    configMap = "dashboard-${replace(basename(file), ".json", "")}"
    mountPath = "/var/lib/grafana/dashboards/default/${file}"
    subPath   = file
  }]

  dashboard_config_mounts = join("\n", [for cfg in local.dashboard_config_strings : <<-EOT

  - name: ${cfg.name}
    configMap: ${cfg.configMap}
    mountPath: ${cfg.mountPath}
    subPath: ${cfg.subPath}
    readOnly: true
  EOT
  ])
}

variable "namespace" {
  description = "Name des Namespaces"
  type        = string
}

variable "node" {
  description = "NodeSelector Node name"
  type        = string
}

variable "auth" {
  description = "Authentifizierungdaten für den Admin von Grafana"
  type = object({
    user     = string
    password = string
  })
  sensitive = true
}