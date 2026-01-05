{ pkgs, ... }:

let
  inherit (pkgs.stdenv) isDarwin;

  onePassDarwinPath =
    "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock";
in
{
  programs.ssh =
    {
      enable = true;

      # Load private host entries / overrides if present.
      includes = [ "~/.ssh/config.local" ];
    } // (if isDarwin then {
      enableDefaultConfig = false;

      matchBlocks."*" = {
        extraOptions.IdentityAgent = onePassDarwinPath;
      };

      # When connecting to the NixOS box, forward the local 1Password agent
      # so the remote stays headless.
      matchBlocks."amalthea" = {
        extraOptions.ForwardAgent = "yes";
      };
    } else {});
}
