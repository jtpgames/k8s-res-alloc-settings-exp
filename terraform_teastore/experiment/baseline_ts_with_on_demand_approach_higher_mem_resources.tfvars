# ---- teastore variables ---

use_kieker = false

auth_resources = {
  requests = {
    memory = "655Mi"
  }
  limits = {
    memory = "800Mi"
  }
}

db_resources = {
  requests = {
    memory = "194Mi"
  }
  limits = {
    memory = "294Mi"
  }
}

image_resources = {
  requests = {
    memory = "800Mi"
  }
  limits = {
    memory = "1000Mi"
  }
}

persistence_resources = {
  requests = {
    memory = "707Mi"
  }
  limits = {
    memory = "900Mi"
  }
}

rabbitmq_resources = {
  requests = {
    memory = "463Mi"
  }
  limits = {
    memory = "563Mi"
  }
}

recommender_resources = {
  requests = {
    memory = "715Mi"
  }
  limits = {
    memory = "815Mi"
  }
}

registry_resources = {
  requests = {
    memory = "328Mi"
  }
  limits = {
    memory = "428Mi"
  }
}

webui_resources = {
  requests = {
    memory = "930Mi"
  }
  limits = {
    memory = "1600Mi"
  }
}
