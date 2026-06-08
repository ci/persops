{
  pkgs,
  inputs,
  currentSystem,
  ...
}:
let
  yazi-plugins = inputs.nix-yazi-plugins.legacyPackages.${currentSystem};
  yazi-flavors = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "flavors";
    rev = "06708015bfb53b169d99bb3907829f9175105d57";
    sha256 = "sha256-Gm6ThktOLUR+KDs6f3s1WCgrw2TOKQ4tolVvVdCxnCM=";
  };
in
{
  imports = [
    yazi-plugins.homeManagerModules.default
  ];

  programs.yazi = {
    enable = true;
    enableFishIntegration = true; # yy wrapper for cd-on-exit
    shellWrapperName = "yy";
    settings = {
      mgr = {
        show_hidden = true;
        sort_by = "mtime";
        sort_dir_first = true;
        sort_reverse = true;
      };
    };
    theme = {
      flavor = {
        dark = "catppuccin-mocha";
      };
    };
    flavors = {
      catppuccin-mocha = "${yazi-flavors}/catppuccin-mocha.yazi";
    };
    keymap = {
      mgr.prepend_keymap = [
        # rewrite some defaults
        {
          on = "?";
          run = "help";
          desc = "Open help";
        }
        # invert zoxide and fzf
        {
          on = "z";
          run = "plugin zoxide";
          desc = "Jump to a directory via zoxide";
        }
        {
          on = "Z";
          run = "plugin fzf";
          desc = "Jump to a file/directory via fzf";
        }
        {
          on = [
            "g"
            "c"
          ];
          run = "cd ~/p/persops";
          desc = "Go to personal config";
        }
        {
          on = [
            "g"
            "p"
          ];
          run = "cd ~/p";
          desc = "Go to 'projects'";
        }
        {
          on = [
            "g"
            "t"
          ];
          run = "cd /tmp";
          desc = "Go to tmp";
        }
      ];
    };
  };

  programs.yazi.yaziPlugins = {
    enable = true;
    plugins = {
      jump-to-char = {
        enable = true;
        keys.toggle.on = [ "F" ];
      };
      relative-motions = {
        enable = true;
        show_numbers = "relative_absolute";
        show_motion = true;
      };
      ouch = {
        enable = true;
      };
      bookmarks = {
        enable = true;
        persist = "vim";
      };
    };
  };
}
