{ config, pkgs, ... }:
let
  dashboards = import ./dashboards.nix { inherit pkgs; };
  databasePath = config.services.grafana.settings.database.path;
  queryProxyConfig = (pkgs.formats.yaml { }).generate "grafana-metrics-proxy.yaml" {
    unauthorized_user.url_map = [
      {
        src_paths = [
          "/api/v1/(query|query_range|query_exemplars|series|labels|metadata|status/buildinfo|status/flags|format_query)"
          "/api/v1/label/[^/]+/values"
        ];
        url_prefix = "http://127.0.0.1:8428";
      }
    ];
  };
  checkedQueryProxyConfig = pkgs.runCommand "checked-grafana-metrics-proxy.yaml" { } ''
    ${pkgs.victoriametrics}/bin/vmauth -dryRun -auth.config=${queryProxyConfig}
    cp ${queryProxyConfig} "$out"
  '';
  initializeKey = pkgs.writeShellScript "grafana-initialize-key" ''
    set -eu
    cd "$1"
    if [ ! -s encryption-key ]; then
      # Losing an existing database's key requires recovery, not a new key.
      test ! -e ${pkgs.lib.escapeShellArg databasePath}
      umask 077
      ${pkgs.openssl}/bin/openssl rand -hex 32 > encryption-key.new
      mv encryption-key.new encryption-key
    fi
  '';
in
{
  services.victoriametrics = {
    enable = true;
    listenAddress = "127.0.0.1:8428";
    retentionPeriod = "30d";
    extraOptions = [
      "-storage.minFreeDiskSpaceBytes=10GiB"
      "-memory.allowedBytes=512MiB"
    ];
    prometheusConfig = {
      global.scrape_interval = "60s";
      scrape_configs =
        map
          ({ name, port }: {
            job_name = name;
            static_configs = [
              {
                targets = [ "127.0.0.1:${toString port}" ];
                labels.host = "amalthea";
              }
            ];
            metric_relabel_configs = [
              {
                action = "labeldrop";
                regex = "serial_number";
              }
            ];
          })
          [
            {
              name = "node";
              port = 9100;
            }
            {
              name = "smartctl";
              port = 9633;
            }
            {
              name = "victoriametrics";
              port = 8428;
            }
            {
              name = "query-proxy";
              port = 8426;
            }
            {
              name = "grafana";
              port = 3002;
            }
            {
              name = "ntfy";
              port = 2587;
            }
          ];
    };
  };

  # Grafana's Viewer proxy permits GET bodies. Keep ingestion/admin paths out
  # of its datasource, and keep vmauth's own admin API on a separate listener.
  systemd.services.grafana-metrics-proxy = {
    description = "Read-only metrics API for Grafana";
    wantedBy = [ "multi-user.target" ];
    wants = [ "victoriametrics.service" ];
    after = [ "victoriametrics.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.victoriametrics}/bin/vmauth -auth.config=${checkedQueryProxyConfig} -httpListenAddr=127.0.0.1:8427 -httpInternalListenAddr=127.0.0.1:8426";
      DynamicUser = true;
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      listenAddress = "127.0.0.1";
      enabledCollectors = [ "systemd" ];
      extraFlags = [
        "--collector.systemd.enable-restarts-metrics"
        "--collector.systemd.unit-include=(actual|cliproxyapi|docker|golink|grafana|grafana-metrics-proxy|home-assistant|homepage-dashboard|nix-daemon|ntfy-sh|samba-smbd|sshd|tailscaled|uptime-kuma|victoriametrics|prometheus-.*-exporter).service"
      ];
    };
    smartctl = {
      enable = true;
      listenAddress = "127.0.0.1";
      # The NVMe namespace is disk-group-readable; the controller is root-only.
      # Explicit selection keeps sleeping USB disks out of discovery.
      devices = [ "/dev/nvme0n1" ];
      maxInterval = "60s";
    };
  };

  services.ntfy-sh.settings.metrics-listen-http = "127.0.0.1:2587";

  persops.secretTemplates.grafanaEnv = {
    text = ''
      GRAFANA_NTFY_TOKEN={{ op://persops/ntfy-amalthea/uptime_kuma_token }}
    '';
    path = "/etc/secrets/grafana/environment";
    restartUnits = [ "grafana.service" ];
  };
  systemd.tmpfiles.rules = [
    "d /etc/secrets/grafana 0700 root root -"
    "d /var/backup/grafana 0700 root root -"
  ];
  systemd.services.grafana.serviceConfig.EnvironmentFile = "/etc/secrets/grafana/environment";
  systemd.services.grafana.serviceConfig.ExecStartPre = [
    "${initializeKey} /var/lib/grafana"
  ];

  services.grafana = {
    enable = true;
    settings = {
      database.path = "/var/lib/grafana/grafana.db";
      plugins.preinstall_disabled = true;
      server = {
        http_addr = "127.0.0.1";
        http_port = 3002;
        root_url = "https://home.reverse-justitia.ts.net/grafana/";
        # Tailscale Serve strips /grafana before forwarding.
        serve_from_sub_path = false;
      };
      security = {
        secret_key = "$__file{/var/lib/grafana/encryption-key}";
        disable_initial_admin_creation = true;
        cookie_secure = true;
        disable_gravatar = true;
      };
      auth = {
        disable_login_form = true;
        disable_signout_menu = true;
      };
      "auth.basic".enabled = false;
      "auth.proxy" = {
        enabled = true;
        header_name = "Tailscale-User-Login";
        header_property = "username";
        auto_sign_up = true;
        whitelist = "127.0.0.1";
        headers = "Name:Tailscale-User-Name";
      };
      users = {
        allow_sign_up = false;
        allow_org_create = false;
        auto_assign_org_role = "Viewer";
        default_theme = "dark";
        home_page = "/d/amalthea-overview/amalthea-overview";
      };
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
      };
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "VictoriaMetrics";
          uid = "metrics";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:8427";
          isDefault = true;
          editable = false;
          jsonData = {
            timeInterval = "60s";
            httpMethod = "POST";
          };
        }
      ];
      dashboards.settings.providers = [
        {
          name = "persops";
          options.path = dashboards;
          disableDeletion = false;
        }
      ];
      alerting = import ./alerts.nix;
    };
  };

  services.restic.backups.monitoring-daily = {
    inherit (config.services.restic.backups.actual-daily)
      user
      repository
      passwordFile
      environmentFile
      extraOptions
      ;
    initialize = false;
    paths = [
      "/var/backup/grafana"
      "/var/lib/nvme-health"
    ];
    backupPrepareCommand = ''
      set -eu
      ${pkgs.sqlite}/bin/sqlite3 -readonly ${pkgs.lib.escapeShellArg databasePath} ".backup '/var/backup/grafana/grafana.db'"
      ${pkgs.coreutils}/bin/install -m 0600 /var/lib/grafana/encryption-key /var/backup/grafana/encryption-key
    '';
    extraBackupArgs = [
      "--host"
      "amalthea"
      "--tag"
      "monitoring"
    ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
