module "ingress_controller" {
  source     = "./modules/ingress-controller"

  namespace = "ingress-nginx"
  node = local.nodes.payload
}

module "metric" {
  source     = "./modules/metric"
  depends_on = [module.ingress_controller]

  namespace = "metric"
  node = local.nodes.payload
  grafana_auth = {
    user = "admin"
    password = "admin"
  }
}

module "autoscaler" {
  source     = "./modules/autoscaler"
  depends_on = [module.metric]

  namespace = "autoscaler"
  node = local.nodes.payload

  provisioning = {
    vertical-pod-autoscaler = 1
  }
}

module "workload" {
  source     = "./modules/workload"
  depends_on = [module.metric]

  namespace = "workload"
  node = local.nodes.workload

  image_registry = {
    url                      = local.image_registry.url
    user                     = local.image_registry.user
    password                 = local.image_registry.password
    path_to_dockerconfigjson = local.dockerconfig_path
  }

  provisioning = {
    cpu_load_generator                = 0
    cpu_load_generator_workload_one   = 0
    cpu_load_generator_workload_two   = 0
    cpu_load_generator_workload_three = 0
    memory_allocator                  = 0
    memory_allocator_workload_one     = 0
    memory_allocator_workload_two     = 0
    vpa_memory_allocator              = 1
  }
}
