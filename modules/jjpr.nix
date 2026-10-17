{
  lib,
  pkgs,
  ...
}:
let
  version = "0.39.1";
  jjpr = pkgs.rustPlatform.buildRustPackage {
    pname = "jjpr";
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "michaeldhopkins";
      repo = "jjpr";
      # v0.39.1 after upstream's history rewrite (names scrubbed from comments);
      # pinned by commit so a future retag can't change the source again.
      rev = "7bddb4ec0370cd6a9d482fe2700a371a2ae2b657";
      hash = "sha256-CShFT8/Mzdpcdu7A5MPyO6ycJnqXj8jw5w0+gXR2SeI=";
    };

    cargoHash = "sha256-yFcqPuZdFe128/X9spSosM3alkBz/uU/oteTu8kDNBY=";

    patches = [ ./jjpr-native-stack-recovery.patch ];
    patchFlags = [
      "-p1"
      "--fuzz=0"
    ];

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
