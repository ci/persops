{
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
  # Rex Beta is installed by hand (dmg + Sparkle); no cask or nix package for macOS yet.
  # Its CLI lives in the bundle and is only on PATH inside Rex terminals. The helper
  # bundle's name changes between builds ("Rex Server.app", "Rex Server.rex"), so glob it.
  findRex = ''
    rex_bin=""
    for candidate in "/Applications/Rex Beta.app/Contents/Helpers/"*/Contents/MacOS/rex; do
      if [ -x "$candidate" ]; then
        rex_bin="$candidate"
        break
      fi
    done
  '';
  rex = pkgs.writeShellScriptBin "rex" ''
    ${findRex}
    if [ -z "$rex_bin" ]; then
      echo "rex: Rex Beta.app is not installed in /Applications" >&2
      exit 127
    fi
    exec "$rex_bin" "$@"
  '';
  # herdr's prefix+y hints picker, reading and typing through `rex` instead.
  rexHints = pkgs.writeShellApplication {
    name = "rex-hints";
    runtimeInputs = [
      rex
      pkgs.coreutils
      pkgs.fzf
      pkgs.gawk
      pkgs.gnused
      pkgs.ripgrep
    ];
    text = builtins.readFile ./ai/herdr/hints.sh;
  };
  # herdr's prefix+f project picker, with Rex sessions in place of herdr workspaces.
  rexProjectPicker = pkgs.writeShellApplication {
    name = "rex-project-picker";
    runtimeInputs = [
      rex
      pkgs.coreutils
      pkgs.fd
      pkgs.fzf
      pkgs.gawk
      pkgs.jq
    ];
    text = ''
      REX_SESSIONS_LUA=${./rex/sessions.lua}
    ''
    + builtins.readFile ./ai/herdr/project-picker.sh;
  };
  hookCommand =
    agent: "/bin/sh -c 'rex __internal session-start --agent ${agent} 2>/dev/null || true'";
  # Same SessionStart hook `rex skill setup` writes; the skill itself is vendored in modules/ai/skills/rex.
  addHook = file: agent: ''
    rex_add_hook "${file}" ${lib.escapeShellArg (hookCommand agent)}
  '';
in
lib.mkIf isDarwin {
  xdg.configFile."rex/init.lua".source = ./rex/init.lua;

  home = {
    packages = [
      rex
      rexHints
      rexProjectPicker
    ];

    activation.rexAgentHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      rex_add_hook() {
        local file="$1" cmd="$2" tmp
        if [ -f "$file" ] && ${lib.getExe pkgs.jq} -e --arg cmd "$cmd" \
          'any(.hooks.SessionStart[]?.hooks[]?; .command == $cmd)' "$file" >/dev/null 2>&1; then
          return 0
        fi
        run mkdir -p "$(dirname "$file")"
        tmp="$(mktemp)"
        if { [ -s "$file" ] && cat "$file" || echo '{}'; } |
          ${lib.getExe pkgs.jq} --arg cmd "$cmd" \
            '.hooks.SessionStart += [{hooks: [{type: "command", command: $cmd, timeout: 5}]}]' >"$tmp"; then
          run cp "$tmp" "$file"
        else
          echo "rex: could not parse $file, skipping its Rex SessionStart hook" >&2
        fi
        rm -f "$tmp"
      }
      ${addHook "$HOME/.claude/settings.json" "claude"}
      ${addHook "$HOME/.codex/hooks.json" "codex"}
    '';

    # Rex reads init.lua only on `rex config reload`; skip quietly when no server runs.
    activation.rexConfigReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${findRex}
      if [ -n "$rex_bin" ]; then
        run "$rex_bin" --autostart=false config reload >/dev/null 2>&1 || true
      fi
    '';
  };
}
