module "ingress_controller" {
  source     = "./modules/ingress-controller"

  node = local.nodes.tools
}

module "metric" {
  source     = "./modules/metric"
  depends_on = [module.ingress_controller]

  node = local.nodes.tools

  grafana_auth = {
    user = "admin"
    password = "admin"
  }
}

module "teastore" {
  source     = "./modules/teastore"
  depends_on = [module.metric]

  node = local.nodes.main

  image_registry = {
    url                      = local.image_registry_url
    path_to_dockerconfigjson = local.dockerconfig_path
  }
  
  auth_resources = var.auth_resources
  db_resources = var.db_resources
  image_resources = var.image_resources
  persistence_resources = var.persistence_resources
  rabbitmq_resources = var.rabbitmq_resources
  recommender_resources = var.recommender_resources
  registry_resources = var.registry_resources
  webui_resources = var.webui_resources
  use_kieker = var.use_kieker
}

module "noisy-neighbor" {
  source     = "./modules/noisy-neighbor"
  depends_on = [module.teastore]

  node = local.nodes.main

  image_registry = {
    url                      = local.image_registry_url
    path_to_dockerconfigjson = local.dockerconfig_path
  }

  provisioning_cpu_load_generator = var.provisioning_cpu_load_generator
  provisioning_memory_allocator   = var.provisioning_memory_allocator
  cpu_load_generator_resources    = var.cpu_load_generator_resources
}
