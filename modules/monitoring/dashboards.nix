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
        title = "Uptime Kuma";
        url = "https://uptime.reverse-justitia.ts.net/";
        type = "link";
      }
    ];
  };
  overview = dashboard "amalthea-overview" "Amalthea overview" [
    (panel 1 "CPU busy" "100 * (1 - avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])))" "percent"
      "stat"
      0
      0
      6
    )
    (panel 2 "Memory used" "100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)"
      "percent"
      "stat"
      6
      0
      6
    )
    (panel 3 "Uptime" "time() - node_boot_time_seconds" "s" "stat" 12 0 6)
    (panel 4 "Scrape targets up" "sum(up)" "short" "stat" 18 0 6)
    (panel 5 "CPU busy over time" "100 * (1 - avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])))"
      "percent"
      "timeseries"
      0
      7
      12
    )
    (panel 6 "Memory and swap used"
      "{__name__=~\"node_memory_(MemTotal|MemAvailable|SwapTotal|SwapFree)_bytes\"}"
      "bytes"
      "timeseries"
      12
      7
      12
    )
    (panel 7 "Filesystem available" "node_filesystem_avail_bytes{mountpoint=~\"/|/srv/sea16\"}" "bytes"
      "timeseries"
      0
      14
      12
    )
    (panel 8 "Service active (1 = running)" "node_systemd_unit_state{state=\"active\"}" "short"
      "timeseries"
      12
      14
      12
    )
    (panel 9 "Disk reads / writes" [
      {
        expr = "rate(node_disk_read_bytes_total[5m])";
        legend = "Read {{device}}";
      }
      {
        expr = "rate(node_disk_written_bytes_total[5m])";
        legend = "Write {{device}}";
      }
    ] "Bps" "timeseries" 0 21 12)
    (panel 10 "Network receive / transmit" [
      {
        expr = "rate(node_network_receive_bytes_total{device!~\"lo|veth.*|br-.*|docker.*\"}[5m])";
        legend = "Receive {{device}}";
      }
      {
        expr = "rate(node_network_transmit_bytes_total{device!~\"lo|veth.*|br-.*|docker.*\"}[5m])";
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
    (condition (panel 2 "NVMe available spare" "smartctl_device_available_spare" "percent" "stat" 0 3 6)
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
    (condition (panel 3 "Accumulated media errors" "smartctl_device_media_errors" "short" "stat" 6 3 6)
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
    (panel 4 "NVMe temperature" "smartctl_device_temperature{temperature_type=\"current\"}" "celsius"
      "stat"
      12
      3
      6
    )
    (panel 5 "Endurance used" "smartctl_device_percentage_used" "percent" "stat" 18 3 6)
    (panel 6 "Spare / failure threshold" "{__name__=~\"smartctl_device_available_spare(_threshold)?\"}"
      "percent"
      "timeseries"
      0
      10
      12
    )
    (panel 7 "Media errors (cumulative)" "smartctl_device_media_errors" "short" "timeseries" 12 10 12)
    (panel 8 "Filesystem available" "node_filesystem_avail_bytes{mountpoint=~\"/|/srv/sea16\"}" "bytes"
      "timeseries"
      0
      17
      12
    )
    (panel 9 "NVMe average I/O latency"
      "rate(node_disk_read_time_seconds_total{device=\"nvme0n1\"}[5m]) / clamp_min(rate(node_disk_reads_completed_total{device=\"nvme0n1\"}[5m]), 0.001)"
      "s"
      "timeseries"
      12
      17
      12
    )
  ];
in
pkgs.linkFarm "monitoring-dashboards" [
  {
    name = "overview.json";
    path = pkgs.writeText "overview.json" (builtins.toJSON overview);
  }
  {
    name = "storage.json";
    path = pkgs.writeText "storage.json" (builtins.toJSON storage);
  }
]
