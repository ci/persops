{ lib
, buildNpmPackage
, fetchurl
, makeWrapper
, nodejs
}:

let
  pname = "osgrep";
  version = "0.5.16";
in
buildNpmPackage {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/osgrep/-/osgrep-${version}.tgz";
    hash = "sha256-V23PNxtMCdRaqr4uDOs0rptmSROUrUO7I9HazoGqUCQ=";
  };

  npmDepsHash = "sha256-rUqKWLmxsCiRo0N5BLI+LwuHeogXolLUgF9EZ5bDZoI=";
  dontNpmBuild = true;

  npmInstallFlags = [
    "--ignore-scripts"
  ];

  npmRebuildFlags = [
    "--ignore-scripts"
  ];

  postPatch = ''
    cp ${./osgrep-package-lock.json} package-lock.json
  '';

  nativeBuildInputs = [
    makeWrapper
  ];

  postInstall = ''
    makeWrapper "${nodejs}/bin/node" "$out/bin/osgrep" \
      --add-flags "$out/lib/node_modules/osgrep/dist/index.js"
  '';

  meta = with lib; {
    description = "Local grep-like search tool for your codebase";
    homepage = "https://github.com/Ryandonofrio3/osgrep";
    license = licenses.asl20;
    mainProgram = "osgrep";
    platforms = platforms.all;
  };
}
