# Host secrets come from the shared `persops` 1Password vault through opnix's
# read-only service account; see docs/secrets.md. Modules declare single-value
# files in services.onepassword-secrets.secrets and multi-value files here.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.persops.secretTemplates;
  secretsLib = import ./lib.nix { inherit lib; };
  rawDir = config.services.onepassword-secrets.outputDir;
  unitName = name: "persops-secret-${name}";

  # Consumers that failed while a value was missing need a start; try-restart
  # alone leaves them down. Deliberately stopped units stay stopped.
  restartConsumers =
    units:
    pkgs.writeShellScript "persops-secret-restart-consumers" ''
      for unit in ${lib.escapeShellArgs units}; do
        if ${pkgs.systemd}/bin/systemctl is-failed --quiet "$unit"; then
          ${pkgs.systemd}/bin/systemctl --no-block restart "$unit"
        else
          ${pkgs.systemd}/bin/systemctl --no-block try-restart "$unit"
        fi
      done
    '';

  spec =
    name: template:
    pkgs.writeText "persops-secret-${name}.json" (
      builtins.toJSON {
        template = pkgs.writeText "persops-secret-${name}.tpl" template.text;
        sources = secretsLib.templateSources rawDir name template.text;
        inherit (template)
          path
          owner
          group
          mode
          ;
      }
    );
in
{
  imports = [ inputs.opnix.nixosModules.default ];

  options.persops.secretTemplates = lib.mkOption {
    default = { };
    description = "Files rendered from `op inject`-style templates after opnix fetches their references.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = secretsLib.templateOptions {
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          restartUnits = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Units started after the render and try-restarted when it re-renders.";
          };
        };
      }
    );
  };

  config = {
    assertions = secretsLib.assertions cfg;

    services.onepassword-secrets = {
      enable = true;
      tokenFile = "/etc/opnix-token";
      systemdIntegration.polling = {
        enable = true;
        interval = "6h";
      };
      # opnix try-restarts the render unit when a raw value changes.
      secrets = lib.listToAttrs (
        lib.concatLists (
          lib.mapAttrsToList (
            name: template:
            map (
              raw:
              lib.nameValuePair raw.key {
                reference = raw.ref;
                services = [ (unitName name) ];
              }
            ) (secretsLib.templateRefs name template.text)
          ) cfg
        )
      );
    };

    systemd.services = lib.mapAttrs' (
      name: template:
      lib.nameValuePair (unitName name) {
        description = "Render ${template.path} from opnix secrets";
        wantedBy = [ "multi-user.target" ] ++ template.restartUnits;
        before = template.restartUnits;
        serviceConfig = {
          Type = "oneshot";
          # Stay active so opnix's try-restart re-renders after a value change.
          RemainAfterExit = true;
          UMask = "0077";
          ExecStart = "${lib.getExe pkgs.python3} ${./render-secret-template.py} ${spec name template}";
          # --no-block: the restarted units are ordered after this one.
          ExecStartPost = lib.optional (template.restartUnits != [ ]) (
            restartConsumers template.restartUnits
          );
        };
      }
    ) cfg;
  };
}
