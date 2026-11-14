let
  rule =
    {
      uid,
      title,
      summary,
      description,
      expr,
      threshold,
      for ? "0s",
    }:
    {
      inherit uid title for;
      condition = "B";
      noDataState = "NoData";
      execErrState = "Error";
      # summary is the ntfy title and description its body; see ntfy.tmpl.
      annotations = { inherit summary description; };
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
  value = ''{{ printf "%.0f" $values.A.Value }}'';
  smartctl = "Check: sudo smartctl -a /dev/{{ $labels.device }}";
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
          (rule {
            uid = "nvme-new-errors";
            title = "NVMe media errors increased";
            summary = "NVMe media errors on {{ $labels.device }}";
            description = "{{ $labels.device }} logged ${value} new media errors in 30 min. ${smartctl}";
            expr = "increase(smartctl_device_media_errors{host=\"amalthea\"}[30m])";
            threshold = 0;
          })
          # Spare is exported as a counter upstream, but decreases are degradation,
          # not counter resets. Compare its observed range without rate/increase.
          (rule {
            uid = "nvme-spare-drop";
            title = "NVMe spare capacity dropped";
            summary = "NVMe spare dropped on {{ $labels.device }}";
            description = "{{ $labels.device }} available spare fell ${value} points in 30 min. ${smartctl}";
            expr = "max_over_time(smartctl_device_available_spare{host=\"amalthea\"}[30m]) - smartctl_device_available_spare{host=\"amalthea\"}";
            threshold = 0;
          })
          (rule {
            uid = "nvme-critical";
            title = "NVMe critical warning";
            summary = "NVMe critical warning on {{ $labels.device }}";
            description = "{{ $labels.device }} reports SMART critical warning ${value}. Verify backups, then ${smartctl}";
            expr = "smartctl_device_critical_warning{host=\"amalthea\"}";
            threshold = 0;
          })
          (rule {
            uid = "nvme-low-spare";
            title = "NVMe spare at threshold";
            summary = "NVMe spare at threshold on {{ $labels.device }}";
            description = "{{ $labels.device }} available spare is at or below the vendor threshold; plan a replacement. ${smartctl}";
            expr = "smartctl_device_available_spare_threshold{host=\"amalthea\"} - smartctl_device_available_spare{host=\"amalthea\"}";
            threshold = -1;
          })
          (rule {
            uid = "nvme-temperature";
            title = "NVMe temperature above 70 C";
            summary = "NVMe hot: {{ $labels.device }} at ${value} C";
            description = "{{ $labels.device }} has been above 70 C for 5 min. Check airflow and heavy writers (sudo iotop -o).";
            expr = "smartctl_device_temperature{host=\"amalthea\",temperature_type=\"current\"}";
            threshold = 70;
            for = "5m";
          })
          (rule {
            uid = "filesystem-full";
            title = "Filesystem more than 90% full";
            summary = "Disk ${value}% full: {{ $labels.mountpoint }}";
            description = "{{ $labels.mountpoint }} is ${value}% full (over 90% for 10 min). Check: sudo du -xh -d1 {{ $labels.mountpoint }} | sort -h | tail";
            expr = "100 * (1 - node_filesystem_avail_bytes{host=\"amalthea\",mountpoint=~\"/|/srv/sea16\"} / node_filesystem_size_bytes{host=\"amalthea\",mountpoint=~\"/|/srv/sea16\"})";
            threshold = 90;
            for = "10m";
          })
          (rule {
            uid = "memory-pressure";
            title = "Available memory below 5%";
            summary = "Memory ${value}% used";
            description = "Less than 5% memory available for 10 min. Check: systemd-cgtop -m";
            expr = "100 * (1 - node_memory_MemAvailable_bytes{host=\"amalthea\"} / node_memory_MemTotal_bytes{host=\"amalthea\"})";
            threshold = 95;
            for = "10m";
          })
          (rule {
            uid = "exporter-down";
            title = "Monitoring target unavailable";
            summary = "Metrics target down: {{ $labels.job }}";
            description = "{{ $labels.job }} on {{ $labels.instance }} has failed scrapes for 3 min. Check: curl -s http://{{ $labels.instance }}/metrics | head";
            expr = "1 - up{host=\"amalthea\"}";
            threshold = 0;
            for = "3m";
          })
          (rule {
            uid = "scheduled-job-unhealthy";
            title = "Scheduled job failed or overdue";
            summary = "Job failing: {{ $labels.scheduled_job }}";
            description = "{{ $labels.unit }} failed its last run or is overdue. Check: journalctl -u {{ $labels.unit }} -n 50";
            expr = "1 - persops_job_healthy{host=\"amalthea\"}";
            threshold = 0;
            for = "5m";
          })
          (rule {
            uid = "job-observer-stale";
            title = "Scheduled-job observer stalled";
            summary = "Job observer stalled";
            description = "kuma-job-health last wrote metrics ${value}s ago, so job alerts are blind. Check: journalctl -u kuma-job-health -n 50";
            expr = "time() - persops_job_observer_timestamp_seconds{host=\"amalthea\"}";
            threshold = 900;
          })
          (rule {
            uid = "container-missing";
            title = "Persistent container stopped reporting";
            summary = "Container down: {{ $labels.name }}";
            description = "{{ $labels.name }} has not been seen for 3 min. Check: docker ps -a -f name={{ $labels.name }}; docker logs --tail 50 {{ $labels.name }}";
            expr =
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
              + "))";
            threshold = 0;
            for = "3m";
          })
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
                # ntfy's JSON API wants priority as a number, so set it outside tmpl.Exec.
                # Contact-point provisioning expands $VAR (see the token above): $$ is a literal $.
                template = ''
                  {{- $$priority := 2 }}{{ $$tag := "white_check_mark" }}
                  {{- if eq .Status "firing" }}{{ $$priority = 4 }}{{ $$tag = "rotating_light" }}{{ end }}
                  {{- coll.Dict "topic" "alerts" "title" (tmpl.Exec "ntfy.title" .) "message" (tmpl.Exec "ntfy.message" .) "priority" $$priority "tags" (coll.Slice $$tag) "click" (tmpl.Exec "ntfy.click" .) | data.ToJSON -}}
                '';
              };
            };
          }
        ];
      }
    ];
  };
  templates.settings = {
    apiVersion = 1;
    templates = [
      {
        orgId = 1;
        name = "ntfy";
        template = builtins.readFile ./ntfy.tmpl;
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
