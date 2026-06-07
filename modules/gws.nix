{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

let
  pname = "gws";
  version = "0.4.4";
in
rustPlatform.buildRustPackage {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "googleworkspace";
    repo = "cli";
    rev = "v${version}";
    hash = "sha256-M1Xy9nLfS+U7dDpbVhlNCGGp+K4//CJ5l10R3VVc5qo=";
  };

  cargoHash = "sha256-vK77ay23TFrT0e9G1ml3BJTh0teOsyLnd9HpESePdYo=";

  meta = with lib; {
    description = "Google Workspace CLI";
    homepage = "https://github.com/googleworkspace/cli";
    license = licenses.asl20;
    mainProgram = "gws";
    platforms = platforms.all;
  };
}
