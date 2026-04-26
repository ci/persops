{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    mise
  ];

  xdg.configFile."mise/config.toml".source = ./mise.toml;

  programs = {
    bash.initExtra = ''
      eval "$(${lib.getExe pkgs.mise} activate bash)"
    '';

    fish.interactiveShellInit = lib.mkAfter ''
      ${lib.getExe pkgs.mise} activate fish | source
      fish_add_path --global --path "$HOME/.local/share/pnpm" "$HOME/.npm-global/bin" "$HOME/go/bin" "$HOME/p/posthog/tools/infra-scripts/mcp"
    '';

    fish.shellInit = lib.mkAfter ''
      ${lib.getExe pkgs.mise} activate fish --shims | source
      fish_add_path --global --path "$HOME/.local/share/pnpm" "$HOME/.npm-global/bin" "$HOME/go/bin" "$HOME/p/posthog/tools/infra-scripts/mcp"
    '';
  };
}
