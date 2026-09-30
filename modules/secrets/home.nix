# User-owned host secrets from the shared `persops` 1Password vault; see
# docs/secrets.md. opnix's own Home Manager module exits the whole activation
# script when its token is missing, so this runs the opnix CLI directly and
# keeps existing files whenever a fetch fails. Work-profile hosts must never
# hold the persops-opnix token, so they cannot declare any of these files.
{
  config,
  inputs,
  lib,
  pkgs,
  currentSystemProfile,
  ...
}:
let
  cfg = config.persops.homeSecrets;
  secretsLib = import ./lib.nix { inherit lib; };
  opnix = inputs.opnix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  tokenFile = "${config.xdg.configHome}/opnix/token";
  rawDir = "${config.xdg.stateHome}/persops/opnix";
  owner = config.home.username;
  group = if pkgs.stdenv.hostPlatform.isDarwin then "staff" else "users";

  rawSecrets = lib.concatLists (
    lib.mapAttrsToList (name: template: secretsLib.templateRefs name template.text) cfg.templates
  );

  opnixConfig = pkgs.writeText "persops-home-secrets.json" (
    builtins.toJSON {
      secrets =
        lib.mapAttrsToList (_: file: {
          inherit (file)
            reference
            kind
            path
            mode
            ;
          inherit owner group;
        }) cfg.files
        ++ map (raw: {
          path = "${rawDir}/${raw.key}";
          reference = raw.ref;
          kind = "field";
          mode = "0600";
          inherit owner group;
        }) rawSecrets;
    }
  );

  spec =
    name: template:
    pkgs.writeText "persops-home-secret-${name}.json" (
      builtins.toJSON {
        template = pkgs.writeText "persops-home-secret-${name}.tpl" template.text;
        sources = secretsLib.templateSources rawDir name template.text;
        inherit (template) path mode;
      }
    );

  renderCommands = lib.concatStrings (
    lib.mapAttrsToList (name: template: ''
      run ${lib.getExe pkgs.python3} ${./render-secret-template.py} ${spec name template} \
        || warnEcho "persops secrets: could not render ${template.path}"
    '') cfg.templates
  );
in
{
  options.persops.homeSecrets = {
    files = lib.mkOption {
      default = { };
      description = "Single-value files fetched from 1Password.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            reference = lib.mkOption {
              type = lib.types.str;
            };
            path = lib.mkOption {
              type = lib.types.str;
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0600";
            };
            kind = lib.mkOption {
              type = lib.types.enum [
                "field"
                "file"
              ];
              default = "field";
            };
          };
        }
      );
    };

    templates = lib.mkOption {
      default = { };
      description = "Files rendered from `op inject`-style templates.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = secretsLib.templateOptions { };
        }
      );
    };
  };

  config = lib.mkIf (cfg.files != { } || cfg.templates != { }) {
    assertions = [
      {
        assertion = currentSystemProfile != "work";
        message = "persops home secrets are not allowed on work-profile hosts (docs/secrets.md)";
      }
    ]
    ++ secretsLib.assertions cfg.templates
    ++ lib.mapAttrsToList (name: file: {
      assertion = lib.hasPrefix "op://${secretsLib.vault}/" file.reference;
      message = "persops home secret '${name}' must reference op://${secretsLib.vault}/";
    }) cfg.files;

    home.activation.persopsSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -s ${lib.escapeShellArg tokenFile} ]; then
        warnEcho "persops secrets: ${tokenFile} missing; keeping existing files (docs/secrets.md)"
      else
        run install -d -m 0700 ${lib.escapeShellArg rawDir}
        if run ${opnix}/bin/opnix secret -token-file ${lib.escapeShellArg tokenFile} \
          -config ${opnixConfig} -output ${lib.escapeShellArg rawDir} >/dev/null; then
      ${renderCommands}
          run touch ${lib.escapeShellArg "${rawDir}/last-success"}
        else
          warnEcho "persops secrets: opnix fetch failed; keeping existing files"
        fi
      fi
    '';
  };
}
