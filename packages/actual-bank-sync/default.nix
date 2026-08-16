{
  buildNpmPackage,
  lib,
  makeWrapper,
  nodejs_22,
}:

buildNpmPackage {
  pname = "actual-bank-sync";
  version = "1.0.0";

  src = ./.;
  npmDepsHash = "sha256-kwAaRPXAxG2gqpWtWLWP0hbv48MlbD/KT++isEiM64c=";
  nodejs = nodejs_22;
  dontNpmBuild = true;
  doCheck = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  checkPhase = ''
    runHook preCheck
    npm test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/actual-bank-sync" "$out/bin"
    cp -r node_modules package.json src "$out/libexec/actual-bank-sync/"
    makeWrapper "${nodejs_22}/bin/node" "$out/bin/actual-bank-sync" \
      --add-flags "$out/libexec/actual-bank-sync/src/cli.mjs"
    runHook postInstall
  '';

  meta = {
    description = "Headless Actual bank sync and deterministic FX reconciliation";
    license = lib.licenses.mit;
    mainProgram = "actual-bank-sync";
    platforms = lib.platforms.unix;
  };
}
