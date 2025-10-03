# ---- teastore variables ---

auth_resources = {
  requests = {
    cpu = "170m"
    memory = "655Mi"
  }
  limits = {
    cpu = "340m"
    memory = "755Mi"
  }
}

db_resources = {
  requests = {
    cpu = "1m"
    memory = "194Mi"
  }
  limits = {
    cpu = "2m"
    memory = "294Mi"
  }
}

image_resources = {
  requests = {
    cpu = "58m"
    memory = "773Mi"
  }
  limits = {
    cpu = "116m"
    memory = "873Mi"
  }
}

persistence_resources = {
  requests = {
    cpu = "10m"
    memory = "707Mi"
  }
  limits = {
    cpu = "20m"
    memory = "807Mi"
  }
}

rabbitmq_resources = {
  requests = {
    cpu = "8m"
    memory = "463Mi"
  }
  limits = {
    cpu = "16m"
    memory = "563Mi"
  }
}

recommender_resources = {
  requests = {
    cpu = "80m"
    memory = "715Mi"
  }
  limits = {
    cpu = "160m"
    memory = "815Mi"
  }
}

registry_resources = {
  requests = {
    cpu = "42m"
    memory = "328Mi"
  }
  limits = {
    cpu = "84m"
    memory = "428Mi"
  }
}

webui_resources = {
  requests = {
    cpu = "216m"
    memory = "1100Mi"
  }
  limits = {
    cpu = "638m"
    memory = "1600Mi"
  }
}
