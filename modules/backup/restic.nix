{ pkgs, lib, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  imports =
    lib.optionals isDarwin [ ./restic-darwin.nix ] ++ lib.optionals (!isDarwin) [ ./restic-nixos.nix ];
}
