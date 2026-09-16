terraform {
  required_version = ">= 1.8.0"

  required_providers {
    uptimekuma = {
      source  = "breml/uptimekuma"
      version = "= 0.4.0"
    }
  }
}

variable "ntfy_access_token" {
  type      = string
  sensitive = true
}

resource "uptimekuma_notification" "ntfy" {
  name = "ntfy"
  type = "ntfy"
  config = jsonencode({
    ntfyAuthenticationMethod = "accessToken"
    ntfyaccesstoken          = var.ntfy_access_token
    ntfyIcon                 = ""
    ntfyPriority             = 4
    ntfyPriorityDown         = 5
    ntfyserverurl            = "https://notify.reverse-justitia.ts.net"
    ntfytopic                = "alerts"
    ntfyUseTemplate          = false
  })
  is_active      = true
  is_default     = true
  apply_existing = true

  lifecycle {
    # Kuma consumes this creation-time action and always reads it back as false.
    ignore_changes = [apply_existing]
  }
}
