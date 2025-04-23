{ config, pkgs, ... }: {
  home.file = {
    ".emacs.d" = {
      source = pkgs.fetchFromGitHub {
        owner = "syl20bnr";
        repo = "spacemacs";
        rev = "cabcedf";
        sha256 = "D+OzpFt4mI6k+RK+hUPI9PZve6IfDZnKimtuXvl9OXE=";
      };
      recursive = true;
    };

    # mkOutOfStoreSymlink to allow spacemacs to update those files locally
    ".spacemacs".source = config.lib.file.mkOutOfStoreSymlink "/Users/cat/p/persops/modules/emacs/spacemacs";
    ".spacemacs.env".source = config.lib.file.mkOutOfStoreSymlink "/Users/cat/p/persops/modules/emacs/spacemacs.env";
  };
}
