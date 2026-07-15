{
  lib,
  pkgs,
  currentSystemName,
  currentSystemUser,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;

  settings = import ./restic-storage-box-settings.nix;
  inherit (settings)
    host
    port
    publicKey
    repository
    user
    ;

  home = if isDarwin then "/Users/${currentSystemUser}" else "/home/${currentSystemUser}";
  secretDir =
    if isDarwin then "${home}/.config/restic-storage-box" else "/etc/secrets/restic-storage-box";
  passwordFile = "${secretDir}/password";
  identityFile =
    if isDarwin then "${home}/.ssh/hetzner-storage-box-aglaea" else "${secretDir}/id_ed25519";
  knownHostsFile = "/etc/ssh/ssh_known_hosts";
  sftpCommand = "ssh -i ${identityFile} -p ${toString port} -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${knownHostsFile} -s ${user}@${host} sftp";

  storageBoxClient = pkgs.writeShellScriptBin "restic-storage-box" ''
    set -euo pipefail

    if [ ! -r ${lib.escapeShellArg passwordFile} ]; then
      echo "missing Restic password: ${passwordFile}" >&2
      exit 1
    fi
    if [ ! -r ${lib.escapeShellArg identityFile} ]; then
      echo "missing Storage Box key: ${identityFile}" >&2
      exit 1
    fi

    exec ${lib.getExe pkgs.restic} \
      --repo ${lib.escapeShellArg repository} \
      --password-file ${lib.escapeShellArg passwordFile} \
      -o ${lib.escapeShellArg "sftp.command=${sftpCommand}"} \
      "$@"
  '';

in
{
  assertions = [
    {
      assertion = builtins.elem currentSystemName [
        "aglaea"
        "amalthea"
      ];
      message = "The Storage Box client is only intended for aglaea and amalthea.";
    }
  ];

  programs.ssh.knownHosts."hetzner-storage-box" = {
    hostNames = [
      host
      "[${host}]:${toString port}"
    ];
    inherit publicKey;
  };

  environment.systemPackages = [ storageBoxClient ];
}
