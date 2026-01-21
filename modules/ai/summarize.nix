{ lib
, stdenv
, fetchurl
, nodejs
, pnpm
, python3
, python3Packages
, pkg-config
, makeWrapper
, pkgs
, git
, zstd
}:

let
  pname = "summarize";
  version = "0.9.0";
  binSources = {
    "aarch64-darwin" = {
      url = "https://github.com/steipete/summarize/releases/download/v0.9.0/summarize-macos-arm64-v0.9.0.tar.gz";
      hash = "sha256-B6/eUcbv4K9kgozo1fELFX+NNGa0C64dB6OSydwu6A8=";
    };
  };

  src = fetchurl {
    url = "https://github.com/steipete/summarize/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-HQ/jboAN+g7Mz41ayDAt0thR5kuJjttgfJTXE7IRSzQ=";
  };

  pnpmFetchDepsPkg = pkgs.callPackage "${pkgs.path}/pkgs/build-support/node/fetch-pnpm-deps" {
    inherit pnpm;
  };

  pnpmDeps = (pnpmFetchDepsPkg.fetchPnpmDeps {
    pname = pname;
    version = version;
    src = src;
    hash = "sha256-3BRbu9xNYUpsUkC1DKXKl8iv5GO9rZqE2eqRVDh8DTA=";
    fetcherVersion = 3;
  });

  meta = with lib; {
    description = "Link → clean text → summary";
    homepage = "https://github.com/steipete/summarize";
    license = licenses.mit;
    platforms = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "summarize";
  };
in
if stdenv.isLinux then
  stdenv.mkDerivation {
    inherit pname version src meta;

    nativeBuildInputs = [
      nodejs
      pnpm
      python3
      python3Packages.setuptools
      pkg-config
      makeWrapper
      zstd
      git
    ];

    postPatch = ''
      ${python3}/bin/python - <<'PY'
import json
from pathlib import Path
p = Path("package.json")
data = json.loads(p.read_text())
scripts = data.get("scripts", {})
if "prepare" in scripts:
  del scripts["prepare"]
data["scripts"] = scripts
p.write_text(json.dumps(data, indent=2) + "\n")
PY
    '';

    env = {
      PNPM_IGNORE_PACKAGE_MANAGER_CHECK = "1";
      PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
      NPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
      COREPACK_ENABLE_STRICT = "0";
      NODE_ENV = "development";
      CI = "1";
      HOME = "/tmp";
      PNPM_HOME = "/tmp/pnpm-home";
      PNPM_CONFIG_HOME = "/tmp/pnpm-config";
      XDG_CACHE_HOME = "/tmp/pnpm-cache";
      NPM_CONFIG_USERCONFIG = "/tmp/pnpm-config/.npmrc";
      npm_config_nodedir = "${nodejs.dev}";
      npm_config_build_from_source = "1";
    };

    buildPhase = ''
      runHook preBuild
      mkdir -p "$HOME" "$PNPM_HOME" "$PNPM_CONFIG_HOME" "$XDG_CACHE_HOME"
      export PNPM_STORE_PATH="$TMPDIR/pnpm-store"
      mkdir -p "$PNPM_STORE_PATH"
      tar --zstd -xf ${pnpmDeps}/pnpm-store.tar.zst -C "$PNPM_STORE_PATH"
      chmod -R u+rwX "$PNPM_STORE_PATH"
      ${pnpm}/bin/pnpm config set manage-package-manager-versions false
      ${pnpm}/bin/pnpm config set store-dir "$PNPM_STORE_PATH"
      ${pnpm}/bin/pnpm install --offline --frozen-lockfile --force
      patchShebangs node_modules/.bin
      ${pnpm}/bin/pnpm build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libexec" "$out/libexec/packages" "$out/libexec/apps" "$out/bin"
      cp -r dist package.json node_modules "$out/libexec/"
      cp -r packages/core "$out/libexec/packages/"
      cp -r apps/chrome-extension "$out/libexec/apps/"
      chmod 0755 "$out/libexec/dist/cli.js"
      makeWrapper "${nodejs}/bin/node" "$out/bin/summarize" \
        --add-flags "$out/libexec/dist/cli.js"
      runHook postInstall
    '';
  }
else
  stdenv.mkDerivation {
    pname = pname;
    version = version;
    src = fetchurl binSources.${stdenv.hostPlatform.system};

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      tar -xzf "$src"
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      cp summarize "$out/bin/summarize"
      chmod 0755 "$out/bin/summarize"
      runHook postInstall
    '';

    inherit meta;
  }
