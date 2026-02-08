{ pkgs, lib, ... }:

let
  myRuby = pkgs.ruby_3_4;
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

    beam.packages.erlang_27.elixir_1_18
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
    # nodejs
    nodePackages.npm
    nodePackages.yarn

    lefthook

    # nvim :Mason deps / language toolchains
    rustup
    unzip
    cabal-install

    zig_0_14
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
