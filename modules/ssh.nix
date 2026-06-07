{ pkgs, lib, ... }:

let
  inherit (pkgs.stdenv) isDarwin;

  onePassDarwinPath =
    ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';

  defaultSettings = {
    ForwardAgent = false;
    AddKeysToAgent = "no";
    Compression = false;
    ServerAliveInterval = 0;
    ServerAliveCountMax = 3;
    HashKnownHosts = false;
    UserKnownHostsFile = "~/.ssh/known_hosts";
    ControlMaster = "no";
    ControlPath = "~/.ssh/master-%r@%n:%p";
    ControlPersist = "no";
  };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Load private host entries / overrides if present.
    includes = [ "~/.ssh/config.local" ];

    settings = {
      "*" = defaultSettings // lib.optionalAttrs isDarwin {
        IdentityAgent = onePassDarwinPath;
      };
    } // lib.optionalAttrs isDarwin {
      amalthea = {
        ForwardAgent = "yes";
      };
    };
  };
}
