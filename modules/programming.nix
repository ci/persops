{
  pkgs,
  lib,
  currentSystemName ? null,
  currentSystemProfile,
  ...
}:

let
  isPersonal = currentSystemProfile == "personal";
  myRuby = pkgs.ruby_3_4;
  appleToolchainShims = lib.hiPrio (
    pkgs.symlinkJoin {
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
    }
  );
in
{
  # Work hosts keep the core toolchains; project-specific runtimes come from mise.
  home.packages =
    lib.optionals
      (builtins.elem currentSystemName [
        "aglaea"
        "amalthea"
        "ergane"
      ])
      (
        with pkgs;
        [
          gcc

          go

          (python314.withPackages (
            ps:
            with ps;
            [
              build
              ipython
              pip
              pipx
              pydantic
              requests
              setuptools
              twine
            ]
            ++ lib.optionals isPersonal [
              aiohttp
              beautifulsoup4
              jupyter
              matplotlib
              numpy
              openpyxl
              pandas
              pwntools
              ropgadget
              z3-solver
            ]
          ))
          uv

          deno
          nodejs
          yarn

          lefthook

          # nvim :Mason deps / language toolchains
          (lib.hiPrio rust-analyzer)
          rustup
          cargo-nextest # omicron and friends only support `cargo nextest run`
          unzip

          cscope # C cross-reference for illumos-gate (cscope_maps.nvim)

          zig_0_14
        ]
        ++ lib.optionals isPersonal [
          (myRuby.withPackages (
            ps: with ps; [
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
            ]
          ))

          kamal

          beam.packages.erlang_28.elixir_1_20

          flutter

          php83
          php83Packages.composer

          cabal-install
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          # Keep generic compiler names on macOS pointed at Apple's SDK-aware
          # toolchain. GNU GCC remains available explicitly as `gnu-gcc`/`gnu-g++`.
          appleToolchainShims
        ]
      );

  # Brew native libs for omicron (machines/ergane.nix):
  # - pq-sys checks PQ_LIB_DIR before pkg-config/pg_config; brew's libpq is
  #   keg-only, so neither of those finds it.
  # - brew's xmlsec1 links brew's libxml2, but Homebrew's macOS shim .pc files
  #   resolve libxml-2.0/libxslt to /usr/lib. samael then links the system
  #   libxml2 and segfaults verifying signatures, so point pkg-config at the
  #   keg-only brew copies.
  home.sessionVariables = lib.mkIf (currentSystemName == "ergane") {
    PQ_LIB_DIR = "/opt/homebrew/opt/libpq/lib";
    PKG_CONFIG_PATH = "/opt/homebrew/opt/libxml2/lib/pkgconfig:/opt/homebrew/opt/libxslt/lib/pkgconfig";
  };
}
