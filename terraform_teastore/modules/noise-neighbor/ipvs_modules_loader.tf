# resource "kubernetes_daemon_set_v1" "ipvs_modules_loader" {
#   metadata {
#     name      = "ipvs-modules-loader"
#     namespace = "kube-system"
#     labels = {
#       app = "ipvs-modules-loader"
#     }
#   }
#
#   spec {
#     selector {
#       match_labels = {
#         app = "ipvs-modules-loader"
#       }
#     }
#
#     template {
#       metadata {
#         labels = {
#           app = "ipvs-modules-loader"
#         }
#       }
#
#       spec {
#         host_pid = true
#
#         toleration {
#           operator = "Exists"
#         }
#
#         node_selector = {
#           "kubernetes.io/os" = "linux"
#         }
#
#         container {
#           name  = "loader"
#           image = "busybox:1.36"
#           command = [
#             "sh",
#             "-c",
#             <<EOT
# modprobe ip_vs
# modprobe ip_vs_rr
# modprobe ip_vs_wrr
# modprobe ip_vs_sh
# sleep 3600
# EOT
#           ]
#           security_context {
#             privileged = true
#           }
#         }
#       }
#     }
#   }
# }
#
