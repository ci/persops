{ pkgs, lib, ... }:

let
  myRuby = pkgs.ruby_3_4;
  appleToolchainShims = lib.hiPrio (pkgs.symlinkJoin {
    name = "apple-toolchain-shims";
    paths = [
      (pkgs.writeShellScriptBin "cc" ''
        exec /usr/bin/cc "$@"
      '')
      (pkgs.writeShellScriptBin "c++" ''
        exec /usr/bin/c++ "$@"
      '')
      (pkgs.writeShellScriptBin "cpp" ''
        exec /usr/bin/cpp "$@"
      '')
      (pkgs.writeShellScriptBin "gcc" ''
        exec /usr/bin/cc "$@"
      '')
      (pkgs.writeShellScriptBin "g++" ''
        exec /usr/bin/c++ "$@"
      '')
      (pkgs.writeShellScriptBin "gnu-gcc" ''
        exec ${pkgs.gcc}/bin/gcc "$@"
      '')
      (pkgs.writeShellScriptBin "gnu-g++" ''
        exec ${pkgs.gcc}/bin/g++ "$@"
      '')
    ];
  });
in
{
  home.packages = with pkgs; [
    (myRuby.withPackages (ps: with ps; [
      cocoapods
      htmlbeautifier
      irb
      pry
      pwntools
      rails
      rake
      rspec
      rubocop
      solargraph
      zsteg
    ]))

    gcc

    kamal

    beam.packages.erlang_28.elixir_1_20
    go

    flutter

    (python314.withPackages (ps: with ps; [
      aiohttp
      beautifulsoup4
      build
      ipython
      jupyter
      matplotlib
      numpy
      openpyxl
      pandas
      pip
      pipx
      pwntools
      pydantic
      requests
      ropgadget
      setuptools
      twine
      z3-solver
    ]))
    uv

    deno
    nodejs
    yarn
    php83
    php83Packages.composer

    lefthook

    # nvim :Mason deps / language toolchains
    rustup
    unzip
    cabal-install

    zig_0_14
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    # Keep generic compiler names on macOS pointed at Apple's SDK-aware
    # toolchain. GNU GCC remains available explicitly as `gnu-gcc`/`gnu-g++`.
    appleToolchainShims
  ];

  # Ensure rust-analyzer is available even when rust is managed via rustup/mise.
  # (Mason sometimes expects `rust-analyzer`/`cargo` on PATH.)
  home.activation.ensureRustAnalyzer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${lib.getExe pkgs.rustup}" ]; then
      if ! "${lib.getExe pkgs.rustup}" component list --installed 2>/dev/null | grep -q '^rust-analyzer'; then
        "${lib.getExe pkgs.rustup}" component add rust-analyzer >/dev/null 2>&1 || true
      fi
    fi
  '';
}
