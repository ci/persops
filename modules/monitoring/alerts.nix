let
  rule = uid: title: expr: threshold: duration: {
    inherit uid title;
    condition = "B";
    for = duration;
    noDataState = "NoData";
    execErrState = "Error";
    annotations.summary = title;
    labels = {
      host = "amalthea";
      severity = "critical";
    };
    data = [
      {
        refId = "A";
        datasourceUid = "metrics";
        relativeTimeRange = {
          from = 600;
          to = 0;
        };
        model = {
          inherit expr;
          refId = "A";
          instant = true;
          range = false;
        };
      }
      {
        refId = "B";
        datasourceUid = "__expr__";
        relativeTimeRange = {
          from = 0;
          to = 0;
        };
        model = {
          type = "threshold";
          expression = "A";
          conditions = [
            {
              evaluator = {
                type = "gt";
                params = [ threshold ];
              };
              operator.type = "and";
              reducer.type = "last";
              query.params = [ "B" ];
            }
          ];
        };
      }
    ];
  };
in
{
  rules.settings = {
    apiVersion = 1;
    groups = [
      {
        orgId = 1;
        name = "Amalthea infrastructure";
        folder = "Infrastructure";
        interval = "1m";
        rules = [
          (rule "nvme-new-errors" "NVMe media errors increased" "increase(smartctl_device_media_errors[30m])"
            0
            "0s"
          )
          # Spare is exported as a counter upstream, but decreases are degradation,
          # not counter resets. Compare its observed range without rate/increase.
          (rule "nvme-spare-drop" "NVMe spare capacity dropped"
            "max_over_time(smartctl_device_available_spare[30m]) - smartctl_device_available_spare"
            0
            "0s"
          )
          (rule "nvme-critical" "NVMe critical warning" "smartctl_device_critical_warning" 0 "0s")
          (rule "nvme-low-spare" "NVMe spare at threshold"
            "smartctl_device_available_spare_threshold - smartctl_device_available_spare"
            (-1)
            "0s"
          )
          (rule "nvme-temperature" "NVMe temperature above 70 C"
            "smartctl_device_temperature{temperature_type=\"current\"}"
            70
            "5m"
          )
          (rule "filesystem-full" "Filesystem more than 90% full"
            "100 * (1 - node_filesystem_avail_bytes{mountpoint=~\"/|/srv/sea16\"} / node_filesystem_size_bytes{mountpoint=~\"/|/srv/sea16\"})"
            90
            "10m"
          )
          (rule "memory-pressure" "Available memory below 5%"
            "100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)"
            95
            "10m"
          )
          (rule "exporter-down" "Monitoring target unavailable" "1 - up" 0 "3m")
          (rule "scheduled-job-unhealthy" "Scheduled job failed or overdue"
            "1 - persops_job_healthy{host=\"amalthea\"}"
            0
            "5m"
          )
          (rule "job-observer-stale" "Scheduled-job observer stalled"
            "time() - persops_job_observer_timestamp_seconds{host=\"amalthea\"}"
            900
            "0s"
          )
          (rule "container-missing" "Persistent container stopped reporting" (
            "1 - (max by (name) (time() - container_last_seen{host=\"amalthea\"} < bool 180) or on (name) ("
            + builtins.concatStringsSep " or " (
              map (name: "label_replace(vector(0), \"name\", \"relay-${name}-1\", \"\", \"\")") [
                "api"
                "worker"
                "gateway"
                "keycloak"
                "redis"
                "postgres"
              ]
            )
            + "))"
          ) 0 "3m")
        ];
      }
    ];
  };
  contactPoints.settings = {
    apiVersion = 1;
    contactPoints = [
      {
        orgId = 1;
        name = "ntfy";
        receivers = [
          {
            uid = "ntfy";
            type = "webhook";
            settings = {
              url = "http://127.0.0.1:2586";
              httpMethod = "POST";
              authorization_scheme = "Bearer";
              authorization_credentials = "$GRAFANA_NTFY_TOKEN";
              payload = {
                template = ''{{ coll.Dict "topic" "alerts" "title" (printf "Grafana: %s" .Status) "message" (tmpl.Exec "default.message" .) | data.ToJSON }}'';
              };
            };
          }
        ];
      }
    ];
  };
  policies.settings = {
    apiVersion = 1;
    policies = [
      {
        orgId = 1;
        receiver = "ntfy";
        group_by = [
          "alertname"
          "host"
        ];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "12h";
      }
    ];
  };
}
