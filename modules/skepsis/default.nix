{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  git,
  jujutsu,
  makeWrapper,
  nodejs_22,
  stdenv,
  tsx,
  xdg-utils,
}:

buildNpmPackage rec {
  pname = "skepsis";
  version = "unstable-2026-04-29";

  src = fetchFromGitHub {
    owner = "oxidecomputer";
    repo = "skepsis";
    rev = "5130471eb908ccaecb31c6c8b2cc2282439db897";
    hash = "sha256-ovFeshhlkCEnds8sPDsyLf61J9AeO3NJgoIIxHyfuCU=";
  };

  nodejs = nodejs_22;
  nativeBuildInputs = [ makeWrapper ];

  # Upstream's lockfile omits registry metadata for some entries, which breaks
  # Nix's offline npm fetcher. Use the same locked versions with metadata filled in.
  postPatch = ''
      cp ${./package-lock.json} package-lock.json
      substituteInPlace package.json \
        --replace-fail '"name": "skepsis",' '"name": "skepsis",
    "version": "${version}",'
  '';

  # The production bundle is checked in upstream; no Vite build needed here.
  dontNpmBuild = true;
  npmInstallFlags = [ "--omit=dev" ];
  npmPruneFlags = [ "--omit=dev" ];
  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-AEtSPKD4Kgxh3psX6Ew4HrqeCCJpIb2mUSIowcz1Qsk=";

  postInstall =
    let
      runtimePath = lib.makeBinPath (
        [
          git
          jujutsu
        ]
        ++ lib.optionals stdenv.isLinux [ xdg-utils ]
      );
    in
    ''
      mkdir -p $out/bin
      makeWrapper ${lib.getExe tsx} $out/bin/skepsis \
        --add-flags "$out/lib/node_modules/skepsis/cli.ts" \
        --prefix PATH : ${runtimePath}
      ln -s skepsis $out/bin/sk
    '';

  meta = {
    description = "Fully local browser-based code review UI for git and jj diffs";
    homepage = "https://github.com/oxidecomputer/skepsis";
    license = lib.licenses.mpl20;
    mainProgram = "skepsis";
    platforms = lib.platforms.unix;
  };
}
