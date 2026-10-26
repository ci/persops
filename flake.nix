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
    # Fork of v0.9.3: `dev` merges the copy-mode feature branches (not upstreamable).
    herdr = {
      url = "github:ci/herdr/dev";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Fork of upstream main: `dev` merges the personal feature branches (:catchup, :bookmarks,
    # :nicks, decrypting history from key backup).
    iamb = {
      url = "github:ci/iamb/dev";
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
    opnix = {
      url = "github:brizzbuzz/opnix/v0.11.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rex = {
      url = "https://pkgs.superlogical.com/rex/nix/snapshot.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      overlays = [
        inputs."codex-cli-nix".overlays.default
        (
          _: prev:
          let
            master = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system};
          in
          {
            inherit (master) gh gh-stack;
            # HACK: pnpm 12.3.4 deletes the pinned engine in hoisted workspaces (#14595).
            # TODO: remove this override once nixpkgs-unstable includes the fix (#14643).
            inherit (master) pnpm;
          }
        )
        inputs."claude-code-nix".overlays.default
        inputs.jj-starship.overlays.default
        inputs.tmux-sessionizer.overlays.default
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
        pkgs.jq
        pkgs.nixfmt
        pkgs.nodejs
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
                pkgs.jujutsu
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
                  pkgs.git
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
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          sea16 = import ./tests/sea16.nix { inherit pkgs; };
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

      darwinConfigurations."ergane" = mkSystem "ergane" {
        system = "aarch64-darwin";
        user = "cat";
        darwin = true;
        profile = "work";
      };

      nixosConfigurations."amalthea" = mkSystem "amalthea" {
        system = "x86_64-linux";
        user = "cat";
      };
    };
}
