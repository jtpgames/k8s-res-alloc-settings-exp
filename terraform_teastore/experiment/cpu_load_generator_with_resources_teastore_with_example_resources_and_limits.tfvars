# ---- noise-neighbor variables ---

provisioning_cpu_load_generator = 1

cpu_load_generator_resources = {
  requests = {
    cpu = "1m"
  }
  limits = null
}

# ---- teastore variables ---

auth_resources = {
  requests = {
    cpu = "2m"
  }
  limits = {
    cpu = "1000m"
  }
}

db_resources = {
  requests = {
    cpu = "2m"
  }
  limits = {
    cpu = "1000m"
  }
}

image_resources = {
  requests = {
    cpu = "2m"
  }
  limits = {
    cpu = "1000m"
  }
}

persistence_resources = {
  requests = {
    cpu = "2m"
  }
  limits = {
    cpu = "1000m"
  }
}

rabbitmq_resources = {
  requests = {
    cpu = "2m"
  }
  limits = {
    cpu = "1000m"
  }
}

recommender_resources = {
  requests = {
    cpu = "2m"
  }
  limits = {
    cpu = "1000m"
  }
}

registry_resources = {
  requests = {
    cpu = "2m"
  }
  limits = {
    cpu = "1000m"
  }
}

webui_resources = {
  requests = {
    cpu = "2m"
  }
  limits = {
    cpu = "1000m"
  }
}

