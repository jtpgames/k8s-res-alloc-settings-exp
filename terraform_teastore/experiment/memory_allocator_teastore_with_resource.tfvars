# ---- noise-neighbor variables ---

provisioning_memory_allocator = 30

# ---- teastore variables ---

auth_resources = {
  requests = {
    cpu = "608m"
    memory = "749Mi"
  }
  limits = {
    memory = "749Mi"
  }
}

db_resources = {
  requests = {
    cpu = "43m"
    memory = "125Mi"
  }
  limits = {
    memory = "125Mi"
  }
}

image_resources = {
  requests = {
    cpu = "691m"
    memory = "929Mi"
  }
  limits = {
    memory = "929Mi"
  }
}

persistence_resources = {
  requests = {
    cpu = "1030m"
    memory = "891Mi"
  }
  limits = {
    memory = "891Mi"
  }
}

rabbitmq_resources = {
  requests = {
    cpu = "381m"
    memory = "694Mi"
  }
  limits = {
    memory = "694Mi"
  }
}

recommender_resources = {
  requests = {
    cpu = "383m"
    memory = "844Mi"
  }
  limits = {
    memory = "844Mi"
  }
}

registry_resources = {
  requests = {
    cpu = "115m"
    memory = "390Mi"
  }
  limits = {
    memory = "390Mi"
  }
}

webui_resources = {
  requests = {
    cpu = "1960m"
    memory = "2840Mi"
  }
  limits = {
    memory = "2840Mi"
  }
}
