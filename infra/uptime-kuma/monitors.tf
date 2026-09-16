locals {
  apps = {
    actual = {
      name = "Actual Budget"
      url  = "https://actual.reverse-justitia.ts.net/health"
    }
    home_assistant = {
      name = "Home Assistant"
      url  = "https://home-assistant.reverse-justitia.ts.net/"
    }
    homepage = {
      name = "Homepage"
      url  = "https://home.reverse-justitia.ts.net/"
    }
    golinks = {
      name = "GoLinks"
      url  = "https://go.reverse-justitia.ts.net/"
    }
    ntfy = {
      name = "ntfy"
      url  = "https://notify.reverse-justitia.ts.net/v1/health"
    }
  }
}

resource "uptimekuma_monitor_http" "apps" {
  for_each = local.apps

  name                  = each.value.name
  url                   = each.value.url
  description           = "Checks the user-facing Tailnet HTTPS route from Amalthea."
  interval              = 60
  timeout               = 20
  max_retries           = 2
  retry_interval        = 60
  resend_interval       = 0
  active                = true
  method                = "GET"
  max_redirects         = 5
  accepted_status_codes = ["200-299"]
  ignore_tls            = false
  expiry_notification   = true
  notification_ids      = [uptimekuma_notification.ntfy.id]
}

resource "uptimekuma_monitor_ping" "router" {
  name             = "Home router (aletheia)"
  description      = "Home router reachability over its stable Tailscale IP; independent of DNS."
  hostname         = "100.116.69.49"
  interval         = 60
  timeout          = 10
  max_retries      = 2
  retry_interval   = 60
  resend_interval  = 0
  active           = true
  notification_ids = [uptimekuma_notification.ntfy.id]
}

resource "uptimekuma_monitor_dns" "home" {
  name               = "Home DNS (aletheia)"
  description        = "Resolve example.com through the home router, including its upstream DNS path."
  hostname           = "example.com"
  dns_resolve_server = "100.116.69.49"
  dns_resolve_type   = "A"
  port               = 53
  interval           = 60
  max_retries        = 2
  retry_interval     = 60
  resend_interval    = 0
  active             = true
  notification_ids   = [uptimekuma_notification.ntfy.id]
}
