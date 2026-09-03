NTFY_AUTH_USERS='cat:{{ op://Personal/ntfy-amalthea/user_password_hash }}:user,uptime-kuma:{{ op://Personal/ntfy-amalthea/uptime_kuma_password_hash }}:user'
NTFY_AUTH_ACCESS='cat:*:rw,uptime-kuma:alerts:wo'
NTFY_AUTH_TOKENS='cat:{{ op://Personal/ntfy-amalthea/user_token }}:Personal,uptime-kuma:{{ op://Personal/ntfy-amalthea/uptime_kuma_token }}:Uptime Kuma'
