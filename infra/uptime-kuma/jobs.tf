locals {
  jobs = jsondecode(file("${path.module}/jobs.json"))
}

resource "uptimekuma_monitor_push" "jobs" {
  for_each = local.jobs

  name             = each.value.name
  description      = "Read-only systemd health: latest run successful, enabled timer, success within 26 hours. Checker reports every 5 minutes."
  interval         = 900
  max_retries      = 0
  retry_interval   = 60
  resend_interval  = 0
  active           = true
  notification_ids = [uptimekuma_notification.ntfy.id]
}

output "job_push_tokens" {
  description = "Install with scripts/kuma-job-secrets-install; never put tokens in Nix or Git."
  value       = { for key, monitor in uptimekuma_monitor_push.jobs : key => monitor.push_token }
  sensitive   = true
}
