{ pkgs, ... }:

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

    (python312.withPackages (ps: with ps; [
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

    zig_0_14
  ];
}
