{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

let
  pname = "goplaces";
  version = "0.3.0";
in
buildGoModule {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "goplaces";
    rev = "v${version}";
    hash = "sha256-D54ybZznbc0EXNh/SqyIvfn5x3krI3G9fbXTTj1BaEs=";
  };

  subPackages = [ "cmd/goplaces" ];

  vendorHash = "sha256-OFTjLtKwYSy4tM+D12mqI28M73YJdG4DyqPkXS7ZKUg=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Fast semantic navigation and exploration for Go projects";
    homepage = "https://github.com/steipete/goplaces";
    license = licenses.mit;
    mainProgram = "goplaces";
    platforms = platforms.all;
  };
}
