# ---- teastore variables ---

use_kieker = false

auth_resources = {
  requests = {
    cpu = "340m"
    memory = "655Mi"
  }
  limits = {
    cpu = "680m"
    memory = "800Mi"
  }
}

db_resources = {
  requests = {
    cpu = "10m"
    memory = "194Mi"
  }
  limits = {
    cpu = "400m"
    memory = "294Mi"
  }
}

image_resources = {
  requests = {
    cpu = "232m"
    memory = "800Mi"
  }
  limits = {
    cpu = "564m"
    memory = "1000Mi"
  }
}

persistence_resources = {
  requests = {
    cpu = "240m"
    memory = "707Mi"
  }
  limits = {
    cpu = "720m"
    memory = "900Mi"
  }
}

rabbitmq_resources = {
  requests = {
    cpu = "100m"
    memory = "463Mi"
  }
  limits = {
    cpu = "600m"
    memory = "563Mi"
  }
}

recommender_resources = {
  requests = {
    cpu = "320m"
    memory = "715Mi"
  }
  limits = {
    cpu = "960m"
    memory = "815Mi"
  }
}

registry_resources = {
  requests = {
    cpu = "84m"
    memory = "328Mi"
  }
  limits = {
    cpu = "252m"
    memory = "428Mi"
  }
}

webui_resources = {
  requests = {
    cpu = "432m"
    memory = "1100Mi"
  }
  limits = {
    cpu = "1276m"
    memory = "1600Mi"
  }
}
