{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.iamb.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
