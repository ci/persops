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
        (_: prev: {
          # codex-cli-nix installs only the main codex binary, but codex >= 0.144 spawns
          # a sibling codex-code-mode-host for ALL shell execution — without it every
          # `codex exec` dies with "failed to spawn code-mode host". Graft the matching
          # release asset next to codex-raw. The hash map throws on version bumps so the
          # host can't silently drift from the CLI (prefetch the new asset hash with:
          # nix store prefetch-file <github release asset url>).
          codex =
            let
              system = prev.stdenv.hostPlatform.system;
              hostTargets = {
                "aarch64-darwin" = "aarch64-apple-darwin";
                "x86_64-linux" = "x86_64-unknown-linux-musl";
              };
              hostTarget = hostTargets.${system} or null;
            in
            if hostTarget == null then
              prev.codex
            else
              prev.codex.overrideAttrs (
                old:
                let
                  hostHashes = {
                    "0.144.0" = {
                      "aarch64-darwin" = "sha256-bPkoJDC+/lQTacfLKARgSn8N2UFvOjJB42dtsiAiokY=";
                      "x86_64-linux" = "sha256-JtnGXFqUfCv0iVE+9/geAnsMltwV4ngd5u7V4CoYmT0=";
                    };
                    "0.147.0" = {
                      "aarch64-darwin" = "sha256-Vs2/YYe/kUEI07f+7qWjT/uhXlwWK+3OaeBi7pLd+14=";
                      "x86_64-linux" = "sha256-AUat+qyDY+yfzbWJX3Yk21suhheig4h5OLf7l6HdQ1Y=";
                    };
                    "0.149.0" = {
                      "aarch64-darwin" = "sha256-7WpqCJxQ5yfvHwZC7nwGEbphHXbXICkxagUTvpG/skQ=";
                      "x86_64-linux" = "sha256-NgCkWsKwn+PJlfT0mGATH+o4i0bECcgqAmb8TQNCoEw=";
                    };
                  };
                  hostTarball = prev.fetchurl {
                    url = "https://github.com/openai/codex/releases/download/rust-v${old.version}/codex-code-mode-host-${hostTarget}.tar.gz";
                    hash =
                      hostHashes.${old.version}.${system}
                        or (throw "codex ${old.version} on ${system}: add the codex-code-mode-host asset hash to hostHashes in flake.nix");
                  };
                in
                {
                  postInstall = (old.postInstall or "") + ''
                    tar -xzf ${hostTarball} -C $out/bin
                    if [ -e $out/bin/codex-code-mode-host-${hostTarget} ]; then
                      mv $out/bin/codex-code-mode-host-${hostTarget} $out/bin/codex-code-mode-host
                    fi
                    chmod +x $out/bin/codex-code-mode-host
                  '';
                }
              );
        })
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
