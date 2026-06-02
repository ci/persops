{ lib, pkgs, currentSystemName ? null, currentSystemUser ? "cat", ... }:

let
  inherit (pkgs.stdenv) isDarwin;

  workSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGzV767GrAPq9JZ/Iv7B4Yg6wiA2AH2AwjnZWE23r3HX";
  personalSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFP05x9Bg50efrFPX0NXfV45RwcsYmgpKUKTnR2Ee7LA";
  secretiveSigningConfigs = {
    aglaea = {
      identities = "catalin.irimie@gmail.com,6650666+ci@users.noreply.github.com,ci@users.noreply.github.com,4375373-cat@users.noreply.gitlab.com";
      key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBC5hHouSghgUsKasZMfCkMiuOCU0kU4KwMyN6tCelex+LHxp++ZsMQCtdZJN6q0tyxN31wQ7D3F8DjSM/F412L4= ci-ghgl-signing@secretive.aglaea.local";
      path = "/Users/${currentSystemUser}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys/a9cbb4c069d69eec1b485cf51b58aec1.pub";
    };
    work = {
      identities = "catalin.i@posthog.com,268578347+cat-ph@users.noreply.github.com,cat-ph@users.noreply.github.com";
      key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLUXi3FNs2AOfnfulYgOdNbznvgUfRvI3iNNl1O1aBPTAS6bbYtH/gX/3DiWx2/jAjIHGuFg/EEpEhoQKLD9OBA= catalin.i@posthog.com";
      path = "/Users/${currentSystemUser}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys/a513f11a72d3cfbbb3193115ac1bad5b.pub";
    };
  };
  secretiveSigningConfig =
    if currentSystemName != null && builtins.hasAttr currentSystemName secretiveSigningConfigs
    then builtins.getAttr currentSystemName secretiveSigningConfigs
    else null;
  secretiveSocket = "/Users/${currentSystemUser}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
  useSecretiveSigning = isDarwin && secretiveSigningConfig != null;
in
{
  home.file = {
    # also can use a ~/.gitconfig.local with non-committed overrides
    ".gitconfig".source = ./gitconfig;
  } // lib.optionalAttrs useSecretiveSigning {
    ".local/bin/git-ssh-sign-secretive" = {
      executable = true;
      text = ''
        #!/bin/sh
        export SSH_AUTH_SOCK="${secretiveSocket}"
        exec /usr/bin/ssh-keygen "$@"
      '';
    };
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
      '' + lib.optionalString useSecretiveSigning ''
        ${secretiveSigningConfig.identities} namespaces="git" ${secretiveSigningConfig.key}
      '';
      force = true;
    };

    "git/ssh-signing.inc" = {
      text = lib.optionalString isDarwin (if useSecretiveSigning then ''
        [user]
            signingkey = ${secretiveSigningConfig.path}

        [gpg "ssh"]
            program = /Users/${currentSystemUser}/.local/bin/git-ssh-sign-secretive
      '' else ''
        [gpg "ssh"]
            program = /Applications/1Password.app/Contents/MacOS/op-ssh-sign
      '');
      force = true;
    };

  } // lib.optionalAttrs useSecretiveSigning {
    "jj/conf.d/${currentSystemName}-signing.toml" = {
      text = ''
        [signing]
        behavior = "own"
        backend = "ssh"
        key = "${secretiveSigningConfig.path}"

        [signing.backends.ssh]
        program = "/Users/${currentSystemUser}/.local/bin/git-ssh-sign-secretive"
        allowed-signers = "/Users/${currentSystemUser}/.config/git/allowed_signers"
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
