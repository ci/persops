{ lib }:
rec {
  vault = "persops";

  # References in an `op inject`-style template, e.g. `{{ op://persops/item/field }}`.
  # Keep in sync with PLACEHOLDER in render-secret-template.py.
  refsOf =
    text:
    lib.unique (
      map (match: lib.strings.trim (builtins.head match)) (
        builtins.filter builtins.isList (builtins.split "\\{\\{([^}]*)}}" text)
      )
    );

  # opnix requires camelCase alphanumeric secret keys.
  rawKey =
    name: index:
    "tpl${lib.toUpper (builtins.substring 0 1 name)}${builtins.substring 1 (-1) name}${toString index}";

  # One raw opnix secret per unique template reference.
  templateRefs =
    name: text:
    lib.imap0 (index: ref: {
      key = rawKey name index;
      inherit ref;
    }) (refsOf text);

  # Maps each template reference to the raw file opnix writes under rawDir.
  templateSources =
    rawDir: name: text:
    lib.listToAttrs (
      map (raw: lib.nameValuePair raw.ref "${rawDir}/${raw.key}") (templateRefs name text)
    );

  assertions =
    templates:
    lib.concatLists (
      lib.mapAttrsToList (name: template: [
        {
          assertion = builtins.match "[a-zA-Z0-9]+" name != null;
          message = "persops secret template '${name}' must be alphanumeric";
        }
        {
          assertion =
            refsOf template.text != [ ] && lib.all (lib.hasPrefix "op://${vault}/") (refsOf template.text);
          message = "persops secret template '${name}' must reference op://${vault}/ only";
        }
      ]) templates
    );

  templateOptions =
    extra:
    {
      text = lib.mkOption {
        type = lib.types.lines;
        description = "Template with `{{ op://persops/item/field }}` placeholders.";
      };
      path = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path of the rendered file.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "0400";
      };
    }
    // extra;
}
