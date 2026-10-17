{
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
  # Rex Beta is installed by hand (dmg + Sparkle); no cask or nix package for macOS yet.
  # Its CLI lives in the bundle and is only on PATH inside Rex terminals.
  rexBin = "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.app/Contents/MacOS/rex";
  rex = pkgs.writeShellScriptBin "rex" ''
    if [ ! -x "${rexBin}" ]; then
      echo "rex: Rex Beta.app is not installed in /Applications" >&2
      exit 127
    fi
    exec "${rexBin}" "$@"
  '';
  hookCommand = agent: "/bin/sh -c 'rex __internal session-start --agent ${agent} 2>/dev/null || true'";
  # Same SessionStart hook `rex skill setup` writes; the skill itself is vendored in modules/ai/skills/rex.
  addHook = file: agent: ''
    rex_add_hook "${file}" ${lib.escapeShellArg (hookCommand agent)}
  '';
in
lib.mkIf isDarwin {
  home.packages = [ rex ];

  xdg.configFile."rex/init.lua".source = ./rex/init.lua;

  home.activation.rexAgentHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    rex_add_hook() {
      local file="$1" cmd="$2" tmp
      if [ -f "$file" ] && ${lib.getExe pkgs.jq} -e --arg cmd "$cmd" \
        'any(.hooks.SessionStart[]?.hooks[]?; .command == $cmd)' "$file" >/dev/null 2>&1; then
        return 0
      fi
      run mkdir -p "$(dirname "$file")"
      tmp="$(mktemp)"
      { [ -s "$file" ] && cat "$file" || echo '{}'; } |
        ${lib.getExe pkgs.jq} --arg cmd "$cmd" \
          '.hooks.SessionStart += [{hooks: [{type: "command", command: $cmd, timeout: 5}]}]' >"$tmp"
      run cp "$tmp" "$file"
      rm -f "$tmp"
    }
    ${addHook "$HOME/.claude/settings.json" "claude"}
    ${addHook "$HOME/.codex/hooks.json" "codex"}
  '';

  # Rex reads init.lua only on `rex config reload`; skip quietly when no server runs.
  home.activation.rexConfigReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -x "${rexBin}" ]; then
      run "${rexBin}" config reload --autostart=false >/dev/null 2>&1 || true
    fi
  '';
}
