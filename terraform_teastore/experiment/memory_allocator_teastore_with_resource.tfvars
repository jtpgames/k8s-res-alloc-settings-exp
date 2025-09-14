# ---- noise-neighbor variables ---

provisioning_memory_allocator = 1

# ---- teastore variables ---

auth_resources = {
  requests = {
    cpu = "731m"
    memory = "586Mi"
  }
  limits = {
    memory = "586Mi"
  }
}

db_resources = {
  requests = {
    cpu = "34m"
    memory = "119Mi"
  }
  limits = {
    memory = "119Mi"
  }
}

image_resources = {
  requests = {
    cpu = "767m"
    memory = "864Mi"
  }
  limits = {
    memory = "864Mi"
  }
}

persistence_resources = {
  requests = {
    cpu = "872m"
    memory = "769Mi"
  }
  limits = {
    memory = "769Mi"
  }
}

rabbitmq_resources = {
  requests = {
    cpu = "277m"
    memory = "427Mi"
  }
  limits = {
    memory = "427Mi"
  }
}

recommender_resources = {
  requests = {
    cpu = "311m"
    memory = "535Mi"
  }
  limits = {
    memory = "535Mi"
  }
}

registry_resources = {
  requests = {
    cpu = "88m"
    memory = "332Mi"
  }
  limits = {
    memory = "332Mi"
  }
}

webui_resources = {
  requests = {
    cpu = "1560m"
    memory = "1141Mi"
  }
  limits = {
    memory = "1141Mi"
  }
}
