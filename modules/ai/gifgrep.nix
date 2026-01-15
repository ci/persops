{ lib
, buildGoModule
, fetchFromGitHub
}:

let
  pname = "gifgrep";
  version = "0.2.1";
in
buildGoModule {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "gifgrep";
    rev = "v${version}";
    hash = "sha256-G4v4bhtjHAQzxeTl6TTXvGbHo8HCqI81C0ojm2E7zBk=";
  };

  subPackages = [ "cmd/gifgrep" ];

  vendorHash = "sha256-IBChugE0+ELHgeTZ8kXi5FH7CHB1chvt56/3Lhm1TiI=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Search text in GIFs";
    homepage = "https://github.com/steipete/gifgrep";
    license = licenses.mit;
    mainProgram = "gifgrep";
    platforms = platforms.all;
  };
}
