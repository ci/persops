{
  lib,
  fetchurl,
  git,
  jujutsu,
  makeWrapper,
  nodejs_22,
  stdenv,
  xdg-utils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "skepsis";
  version = "0.2.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@oxide/skepsis/-/skepsis-${finalAttrs.version}.tgz";
    hash = "sha512-yDWL2eP5XJFdgHk0ZUh8oEC+Tja662XPMgB01l2a/BhZKBg419wb/QURWCSxD7MmLv8sk4o2EXo6tykkhWUd+A==";
  };

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;

  installPhase =
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
      runHook preInstall

      appDir=$out/lib/node_modules/@oxide/skepsis
      mkdir -p "$appDir" "$out/bin"
      cp -R dist package.json README.md LICENSE "$appDir"/
      makeWrapper ${lib.getExe nodejs_22} $out/bin/skepsis \
        --add-flags "$appDir/dist/cli.js" \
        --prefix PATH : ${runtimePath}
      ln -s skepsis $out/bin/sk

      runHook postInstall
    '';

  meta = {
    description = "Fully local browser-based code review UI for git and jj diffs";
    homepage = "https://github.com/oxidecomputer/skepsis";
    license = lib.licenses.mpl20;
    mainProgram = "skepsis";
    platforms = lib.platforms.unix;
  };
})
