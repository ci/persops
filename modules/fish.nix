{ pkgs, ... }: {
  programs.fish = {
    enable = true;
    shellAliases = {
      agr = "agrind";
      gdp = "git diff | pbcopy";
      gdpa = "pbpaste | git apply";
      sql2md = "pg_format --nocomment - | xargs -0 printf \"\`\`\`sql\\n%s\`\`\`\" | pbcopy";
      emacsclient = "/opt/homebrew/bin/emacs"; # EmacsForOSX: /Applications/Emacs.app/Contents/MacOS/bin/emacsclient
      ee = "emacsclient -nw"; # -c
      mux = "tmuxinator";
      k = "kubectl";
      l = "exa --classify --group-directories-first";
      ll = "exa --git --long --header --classify --group-directories-first";
      nixrb = "darwin-rebuild switch --flake ~/p/persops/";
    };
    shellAbbrs = {
      g = "git";
      ga = "git add";
      gst = "git status";
      gs = "git status -s";
      gco = "git checkout";
      gcb = "git checkout -b";
      gc = "git commit";
      gcm = "git commit -m";
      gd = "git diff";
      gp = "git push";
      gpf = "git push --force-with-lease";
      gl = "git pull";
      gdm = "git delete-merged-branches";
      glg = "git log";
      glg1 = "git log --oneline";
      gf = "git fetch --tags --force --prune";
      be = "bundle exec";
      rcop = "bundle exec rubocop";
    };
    functions = {
      take = "mkdir -p $argv[1]; and cd $argv[1]";
      extract = {
        description = "Expand or extract bundled & compressed files";
        # https://github.com/oh-my-fish/plugin-extract/blob/master/functions/extract.fish
        body = ''
          set --local ext (echo $argv[1] | awk -F. '{print $NF}')
          switch $ext
            case tar  # non-compressed, just bundled
              tar -xvf $argv[1]
            case gz
              if test (echo $argv[1] | awk -F. '{print $(NF-1)}') = tar  # tar bundle compressed with gzip
                tar -zxvf $argv[1]
              else  # single gzip
                gunzip $argv[1]
              end
            case tgz  # same as tar.gz
              tar -zxvf $argv[1]
            case bz2  # tar compressed with bzip2
              tar -jxvf $argv[1]
            case rar
              unrar x $argv[1]
            case zip
              unzip $argv[1]
            case '*'
              echo "unknown extension"
          end
        '';
      };
    };
    plugins = with pkgs;
    [
      { name = "colored-man-pages"; src = fishPlugins.colored-man-pages.src; }
      { name = "done"; src = fishPlugins.done.src; }
      { name = "fzf"; src = fishPlugins.fzf.src; }
      { name = "puffer"; src = fishPlugins.puffer.src; }
      { name = "z"; src = fishPlugins.z.src; }
    ];
    shellInit = ''
      set -U Z_CMD "j"

      fish_hybrid_key_bindings 2>/dev/null
      fish_vi_cursor

      set -x fish_cursor_default block
      set -x fish_cursor_insert line
      set -x fish_cursor_visual underscore

      set -x LESS '--quit-if-one-screen --ignore-case --status-column --LONG-PROMPT -R --HILITE-UNREAD --tabs=4 --no-init --window=-4'
      set -x FZF_DEFAULT_OPTS '--height "40%" --reverse --ansi --border --inline-info --tabstop=4'

      fish_config theme choose "Catppuccin Mocha"
    '';
  };
  xdg.configFile."fish/themes/Catppuccin Mocha.theme".source = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "fish";
    rev = "cc8e4d8fffbdaab07b3979131030b234596f18da";
    sha256 = "sha256-udiU2TOh0lYL7K7ylbt+BGlSDgCjMpy75vQ98C1kFcc=";
  } + "/themes/Catppuccin Mocha.theme";
}
