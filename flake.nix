{
  description = "persops";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Master nixpkgs is used for really bleeding edge packages. Warning
    # that this is extremely unstable and shouldn't be relied on. Its
    # mostly for testing.
    nixpkgs-master.url = "github:nixos/nixpkgs";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-snapd = {
      url = "github:nix-community/nix-snapd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jj-starship = {
      url = "github:dmmulroy/jj-starship";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tmux-sessionizer = {
      url = "github:jrmoulton/tmux-sessionizer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-steipete-tools = {
      url = "github:clawdbot/nix-steipete-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-yazi-plugins = {
      url = "github:lordkekz/nix-yazi-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jujutsu.url = "github:jj-vcs/jj";
    zig.url = "github:mitchellh/zig-overlay";
    flox = {
      url = "github:flox/flox/latest";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      overlays = [
        inputs.jujutsu.overlays.default
        inputs.zig.overlays.default
        inputs."codex-cli-nix".overlays.default
        inputs."claude-code-nix".overlays.default
        inputs.jj-starship.overlays.default
        inputs.tmux-sessionizer.overlays.default
        (_: prev: {
          # pipx 1.8.0 tests still expect old direct-URL specifier spacing.
          pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
            (_: pyPrev: {
              pipx = pyPrev.pipx.overridePythonAttrs (old: {
                disabledTests = (old.disabledTests or [ ]) ++ [
                  "test_fix_package_name"
                  "test_parse_specifier_for_metadata"
                ];
              });
            })
          ];
        })
        (
          _: prev:
          if prev.stdenv.isDarwin then
            {
              # direnv 2.37.1 still forces Darwin external linking upstream.
              direnv = prev.direnv.overrideAttrs (old: {
                env = (old.env or { }) // {
                  CGO_ENABLED = 1;
                };
              });
            }
          else
            { }
        )
      ];

      mkSystem = import ./lib/mksystem.nix {
        inherit
          self
          overlays
          nixpkgs
          inputs
          ;
      };

      checkSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      forAllCheckSystems = nixpkgs.lib.genAttrs checkSystems;

      pkgsFor =
        system:
        import nixpkgs {
          inherit overlays system;
          config.allowUnfree = true;
        };

      checkToolPackages = pkgs: [
        pkgs.actionlint
        pkgs.deadnix
        pkgs.nixfmt
        pkgs.shellcheck
        pkgs.shfmt
        pkgs.statix
        pkgs.stylua
      ];

      workflowToolPackages = pkgs: [
        pkgs.nix-fast-build
        pkgs.nix-output-monitor
      ];
    in
    {
      formatter = forAllCheckSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.nixfmt
      );

      devShells = forAllCheckSystems (
        system:
        let
          pkgs = pkgsFor system;
          pythonForChecks = pkgs.python3.withPackages (ps: [
            ps.pyyaml
          ]);
        in
        {
          default = pkgs.mkShell {
            packages =
              checkToolPackages pkgs
              ++ workflowToolPackages pkgs
              ++ [
                pythonForChecks
              ];
          };
        }
      );

      checks = forAllCheckSystems (
        system:
        let
          pkgs = pkgsFor system;
          pythonForChecks = pkgs.python3.withPackages (ps: [
            ps.pyyaml
          ]);
        in
        {
          repo =
            pkgs.runCommand "persops-repo-check"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.findutils
                  pkgs.gnugrep
                  pkgs.gnused
                  pythonForChecks
                ]
                ++ checkToolPackages pkgs;
              }
              ''
                cp -R ${self} source
                chmod -R u+w source
                cd source
                bash scripts/check-repo
                touch $out
              '';
        }
      );

      darwinConfigurations."aglaea" = mkSystem "aglaea" {
        system = "aarch64-darwin";
        user = "cat";
        darwin = true;
      };

      darwinConfigurations."work" = mkSystem "work" {
        system = "aarch64-darwin";
        user = "cat";
        darwin = true;
      };

      nixosConfigurations."amalthea" = mkSystem "amalthea" {
        system = "x86_64-linux";
        user = "cat";
      };
    };
}
