{ config, ... }:
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
    # Live checkout so lua edits do not need `make switch`. Requires ~/p/persops.
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/p/persops/modules/nvim";
  };
}
