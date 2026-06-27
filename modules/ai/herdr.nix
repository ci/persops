{
  pkgs,
  inputs,
  lib,
  ...
}:
let
  hostSystem = pkgs.stdenv.hostPlatform.system;
  herdrPackage = inputs.herdr.packages.${hostSystem}.default;
  herdrNavigator = pkgs.writeShellApplication {
    name = "herdr-navigator";
    runtimeInputs = [
      herdrPackage
      pkgs.jq
    ];
    text = ''
      dir="''${1:?usage: herdr-navigator <left|right|up|down>}"
      case "$dir" in
        left) key="ctrl+h" ;;
        down) key="ctrl+j" ;;
        up) key="ctrl+k" ;;
        right) key="ctrl+l" ;;
        *)
          echo "herdr-navigator: bad direction '$dir'" >&2
          exit 1
          ;;
      esac

      info="$(herdr pane process-info --current 2>/dev/null || true)"
      pane_id="$(printf '%s' "$info" | jq -r '.result.process_info.pane_id // empty' 2>/dev/null || true)"
      if [ -z "$pane_id" ]; then
        exit 0
      fi

      if printf '%s' "$info" | jq -e '
        any(.result.process_info.foreground_processes[]?;
          ((.argv0? // "") | test("(^|/)(n?vim)$"; "i")) or
          ((.name? // "") | test("^(n?vim)$"; "i"))
        )
      ' >/dev/null; then
        herdr pane send-keys "$pane_id" "$key" >/dev/null 2>&1 || true
      else
        herdr pane focus --direction "$dir" --current >/dev/null 2>&1 || true
      fi
    '';
  };
  navCommand = key: direction: {
    inherit key;
    type = "shell";
    command = "${lib.getExe herdrNavigator} ${direction}";
    description = "navigate ${direction} through vim/herdr panes";
  };
  herdrConfig = (pkgs.formats.toml { }).generate "herdr-config.toml" {
    onboarding = false;

    keys = {
      prefix = "ctrl+space";
      settings = "prefix+shift+s";
      detach = [
        "prefix+d"
        "prefix+q"
      ];
      reload_config = "prefix+r";
      goto = "prefix+g";
      workspace_picker = [
        "prefix+s"
        "prefix+w"
      ];
      resize_mode = "prefix+shift+r";
      last_pane = "prefix+space";
      rename_tab = [
        "prefix+comma"
        "prefix+shift+t"
      ];
      split_vertical = [
        "prefix+v"
        "prefix+|"
      ];

      focus_pane_left = [
        "prefix+h"
        "ctrl+alt+h"
      ];
      focus_pane_down = [
        "prefix+j"
        "ctrl+alt+j"
      ];
      focus_pane_up = [
        "prefix+k"
        "ctrl+alt+k"
      ];
      focus_pane_right = [
        "prefix+l"
        "ctrl+alt+l"
      ];

      switch_workspace = "prefix+shift+1..9";
      focus_agent = "prefix+alt+1..9";
      command = [
        (navCommand "ctrl+h" "left")
        (navCommand "ctrl+j" "down")
        (navCommand "ctrl+k" "up")
        (navCommand "ctrl+l" "right")
      ];
    };

    ui = {
      show_agent_labels_on_pane_borders = true;
      toast.delivery = "system";
    };
  };
in
{
  xdg.configFile."herdr/config.toml".source = herdrConfig;

  home.packages = [
    herdrPackage
  ];
}
