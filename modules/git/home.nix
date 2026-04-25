{ pkgs, ... }: {
  home.file = {
    # also can use a ~/.gitconfig.local with non-committed overrides
    ".gitconfig".source = ./gitconfig;
  };

  # Take ownership of Git's default global excludes file.
  xdg.configFile."git/ignore" = {
    source = ./ignore;
    force = true;
  };

  home.packages = with pkgs; [
    delta
    git
    git-absorb
    git-branchless
    git-revise
    lazygit
  ];
}

