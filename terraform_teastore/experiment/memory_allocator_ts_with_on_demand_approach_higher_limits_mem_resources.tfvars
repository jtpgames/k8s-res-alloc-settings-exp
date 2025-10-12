# ---- noise-neighbor variables ---

provisioning_memory_allocator = 28

# ---- teastore variables ---

auth_resources = {
  requests = {
    memory = "655Mi"
  }
  limits = {
    memory = "1965Mi"
  }
}

db_resources = {
  requests = {
    memory = "194Mi"
  }
  limits = {
    memory = "582Mi"
  }
}

image_resources = {
  requests = {
    memory = "800Mi"
  }
  limits = {
    memory = "2400Mi"
  }
}

persistence_resources = {
  requests = {
    memory = "707Mi"
  }
  limits = {
    memory = "2121Mi"
  }
}

rabbitmq_resources = {
  requests = {
    memory = "463Mi"
  }
  limits = {
    memory = "1389Mi"
  }
}

recommender_resources = {
  requests = {
    memory = "715Mi"
  }
  limits = {
    memory = "2145Mi"
  }
}

registry_resources = {
  requests = {
    memory = "328Mi"
  }
  limits = {
    memory = "984Mi"
  }
}

webui_resources = {
  requests = {
    memory = "930Mi"
  }
  limits = {
    memory = "2790Mi"
  }
}
