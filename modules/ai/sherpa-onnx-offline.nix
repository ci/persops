{ lib
, stdenv
, fetchurl
, makeWrapper
, cudaPackages
}:

let
  pname = "sherpa-onnx-offline";
  version = "1.12.23";

  binSources = {
    "x86_64-linux" = {
      url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/v${version}/sherpa-onnx-v${version}-cuda-12.x-cudnn-9.x-linux-x64-gpu.tar.bz2";
      hash = "sha256-rFQA63lxtxNNA0KXJ+vdcCwjWX43IfSjrehIFXCNjD4=";
    };
  };

  source = lib.attrByPath [ stdenv.hostPlatform.system ] null binSources;
  src = if source == null then
    throw "sherpa-onnx-offline: unsupported system ${stdenv.hostPlatform.system}"
  else
    fetchurl source;

  runtimeLibs = [
    stdenv.cc.cc.lib
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];

  meta = with lib; {
    description = "Offline sherpa-onnx GPU binaries (CUDA 12.x + cuDNN 9.x)";
    homepage = "https://github.com/k2-fsa/sherpa-onnx";
    license = licenses.asl20;
    mainProgram = "sherpa-onnx-offline";
    platforms = builtins.attrNames binSources;
  };
in
stdenv.mkDerivation {
  inherit pname version src meta;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    tar -xjf "$src"
  '';

  installPhase = ''
    runHook preInstall
    root_dir=$(find . -maxdepth 1 -type d -name "sherpa-onnx-v*" | head -n1)
    if [ -z "$root_dir" ]; then
      echo "sherpa-onnx: release dir not found in tarball" >&2
      exit 1
    fi
    mkdir -p "$out/bin" "$out/lib"
    cp -r "$root_dir"/bin/* "$out/bin/"
    cp -r "$root_dir"/lib/* "$out/lib/"
    if [ -d "$root_dir/include" ]; then
      mkdir -p "$out/include"
      cp -r "$root_dir"/include/* "$out/include/"
    fi
    runHook postInstall
  '';

  postFixup = ''
    for exe in "$out"/bin/*; do
      if [ -x "$exe" ] && [ ! -d "$exe" ]; then
        wrapProgram "$exe" \
          --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib:/run/opengl-driver-32/lib:$out/lib:${lib.makeLibraryPath runtimeLibs}"
      fi
    done
  '';
}
