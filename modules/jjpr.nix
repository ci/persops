{
  lib,
  pkgs,
  ...
}:
let
  version = "0.45.1";
  jjpr = pkgs.rustPlatform.buildRustPackage {
    pname = "jjpr";
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "michaeldhopkins";
      repo = "jjpr";
      # v0.45.1, pinned by commit: upstream has rewritten history and retagged
      # before, so the tag alone could change the source.
      rev = "b116c58a0227a3b50357ad026a6a5dc5e953705f";
      hash = "sha256-3wJ7qt6xKBZKqTmXwMjHXVLf6jhVE+7vZAVajr2jDNY=";
    };

    cargoHash = "sha256-5cEhQqbo4ln5f3JoNi1hA0axqqu7mUGQ2vX5EV7tXnk=";

    # tests/mutants_run.rs runs its stub cargo and scripts/mutants-run.sh
    # through /bin/bash, which the build sandbox doesn't have.
    postPatch = ''
      substituteInPlace tests/mutants_run.rs \
        --replace-fail /bin/bash ${pkgs.bash}/bin/bash
    '';

    # Upstream has a #[should_panic] test around a debug assertion.
    checkType = "debug";

    # jj stores repo-scoped config below the user config directory. Keep tests
    # independent from the invoking user's identity and signing configuration.
    preCheck = ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      mkdir -p "$XDG_CONFIG_HOME"
    '';

    nativeCheckInputs = [
      pkgs.git
      pkgs.jujutsu
    ];

    meta = with lib; {
      description = "Manage stacked pull requests in Jujutsu repositories";
      homepage = "https://github.com/michaeldhopkins/jjpr";
      license = with licenses; [
        asl20
        mit
      ];
      mainProgram = "jjpr";
      platforms = platforms.unix;
    };
  };
in
{
  home.packages = [ jjpr ];

  xdg.configFile."jjpr/config.toml".text = ''
    merge_method = "squash"
    required_approvals = 1
    require_ci_pass = true
    reconcile_strategy = "merge"
    stack_nav = "comment"
  '';
}
