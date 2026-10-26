{
  config,
  pkgs,
  lib,
  ...
}:
let
  key = "/etc/secrets/monitoring/kuma-metrics-key";
  receiverConfig = "/etc/secrets/monitoring/receiver.yaml";
in
{
  services.onepassword-secrets.secrets.kumaMetricsKey = {
    reference = "op://persops/monitoring-amalthea/kuma_metrics_api_key";
    path = key;
    mode = "0400";
    services = [ "victoriametrics" ];
  };
  systemd.tmpfiles.rules = [ "d /etc/secrets/monitoring 0700 root root -" ];
  systemd.services.victoriametrics.serviceConfig.LoadCredential = [ "kuma-metrics-key:${key}" ];
  services.victoriametrics.prometheusConfig.scrape_configs = lib.mkAfter [
    {
      job_name = "kuma";
      basic_auth = {
        username = "metrics";
        password_file = "/run/credentials/victoriametrics.service/kuma-metrics-key";
      };
      static_configs = [
        {
          targets = [ "127.0.0.1:3001" ];
          labels.host = "amalthea";
        }
      ];
      metric_relabel_configs = [
        # Push URLs and arbitrary monitor URLs must never become metric labels.
        {
          action = "labelkeep";
          regex = "__name__|host|job|instance|monitor_name|monitor_type|monitor_id";
        }
        {
          source_labels = [ "__name__" ];
          action = "keep";
          regex = "monitor_(status|response_time|cert_days_remaining|cert_is_valid)";
        }
      ];
    }
    {
      job_name = "push-receiver";
      static_configs = [
        {
          targets = [ "127.0.0.1:8424" ];
          labels.host = "amalthea";
        }
      ];
    }
  ];
  persops.secretTemplates.metricsReceiver = {
    text = ''
      users:
        - bearer_token: "{{ op://persops/monitoring-amalthea/aglaea_push_token }}"
          name: aglaea
          max_concurrent_requests: 2
          url_map:
            - src_paths: ["/api/v1/write"]
              url_prefix: "http://127.0.0.1:8428/?extra_label=host=aglaea&extra_label=instance=aglaea&extra_label=job=node"
    '';
    path = receiverConfig;
    restartUnits = [ "metrics-receiver.service" ];
  };
  systemd.services.metrics-receiver = {
    description = "Write-only metrics receiver for personal external hosts";
    wantedBy = [ "multi-user.target" ];
    after = [ "victoriametrics.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.victoriametrics}/bin/vmauth -auth.config=%d/receiver.yaml -httpListenAddr=127.0.0.1:8423 -httpInternalListenAddr=127.0.0.1:8424 -logInvalidAuthTokens=false";
      LoadCredential = [ "receiver.yaml:${receiverConfig}" ];
      DynamicUser = true;
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };
  systemd.services.monitoring-health = {
    description = "Minimal metrics pipeline health endpoint for Pheme";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./health.py} ${toString (builtins.length config.services.victoriametrics.prometheusConfig.scrape_configs)}";
      DynamicUser = true;
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };
}
