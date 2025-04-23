{ pkgs, ... }:

let
  emacsWithPackages = with pkgs; ((pkgs.emacsPackagesFor pkgs.emacs-nox).withPackages (epkgs: with epkgs; [
    treesit-grammars.with-all-grammars
  ]));
in
{
  environment.systemPackages = [emacsWithPackages];

  services.emacs = {
    enable = true;
    package = emacsWithPackages;
    additionalPath = ["/Users/cat/.nix-profile/bin" "/etc/profiles/per-user/cat/bin"];
  };
}
