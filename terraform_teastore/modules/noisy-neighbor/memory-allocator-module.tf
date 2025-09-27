module "memory-allocator" {
  depends_on = [kubernetes_default_service_account_v1.noisy-neighbor]
  source = "./memory-allocator"

  for_each = toset(local.memory_allocator_string_list)

  namespace = local.namespace
  node      = var.node

  deployment_count = each.key
  deployment_id    = local.deployment_id

  image_registry_url = var.image_registry.url
}
