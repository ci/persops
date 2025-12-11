{ config, ... }: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  xdg.configFile."nvim" = {
    source = ./nvim;
    # source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/p/persops/modules/nvim";
    recursive = true;
  };
}
