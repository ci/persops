{ lib
, buildGoModule
, fetchFromGitHub
}:

let
  pname = "blogwatcher";
  version = "0.0.2";
in
buildGoModule {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "Hyaxia";
    repo = "blogwatcher";
    rev = "v${version}";
    hash = "sha256-O9CAEJoSr6fWeznKewvEIHqW6BZiz5LI7gIp6w2SnBc=";
  };

  subPackages = [ "cmd/blogwatcher" ];

  vendorHash = "sha256-TfcMKlr/mdElYLf2zw9iNLJgGVJzMVg97jJm015ClTQ=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Monitor blogs and websites and summarize updates";
    homepage = "https://github.com/Hyaxia/blogwatcher";
    license = licenses.mit;
    mainProgram = "blogwatcher";
    platforms = platforms.all;
  };
}
