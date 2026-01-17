{ config, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
in {
  programs.fish = {
    enable = true;
    shellAliases = {
      agr = "agrind";
      git = "git-branchless wrap --";
      gdp = "git diff | pbcopy";
      gdpa = "pbpaste | git apply";
      sql2md = "pg_format --nocomment - | xargs -0 printf \"\`\`\`sql\\n%s\`\`\`\" | pbcopy";
      # emacsclient = "/opt/homebrew/bin/emacs"; # EmacsForOSX: /Applications/Emacs.app/Contents/MacOS/bin/emacsclient
      ee = "emacsclient -nw -c";
      mux = "tmuxinator";
      k = "kubectl";
      ls = "eza --all --classify";
      ll = "eza --all --group --header --group-directories-first --long --git";
      lg = "eza --all --group --header --group-directories-first --long --git --git-ignore";
      le = "eza --all --group --header --group-directories-first --long --extended";
      lt = "eza --all --group --header --group-directories-first --tree --level 2";
      magit = "ee -e '(progn (magit-status) (delete-other-windows))'";
    } // (if isLinux then {
        # just to keep it consistent
        pbcopy = "xclip";
        pbpaste = "xclip -o";
      } else {});

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
      # git worktrees
      gwl = "git worktree list";
      gwa = "git worktree add";
      gwr = "git worktree remove";
      # jj workspaces
      jwl = "jj workspace list";
      jwa = "jj workspace add";
      jwr = "jj workspace forget";
    };
    functions = {
      take = "mkdir -p $argv[1]; and cd $argv[1]";
      gwf = {
        description = "Create worktree for branch and cd into it";
        body = ''
          set branch $argv[1]
          if test -z "$branch"
            echo "Usage: gwf <branch-name>"
            return 1
          end
          set repo_name (basename (git rev-parse --show-toplevel))
          set worktree_path "../$repo_name-$branch"
          git worktree add $worktree_path $branch
          and cd $worktree_path
        '';
      };
      jwf = {
        description = "Create jj workspace and cd into it";
        body = ''
          set name $argv[1]
          set revs $argv[2..-1]
          if test -z "$name"
            echo "Usage: jwf <name> [revset...]"
            return 1
          end
          set repo_root (jj workspace root 2>/dev/null)
          if test -z "$repo_root"
            echo "Not in a jj workspace"
            return 1
          end
          set repo_name (basename $repo_root)
          set workspace_path "../$repo_name-$name"
          if test (count $revs) -gt 0
            jj workspace add --name $name -r $revs $workspace_path
          else
            jj workspace add --name $name $workspace_path
          end
          and cd $workspace_path
        '';
      };
    };
    plugins = with pkgs;
      [
        { name = "colored-man-pages"; src = fishPlugins.colored-man-pages.src; }
        { name = "done"; src = fishPlugins.done.src; }
        { name = "fzf-fish"; src = fishPlugins.fzf-fish.src; }
        { name = "puffer"; src = fishPlugins.puffer.src; }
      ];
    shellInit = ''
      fish_hybrid_key_bindings 2>/dev/null
      fish_vi_cursor

      fzf_configure_bindings --history=\cf

      set -x fish_cursor_default block
      set -x fish_cursor_insert line
      set -x fish_cursor_visual underscore

      set -x LESS '--quit-if-one-screen --ignore-case --status-column --LONG-PROMPT -R --HILITE-UNREAD --tabs=4 --no-init --window=-4'
      set -x FZF_DEFAULT_OPTS '--height "40%" --reverse --ansi --border --inline-info --tabstop=4'

      fish_config theme choose "Catppuccin Mocha"
    '' + (if isDarwin then ''
      set -gx PATH $PATH /opt/homebrew/bin

      # need this non-interactively to allow tmux to use it
      alias nixrb "sudo darwin-rebuild switch --flake ~/p/persops/"
    '' else ''
      alias nixrb "sudo nixos-rebuild switch --flake /nix-config"
    '');
  };
  xdg.configFile."fish/themes/Catppuccin Mocha.theme".source = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "fish";
    rev = "cc8e4d8fffbdaab07b3979131030b234596f18da";
    sha256 = "sha256-udiU2TOh0lYL7K7ylbt+BGlSDgCjMpy75vQ98C1kFcc=";
  } + "/themes/Catppuccin Mocha.theme";
}
