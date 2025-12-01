{ pkgs, ... }: {
  home.file = {
    # also can use a ~/.gitconfig.local with non-committed overrides
    ".gitconfig".source = ./gitconfig;
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

