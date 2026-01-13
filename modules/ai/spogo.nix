{ lib
, stdenv
, fetchurl
}:

let
  pname = "spogo";
  version = "0.2.0";
  binSources = {
    "aarch64-darwin" = {
      url = "https://github.com/steipete/spogo/releases/download/v${version}/spogo_${version}_darwin_arm64.tar.gz";
      hash = "sha256-T/ft1sggyMRE1akZCCU2avRyEBkAc/AA14F+Zm6toys=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/steipete/spogo/releases/download/v${version}/spogo_${version}_darwin_amd64.tar.gz";
      hash = "sha256-QHjEFQxQ4V1SnuGEVo68mNoWC/PqNPnWqinZ/xfaVjQ=";
    };
    "aarch64-linux" = {
      url = "https://github.com/steipete/spogo/releases/download/v${version}/spogo_${version}_linux_arm64.tar.gz";
      hash = "sha256-fEjnpwzGmmteXSnrpVniNeFfOUmdh7C/e86/R8twWl8=";
    };
    "x86_64-linux" = {
      url = "https://github.com/steipete/spogo/releases/download/v${version}/spogo_${version}_linux_amd64.tar.gz";
      hash = "sha256-XlfghphYtrT+NthVPM7kQkaF74TxrV6fx3EIby/+mUc=";
    };
  };

  source = lib.attrByPath [ stdenv.hostPlatform.system ] null binSources;
  src = if source == null then
    throw "spogo: unsupported system ${stdenv.hostPlatform.system}"
  else
    fetchurl source;

  meta = with lib; {
    description = "Spotify, but make it terminal. Power CLI using web cookies.";
    homepage = "https://github.com/steipete/spogo";
    license = licenses.mit;
    mainProgram = "spogo";
    platforms = builtins.attrNames binSources;
  };
in
stdenv.mkDerivation {
  inherit pname version src meta;

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    spogo_path=$(find . -type f -name spogo -perm -u+x | head -n1)
    if [ -z "$spogo_path" ]; then
      echo "spogo binary not found in release tarball" >&2
      exit 1
    fi
    install -m755 "$spogo_path" "$out/bin/spogo"
    runHook postInstall
  '';
}
