# ---- teastore variables ---

auth_resources = {
  requests = {
    cpu = "170m"
    memory = "655Mi"
  }
  limits = {
    cpu = "170m"
    memory = "655Mi"
  }
}

db_resources = {
  requests = {
    cpu = "1m"
    memory = "194Mi"
  }
  limits = {
    cpu = "1m"
    memory = "194Mi"
  }
}

image_resources = {
  requests = {
    cpu = "58m"
    memory = "773Mi"
  }
  limits = {
    cpu = "58m"
    memory = "773Mi"
  }
}

persistence_resources = {
  requests = {
    cpu = "10m"
    memory = "707Mi"
  }
  limits = {
    cpu = "10m"
    memory = "707Mi"
  }
}

rabbitmq_resources = {
  requests = {
    cpu = "8m"
    memory = "463Mi"
  }
  limits = {
    cpu = "8m"
    memory = "463Mi"
  }
}

recommender_resources = {
  requests = {
    cpu = "80m"
    memory = "715Mi"
  }
  limits = {
    cpu = "80m"
    memory = "715Mi"
  }
}

registry_resources = {
  requests = {
    cpu = "42m"
    memory = "328Mi"
  }
  limits = {
    cpu = "42m"
    memory = "328Mi"
  }
}

webui_resources = {
  requests = {
    cpu = "216m"
    memory = "1100Mi"
  }
  limits = {
    cpu = "216m"
    memory = "1100Mi"
  }
}
