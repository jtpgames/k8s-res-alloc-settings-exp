module "memory-allocator" {
  depends_on = [kubernetes_default_service_account_v1.noise-neighbor]
  source = "./memory-allocator"

  for_each = toset(var.provisioning_memory_allocator)

  namespace = local.namespace
  node      = var.node

  deployment_count = each.key
  deployment_id    = local.deployment_id

  image_registry_url = var.image_registry.url
}
