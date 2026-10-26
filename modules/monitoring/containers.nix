{ lib, ... }:
let
  names = "relay-(api|worker|gateway|keycloak|redis|postgres)-1";
in
{
  services.cadvisor = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9280;
    extraOptions = [
      "--docker_only=true"
      "--disable_root_cgroup_stats=true"
      "--store_container_labels=false"
      "--housekeeping_interval=30s"
      "--enable_metrics=cpu,memory,network"
    ];
  };
  systemd.services.cadvisor.serviceConfig.Restart = "on-failure";
  services.victoriametrics.prometheusConfig.scrape_configs = lib.mkAfter [
    {
      job_name = "containers";
      static_configs = [
        {
          targets = [ "127.0.0.1:9280" ];
          labels.host = "amalthea";
        }
      ];
      metric_relabel_configs = [
        {
          source_labels = [ "name" ];
          action = "keep";
          regex = names;
        }
        {
          source_labels = [ "__name__" ];
          action = "keep";
          regex = "container_(cpu_usage_seconds_total|memory_working_set_bytes|memory_usage_bytes|spec_memory_limit_bytes|network_receive_bytes_total|network_transmit_bytes_total|last_seen|start_time_seconds)";
        }
        {
          action = "labeldrop";
          regex = "id|image";
        }
      ];
    }
  ];
}
