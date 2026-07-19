{
  lib,
  pkgs,
  ...
}:
let
  version = "0.34.1";
  jjpr = pkgs.rustPlatform.buildRustPackage {
    pname = "jjpr";
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "michaeldhopkins";
      repo = "jjpr";
      rev = "v${version}";
      hash = "sha256-mtOFs8slYEKOCOVVdL8IDQB0UmV6Sg9CGsTOGJETXew=";
    };

    cargoHash = "sha256-z2y2kEnlhTCRuh2vuE9bHJfUPTQjXF1kSOXYwk3guWI=";

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
