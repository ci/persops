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
          unzip

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
        ++ lib.optionals pkgs.stdenv.isDarwin [
          # Keep generic compiler names on macOS pointed at Apple's SDK-aware
          # toolchain. GNU GCC remains available explicitly as `gnu-gcc`/`gnu-g++`.
          appleToolchainShims
        ]
      );

}
