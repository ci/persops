{ config, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = true;
    withRuby = true;
  };

  xdg.configFile."nvim" = {
    # Keep config live for iteration without `make switch`; activation requires the persops checkout at this path.
    source = config.lib.file.mkOutOfStoreSymlink (
      if pkgs.stdenv.isDarwin then
        "${config.home.homeDirectory}/p/persops/modules/nvim"
      else
        "/nix-config/modules/nvim"
    );
  };
}
