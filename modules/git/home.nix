{ lib, pkgs, ... }:

let
  workSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGzV767GrAPq9JZ/Iv7B4Yg6wiA2AH2AwjnZWE23r3HX";
  personalSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFP05x9Bg50efrFPX0NXfV45RwcsYmgpKUKTnR2Ee7LA";
in
{
  home.file = {
    # also can use a ~/.gitconfig.local with non-committed overrides
    ".gitconfig".source = ./gitconfig;
  };

  xdg.configFile = {
    # Take ownership of Git's default global excludes file.
    "git/ignore" = {
      source = ./ignore;
      force = true;
    };

    # Local trust DB for SSH commit/tag signatures.
    # Work key: GitHub cat-ph SSH signing key 858365.
    # Personal key: GitHub ci SSH auth key; ci currently publishes no SSH signing keys.
    "git/allowed_signers" = {
      text = ''
        catalin.i@posthog.com,268578347+cat-ph@users.noreply.github.com,cat-ph@users.noreply.github.com namespaces="git" ${workSshKey}
        catalin.irimie@gmail.com,6650666+ci@users.noreply.github.com,ci@users.noreply.github.com namespaces="git" ${personalSshKey}
      '';
      force = true;
    };

    "git/1password-ssh-signing.inc" = {
      text = lib.optionalString pkgs.stdenv.isDarwin ''
        [gpg "ssh"]
            program = /Applications/1Password.app/Contents/MacOS/op-ssh-sign
      '';
      force = true;
    };
  };

  home.packages = with pkgs; [
    delta
    git
    git-absorb
    git-branchless
    git-revise
    lazygit
  ];
}

