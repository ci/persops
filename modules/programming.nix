{ pkgs, ... }:

let
  myRuby = pkgs.ruby_3_4;

  # to update, nix run nixpkgs#bundix -- --gemset in ./ruby
  customGems = pkgs.bundlerApp {
    pname  = "kamal";
    exes   = [ "kamal" ]; # all exes get installed
    gemdir = ./ruby;
    ruby   = myRuby;
  };
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

    customGems

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
      z3
    ]))
    uv

    deno
    # nodejs
    nodePackages.npm
    nodePackages.yarn
  ];
}
