{ pkgs }:
let
  panel = id: title: expr: unit: type: x: y: w: {
    inherit id title type;
    gridPos = {
      inherit x y w;
      h = 7;
    };
    datasource = {
      type = "prometheus";
      uid = "metrics";
    };
    targets = pkgs.lib.imap0 (index: query: {
      refId = "A${toString index}";
      expr = if builtins.isString query then query else query.expr;
      instant = type == "stat";
      range = type != "stat";
      legendFormat =
        if builtins.isString query then "{{__name__}} {{device}}{{mountpoint}}{{name}}" else query.legend;
    }) (if builtins.isList expr then expr else [ expr ]);
    fieldConfig.defaults = {
      inherit unit;
      color.mode = "palette-classic";
      thresholds = {
        mode = "absolute";
        steps = [
          {
            color = "green";
            value = null;
          }
        ];
      };
    };
    options =
      if type == "stat" then
        {
          reduceOptions.calcs = [ "lastNotNull" ];
          colorMode = "value";
          graphMode = "area";
        }
      else
        {
          legend = {
            displayMode = "list";
            placement = "bottom";
          };
        };
  };
  condition =
    item: steps:
    item
    // {
      fieldConfig.defaults = item.fieldConfig.defaults // {
        color.mode = "thresholds";
        thresholds = {
          mode = "absolute";
          inherit steps;
        };
      };
    };
  dashboard = uid: title: panels: {
    inherit uid title panels;
    schemaVersion = 39;
    editable = false;
    refresh = "1m";
    timezone = "browser";
    time = {
      from = "now-6h";
      to = "now";
    };
    links = [
      {
        title = "Overview";
        url = "/grafana/d/amalthea-overview/amalthea-overview";
        type = "link";
      }
      {
        title = "Storage";
        url = "/grafana/d/amalthea-storage/amalthea-storage";
        type = "link";
      }
      {
        title = "Jobs and containers";
        url = "/grafana/d/amalthea-operations/amalthea-jobs-and-containers";
        type = "link";
      }
      {
        title = "Availability and Aglaea";
        url = "/grafana/d/external-monitoring/availability-and-aglaea";
        type = "link";
      }
      {
        title = "Uptime Kuma";
        url = "https://uptime.reverse-justitia.ts.net/";
        type = "link";
      }
    ];
  };
  external = dashboard "external-monitoring" "Availability and Aglaea" [
    {
      id = 1;
      type = "text";
      title = "Availability and laptop reporting";
      gridPos = {
        x = 0;
        y = 0;
        w = 24;
        h = 3;
      };
      options = {
        mode = "markdown";
        content = "Kuma status: 0 down, 1 up, 2 pending, 3 maintenance. Kuma owns availability notifications. Aglaea may sleep or disconnect: offline is expected and does not alert. Current hardware panels disappear after telemetry expires; last sample age retains up to 30 days of evidence. Its clock must be correct.";
      };
    }
    (panel 2 "Kuma availability" [
      {
        expr = "monitor_status{host=\"amalthea\"}";
        legend = "{{monitor_name}}";
      }
    ] "short" "timeseries" 0 3 12)
    (panel 3 "Kuma response time" [
      {
        expr = "monitor_response_time{host=\"amalthea\"}";
        legend = "{{monitor_name}}";
      }
    ] "ms" "timeseries" 12 3 12)
    (panel 4 "Aglaea reporting (1 = within 3 minutes)"
      "max((time() - last_over_time(node_time_seconds{host=\"aglaea\"}[30d]) < bool 180) * (time() - last_over_time(node_time_seconds{host=\"aglaea\"}[30d]) >= bool 0)) or vector(0)"
      "short"
      "stat"
      0
      10
      8
    )
    (panel 5 "Aglaea last sample age" "time() - last_over_time(node_time_seconds{host=\"aglaea\"}[30d])"
      "s"
      "stat"
      8
      10
      8
    )
    (panel 6 "Aglaea uptime" "time() - node_boot_time_seconds{host=\"aglaea\"}" "s" "stat" 16 10 8)
    (panel 7 "Aglaea CPU busy"
      "100 * (1 - avg(rate(node_cpu_seconds_total{host=\"aglaea\",mode=\"idle\"}[5m])))"
      "percent"
      "timeseries"
      0
      17
      12
    )
    (panel 8 "Aglaea memory" [
      {
        expr = "{host=\"aglaea\",__name__=~\"node_memory_(active|wired|compressed|free|total)_bytes\"}";
        legend = "{{__name__}}";
      }
    ] "bytes" "timeseries" 12 17 12)
    (panel 9 "Aglaea filesystem available" "node_filesystem_avail_bytes{host=\"aglaea\"}" "bytes"
      "timeseries"
      0
      24
      12
    )
    (panel 10 "Certificate days remaining" [
      {
        expr = "monitor_cert_days_remaining{host=\"amalthea\"}";
        legend = "{{monitor_name}}";
      }
    ] "d" "stat" 12 24 12)
  ];
  overview = dashboard "amalthea-overview" "Amalthea overview" [
    (panel 1 "CPU busy"
      "100 * (1 - avg(rate(node_cpu_seconds_total{host=\"amalthea\",mode=\"idle\"}[5m])))"
      "percent"
      "stat"
      0
      0
      6
    )
    (panel 2 "Memory used"
      "100 * (1 - node_memory_MemAvailable_bytes{host=\"amalthea\"} / node_memory_MemTotal_bytes{host=\"amalthea\"})"
      "percent"
      "stat"
      6
      0
      6
    )
    (panel 3 "Uptime" "time() - node_boot_time_seconds{host=\"amalthea\"}" "s" "stat" 12 0 6)
    (panel 4 "Scrape targets up" "sum(up{host=\"amalthea\"})" "short" "stat" 18 0 6)
    (panel 5 "CPU busy over time"
      "100 * (1 - avg(rate(node_cpu_seconds_total{host=\"amalthea\",mode=\"idle\"}[5m])))"
      "percent"
      "timeseries"
      0
      7
      12
    )
    (panel 6 "Memory and swap used"
      "{host=\"amalthea\",__name__=~\"node_memory_(MemTotal|MemAvailable|SwapTotal|SwapFree)_bytes\"}"
      "bytes"
      "timeseries"
      12
      7
      12
    )
    (panel 7 "Filesystem available"
      "node_filesystem_avail_bytes{host=\"amalthea\",mountpoint=~\"/|/srv/sea16\"}"
      "bytes"
      "timeseries"
      0
      14
      12
    )
    (panel 8 "Service active (1 = running)"
      "node_systemd_unit_state{host=\"amalthea\",state=\"active\"}"
      "short"
      "timeseries"
      12
      14
      12
    )
    (panel 9 "Disk reads / writes" [
      {
        expr = "rate(node_disk_read_bytes_total{host=\"amalthea\"}[5m])";
        legend = "Read {{device}}";
      }
      {
        expr = "rate(node_disk_written_bytes_total{host=\"amalthea\"}[5m])";
        legend = "Write {{device}}";
      }
    ] "Bps" "timeseries" 0 21 12)
    (panel 10 "Network receive / transmit" [
      {
        expr = "rate(node_network_receive_bytes_total{host=\"amalthea\",device!~\"lo|veth.*|br-.*|docker.*\"}[5m])";
        legend = "Receive {{device}}";
      }
      {
        expr = "rate(node_network_transmit_bytes_total{host=\"amalthea\",device!~\"lo|veth.*|br-.*|docker.*\"}[5m])";
        legend = "Transmit {{device}}";
      }
    ] "Bps" "timeseries" 12 21 12)
  ];
  storage = dashboard "amalthea-storage" "Amalthea storage" [
    {
      id = 1;
      type = "text";
      title = "Drive condition and monitoring limits";
      gridPos = {
        x = 0;
        y = 0;
        w = 24;
        h = 3;
      };
      options = {
        mode = "markdown";
        content = "**Existing media errors remain significant even when SMART passes.** Alerts detect new errors, falling spare, critical warnings and missing telemetry. USB disk coverage here is filesystem capacity; the existing Kuma archive probe checks mount health. SMART data is collected only for the internal NVMe.";
      };
    }
    (condition
      (panel 2 "NVMe available spare" "smartctl_device_available_spare{host=\"amalthea\"}" "percent"
        "stat"
        0
        3
        6
      )
      [
        {
          color = "red";
          value = null;
        }
        {
          color = "orange";
          value = 11;
        }
        {
          color = "green";
          value = 100;
        }
      ]
    )
    (condition
      (panel 3 "Accumulated media errors" "smartctl_device_media_errors{host=\"amalthea\"}" "short" "stat"
        6
        3
        6
      )
      [
        {
          color = "green";
          value = null;
        }
        {
          color = "orange";
          value = 1;
        }
      ]
    )
    (panel 4 "NVMe temperature"
      "smartctl_device_temperature{host=\"amalthea\",temperature_type=\"current\"}"
      "celsius"
      "stat"
      12
      3
      6
    )
    (panel 5 "Endurance used" "smartctl_device_percentage_used{host=\"amalthea\"}" "percent" "stat" 18 3
      6
    )
    (panel 6 "Spare / failure threshold"
      "{host=\"amalthea\",__name__=~\"smartctl_device_available_spare(_threshold)?\"}"
      "percent"
      "timeseries"
      0
      10
      12
    )
    (panel 7 "Media errors (cumulative)" "smartctl_device_media_errors{host=\"amalthea\"}" "short"
      "timeseries"
      12
      10
      12
    )
    (panel 8 "Filesystem available"
      "node_filesystem_avail_bytes{host=\"amalthea\",mountpoint=~\"/|/srv/sea16\"}"
      "bytes"
      "timeseries"
      0
      17
      12
    )
    (panel 9 "NVMe average I/O latency"
      "rate(node_disk_read_time_seconds_total{host=\"amalthea\",device=\"nvme0n1\"}[5m]) / clamp_min(rate(node_disk_reads_completed_total{host=\"amalthea\",device=\"nvme0n1\"}[5m]), 0.001)"
      "s"
      "timeseries"
      12
      17
      12
    )
  ];
  operations = dashboard "amalthea-operations" "Amalthea jobs and containers" [
    (panel 1 "Scheduled-job health (1 = healthy)" [
      {
        expr = "persops_job_healthy{host=\"amalthea\"}";
        legend = "{{scheduled_job}}";
      }
    ] "short" "timeseries" 0 0 12)
    (panel 2 "Time since successful completion" [
      {
        expr = "time() - (persops_job_last_success_timestamp_seconds{host=\"amalthea\"} > 0)";
        legend = "{{scheduled_job}}";
      }
    ] "s" "stat" 12 0 12)
    (panel 3 "Observer age (seconds; should stay below 900)"
      "time() - persops_job_observer_timestamp_seconds{host=\"amalthea\"}"
      "s"
      "stat"
      0
      7
      6
    )
    (panel 4 "Persistent containers reporting (expected 6)"
      "count(time() - container_last_seen{host=\"amalthea\"} < 180) or vector(0)"
      "short"
      "stat"
      6
      7
      6
    )
    (panel 5 "Jobs without success evidence" [
      {
        expr = "persops_job_last_success_timestamp_seconds{host=\"amalthea\"} == bool 0";
        legend = "{{scheduled_job}}";
      }
    ] "short" "stat" 12 7 12)
    (panel 6 "Container CPU cores" [
      {
        expr = "sum by (name) (rate(container_cpu_usage_seconds_total{host=\"amalthea\",cpu=\"total\"}[5m]))";
        legend = "{{name}}";
      }
    ] "short" "timeseries" 0 14 12)
    (panel 7 "Container working memory" "container_memory_working_set_bytes{host=\"amalthea\"}" "bytes"
      "timeseries"
      12
      14
      12
    )
    (panel 8 "Container starts observed in 24h"
      "changes(container_start_time_seconds{host=\"amalthea\"}[24h])"
      "short"
      "stat"
      0
      21
      12
    )
    (panel 9 "Container network" [
      {
        expr = "sum by (name) (rate(container_network_receive_bytes_total{host=\"amalthea\"}[5m]))";
        legend = "Receive {{name}}";
      }
      {
        expr = "sum by (name) (rate(container_network_transmit_bytes_total{host=\"amalthea\"}[5m]))";
        legend = "Transmit {{name}}";
      }
    ] "Bps" "timeseries" 12 21 12)
  ];
in
pkgs.linkFarm "monitoring-dashboards" [
  {
    name = "external.json";
    path = pkgs.writeText "external.json" (builtins.toJSON external);
  }
  {
    name = "overview.json";
    path = pkgs.writeText "overview.json" (builtins.toJSON overview);
  }
  {
    name = "storage.json";
    path = pkgs.writeText "storage.json" (builtins.toJSON storage);
  }
  {
    name = "operations.json";
    path = pkgs.writeText "operations.json" (builtins.toJSON operations);
  }
]
