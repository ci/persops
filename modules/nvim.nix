{ config, currentSystemProfile, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = true;
    withRuby = true;
    # Do not write HM's generated init.lua into the live checkout symlink.
    sideloadInitLua = true;
    # Lets the shared live Lua config tell personal and work hosts apart.
    initLua = ''
      vim.g.persops_profile = "${currentSystemProfile}"
    '';
  };

  xdg.configFile."nvim" = {
    # Live checkout so lua edits do not need `make switch`. Requires ~/p/persops.
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/p/persops/modules/nvim";
  };
}
