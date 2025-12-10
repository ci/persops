{ pkgs, user, ... }:

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
    additionalPath = ["/Users/${user}/.nix-profile/bin" "/etc/profiles/per-user/${user}/bin"];
  };
}
