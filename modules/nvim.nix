_: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = true;
    withRuby = true;
  };

  xdg.configFile."nvim" = {
    source = ./nvim;
    # source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/p/persops/modules/nvim";
    recursive = true;
  };
}
