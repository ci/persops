# Keep universal CLI packages in commonPackages and place host-specific additions
# in the matching host list so work and server closures stay intentionally small.
{
  pkgs,
  lib,
  currentSystemName ? null,
  blogwatcherPackage,
  goplacesPackage,
  gwsPackage,
  skepsisPackage,
  ...
}:
let
  commonPackages = with pkgs; [
    actionlint
    ast-grep
    biome
    btop
    bun
    cmake
    curl
    devenv
    difftastic
    doggo
    duf
    dust
    eza
    fd
    file
    fzf
    fx
    gh
    glow
    htop
    hyperfine
    jq
    jujutsu
    jjui
    mosh
    navi
    nix-fast-build
    nix-output-monitor
    nushell
    ouch
    pnpm
    ripgrep
    sad
    shellcheck
    statix
    tree-sitter
    wget
  ];

  opsPackages = with pkgs; [
    ansible
    docker
    docker-compose
    k9s
    kubectl
    kubectx
    kubernetes-helm
    opentofu
    tanka
    terraform
  ];

  aglaeaPackages =
    with pkgs;
    [
      audacity
      avalonia-ilspy
      awscli2
      blogwatcherPackage
      cloudflared
      dbeaver-bin
      element-desktop
      freerdp
      ghidra-bin
      goplacesPackage
      gwsPackage
      jsonnet
      jsonnet-bundler
      kaggle
      openhue-cli
      outfieldr
      overmind
      pgcli
      pscale
      signal-desktop
      skepsisPackage
      slack
      wakeonlan
      zoom-us
    ]
    ++ opsPackages
    ++ lib.optionals pkgs.stdenv.isDarwin [
      docker-credential-helpers
      hexfiend
      mos
      numi
    ];

  workPackages =
    with pkgs;
    [
      awscli2
      pgcli
    ]
    ++ opsPackages;

  amaltheaPackages = with pkgs; [
    docker-compose
    k9s
    kubectl
    kubectx
    pgcli
  ];

  hostPackages =
    if currentSystemName == "aglaea" then
      aglaeaPackages
    else if currentSystemName == "work" then
      workPackages
    else if currentSystemName == "amalthea" then
      amaltheaPackages
    else
      [ ];
in
{
  home.packages = commonPackages ++ hostPackages;
}
