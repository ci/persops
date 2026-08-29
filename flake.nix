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
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
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
    };
    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.5";
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
        (
          _: prev:
          let
            master = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system};
          in
          {
            inherit (master) gh gh-stack;
          }
        )
        inputs."claude-code-nix".overlays.default
        inputs.jj-starship.overlays.default
        inputs.tmux-sessionizer.overlays.default
        (
          _: prev:
          if prev.stdenv.isDarwin then
            {
              # mise 2026.8.6 Darwin checkPhase fails HTTP range-resume tests
              # against the local mock server (416 Range Not Satisfiable).
              mise = prev.mise.overrideAttrs (old: {
                checkFlags = (old.checkFlags or [ ]) ++ [
                  "--skip=http::tests::test_download_recovers_from_unsatisfied_range"
                ];
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

      packages = forAllCheckSystems (system: {
        deploy-rs = inputs.deploy-rs.packages.${system}.default;
      });

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
                nixpkgs.legacyPackages.${system}.jujutsu
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
                  pkgs.gnumake
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

      deploy.nodes.amalthea = {
        hostname = "amalthea";
        sshUser = "cat";
        remoteBuild = true;

        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.amalthea;
        };
      };

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
