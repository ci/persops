locals {
  matrix_endpoints = {
    client           = "https://matrix.ca7.ir/_matrix/client/versions"
    federation       = "https://matrix.ca7.ir/_matrix/federation/v1/version"
    server_discovery = "https://ca7.ir/.well-known/matrix/server"
    client_discovery = "https://ca7.ir/.well-known/matrix/client"
  }
}

resource "uptimekuma_monitor_http" "matrix" {
  for_each = local.matrix_endpoints

  name                  = "Matrix (${replace(each.key, "_", " ")})"
  url                   = each.value
  description           = "Public HTTPS availability from Amalthea; not an authenticated messaging test."
  interval              = 60
  timeout               = 20
  max_retries           = 2
  retry_interval        = 60
  resend_interval       = 0
  active                = true
  method                = "GET"
  max_redirects         = 3
  accepted_status_codes = ["200"]
  ignore_tls            = false
  expiry_notification   = true
  notification_ids      = [uptimekuma_notification.ntfy.id]
}

resource "uptimekuma_monitor_ping" "pheme" {
  name             = "Pheme (Matrix host)"
  description      = "Reciprocal host reachability over Tailscale from Amalthea."
  hostname         = "100.75.219.10"
  interval         = 60
  timeout          = 10
  max_retries      = 2
  retry_interval   = 60
  resend_interval  = 0
  active           = true
  notification_ids = [uptimekuma_notification.ntfy.id]
}
