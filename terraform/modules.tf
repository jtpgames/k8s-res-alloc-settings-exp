module "ingress_controller" {
  source     = "./modules/ingress-controller"

  namespace = "ingress-nginx"
  node = local.nodes.tools
}

module "metric" {
  source     = "./modules/metric"
  depends_on = [module.ingress_controller]

  namespace = "metric"
  node = local.nodes.tools
  grafana_auth = {
    user = "admin"
    password = "admin"
  }
}

module "autoscaler" {
  source     = "./modules/autoscaler"
  depends_on = [module.metric]

  namespace = "autoscaler"
  node = local.nodes.tools

  provisioning = {
    vertical-pod-autoscaler = 0
  }
}

module "workload" {
  source     = "./modules/workload"
  depends_on = [module.metric]

  namespace = "workload"
  node = local.nodes.main

  image_registry = {
    url                      = local.image_registry.url
    path_to_dockerconfigjson = local.dockerconfig_path
  }

  provisioning = {
    cpu_load_generator                = 1
    cpu_load_generator_workload_one   = 0
    cpu_load_generator_workload_two   = 0
    cpu_load_generator_workload_three = 0
    memory_allocator                  = 1
    memory_allocator_workload_one     = 0
    memory_allocator_workload_two     = 0
    vpa_memory_allocator              = 0
  }
}
