{ pkgs, inputs, lib, config, ... }:
let
  llmAgents = inputs.llm-agents.packages.${pkgs.system};
  summarizePackage = pkgs.callPackage ./summarize.nix {
    nodejs = if pkgs ? nodejs_22 then pkgs.nodejs_22 else pkgs.nodejs;
    pnpm = if pkgs ? pnpm_10 then pkgs.pnpm_10 else pkgs.pnpm;
    pkgs = pkgs;
  };
  gifgrepPackage = pkgs.callPackage ./gifgrep.nix { };
  spogoPackage = pkgs.callPackage ./spogo.nix { };
  isLinux = pkgs.stdenv.isLinux;
  summarizeEnabled = true;
  homeDir = config.home.homeDirectory;
  clawdbotSecretsDir = "${homeDir}/.secrets";
  clawdbotGatewayPort = 18789;
  # Temporary workaround for missing bundled extensions in nix-clawdbot.
  # See: https://github.com/clawdbot/nix-clawdbot/issues/6
  clawdbotExtensionsSrc = pkgs.fetchFromGitHub {
    owner = "clawdbot";
    repo = "clawdbot";
    rev = "c21469b282213cbcc1858921dc668b1cc5e29f7e";
    hash = "sha256-DklaX3pZ/Za/ki1xRimvz2MU4gzrur9+Yi6jFw9ceXQ=";
  };
  clawdbotExtensions = pkgs.runCommand "clawdbot-extensions" { } ''
    set -euo pipefail
    mkdir -p "$out"
    cp -R ${clawdbotExtensionsSrc}/extensions/* "$out/"
    chmod -R u+w "$out"
    for dir in "$out"/*; do
      if [ -d "$dir" ]; then
        id="$(basename "$dir")"
        ${lib.getExe pkgs.jq} -n \
          --arg id "$id" \
          '{
            id: $id,
            configSchema: { type: "object", additionalProperties: true }
          }' > "$dir/clawdbot.plugin.json"
      fi
    done
  '';
in {
  imports = [
    inputs.nix-clawdbot.homeManagerModules.clawdbot
  ];

  # AI agent packages
  home.packages = with pkgs; [
    llmAgents.amp
    codex
    claude-code
    llmAgents.claude-code-acp
    llmAgents.claude-plugins
    llmAgents.codex-acp
    # llmAgents.copilot-cli
    llmAgents.cursor-agent
    # disabled temp: https://github.com/numtide/llm-agents.nix/issues/1644
    # llmAgents.gemini-cli
    llmAgents.opencode
    yt-dlp
    gifgrepPackage
    spogoPackage
    # llm
  ] ++ lib.optionals (summarizeEnabled && isLinux && pkgs.system == "x86_64-linux") [
    summarizePackage
  ];

  programs.clawdbot = {
    package = if isLinux then pkgs.clawdbot-gateway else pkgs.clawdbot-app;
    appPackage = if pkgs.stdenv.isDarwin then pkgs.clawdbot-app else null;
    # Seed editable workspace docs from modules/ai/clawdbot-documents on first run (manual copy).
    firstParty.peekaboo.enable = pkgs.stdenv.isDarwin;
    firstParty.summarize.enable = pkgs.stdenv.isDarwin;
    instances.default = {
      enable = true;
      gatewayPort = clawdbotGatewayPort;
      systemd.enable = isLinux;
      launchd.enable = false;
      appDefaults.attachExistingOnly = true;

      agent.model = "openai-codex/gpt-5.2";

      configOverrides = {
        agents = {
          list = [
            {
              id = "main";
              default = true;
              identity = {
                name = "Cat Prime";
                theme = "warm, crisp, direct/precise";
                emoji = "👻🐈‍⬛";
              };
            }
          ];
        };
        gateway = {
          bind = "loopback";
          tailscale = { mode = "serve"; };
        };

        channels = {
          telegram = {
            enabled = true;
            tokenFile = "${clawdbotSecretsDir}/telegram.bot.token";
            allowFrom = [ 367809160 ];
            dmPolicy = "pairing";
            groupPolicy = "disabled";
            groups = {
              "*" = { requireMention = true; };
            };
          };
          discord = {
            enabled = true;
            guilds = {
              "1459993647964618843" = {
                requireMention = true;
                users = [
                  "303646090807214093"
                  "305098219501912078"
                  "ca7ir"
                  "periqles"
                ];
                channels = {
                  "general" = { allow = true; };
                };
              };
            };
          };
          whatsapp = {
            dmPolicy = "allowlist";
            allowFrom = [
              "+40763641549"
            ];
            groupPolicy = "allowlist";
            groupAllowFrom = [
              "+40763641549"
              "+40787895941"
            ];
            groups = {
              "120363403134225234@g.us" = { requireMention = true; };
            };
          };
        };

        messages = lib.mkForce {
          queue = {
            mode = "interrupt";
            byChannel = {
              discord = "queue";
              telegram = "interrupt";
              webchat = "queue";
            };
          };
        };

        skills = {
          install = {
            nodeManager = "bun";
          };
        };
      } // lib.optionalAttrs isLinux {
        browser = {
          executablePath = "/run/current-system/sw/bin/chromium";
          headless = true;
        };
      };
    };
  };

  # systemd user services don't inherit /run/current-system/sw/bin; add tailscale for gateway serve
  systemd.user.services = lib.mkIf isLinux {
    clawdbot-gateway.Service = {
      Environment = lib.mkAfter [
        "PATH=${lib.makeBinPath [ pkgs.tailscale ]}:/run/current-system/sw/bin:/run/wrappers/bin:${config.home.profileDirectory}/bin"
      ];
      EnvironmentFile = [
        "-${clawdbotSecretsDir}/discord.bot.token"
      ];
    };
  };



  # OpenCode configuration
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    plugin = [
      "oh-my-opencode"
      "opencode-openai-codex-auth@4.1.1"
      "opencode-antigravity-auth@1.2.7"
    ];
    keybinds = {
      leader = "ctrl+x";
      messages_half_page_up = "ctrl+u";
      messages_half_page_down = "ctrl+d";
    };
    provider = {
      google = {
        models = {
          # Antigravity Quota - Gemini 3 models
          antigravity-gemini-3-pro-low = {
            name = "Gemini 3 Pro Low (Antigravity)";
            limit = { context = 1048576; output = 65535; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          antigravity-gemini-3-pro-high = {
            name = "Gemini 3 Pro High (Antigravity)";
            limit = { context = 1048576; output = 65535; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          antigravity-gemini-3-flash = {
            name = "Gemini 3 Flash (Antigravity)";
            limit = { context = 1048576; output = 65536; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          # Legacy names (backward compatibility)
          gemini-3-pro-low = {
            name = "Gemini 3 Pro Low (Antigravity)";
            limit = { context = 1048576; output = 65535; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          gemini-3-pro-high = {
            name = "Gemini 3 Pro High (Antigravity)";
            limit = { context = 1048576; output = 65535; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          gemini-3-flash = {
            name = "Gemini 3 Flash (Antigravity)";
            limit = { context = 1048576; output = 65536; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          # Antigravity Quota - Claude models
          antigravity-claude-sonnet-4-5 = {
            name = "Claude Sonnet 4.5 (Antigravity)";
            limit = { context = 200000; output = 64000; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          antigravity-claude-sonnet-4-5-thinking-low = {
            name = "Claude Sonnet 4.5 Think Low (Antigravity)";
            limit = { context = 200000; output = 64000; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          antigravity-claude-sonnet-4-5-thinking-medium = {
            name = "Claude Sonnet 4.5 Think Medium (Antigravity)";
            limit = { context = 200000; output = 64000; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          antigravity-claude-sonnet-4-5-thinking-high = {
            name = "Claude Sonnet 4.5 Think High (Antigravity)";
            limit = { context = 200000; output = 64000; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          antigravity-claude-opus-4-5-thinking-low = {
            name = "Claude Opus 4.5 Think Low (Antigravity)";
            limit = { context = 200000; output = 64000; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          antigravity-claude-opus-4-5-thinking-medium = {
            name = "Claude Opus 4.5 Think Medium (Antigravity)";
            limit = { context = 200000; output = 64000; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          antigravity-claude-opus-4-5-thinking-high = {
            name = "Claude Opus 4.5 Think High (Antigravity)";
            limit = { context = 200000; output = 64000; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          # Gemini CLI Quota models
          "gemini-2.5-flash" = {
            name = "Gemini 2.5 Flash (CLI)";
            limit = { context = 1048576; output = 65536; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          "gemini-2.5-pro" = {
            name = "Gemini 2.5 Pro (CLI)";
            limit = { context = 1048576; output = 65536; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          gemini-3-flash-preview = {
            name = "Gemini 3 Flash Preview (CLI)";
            limit = { context = 1048576; output = 65536; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
          gemini-3-pro-preview = {
            name = "Gemini 3 Pro Preview (CLI)";
            limit = { context = 1048576; output = 65535; };
            modalities = { input = ["text" "image" "pdf"]; output = ["text"]; };
          };
        };
      };
    };
  };

  # Oh My OpenCode configuration
  xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
    agents = {
      explore = { model = "anthropic/claude-haiku-4-5"; };
    };
  };

  # OpenCode commands
  xdg.configFile."opencode/command/commit.md".source = ./commands/commit.md;
  xdg.configFile."opencode/command/rmslop.md".source = ./commands/rmslop.md;

  # Global agent instructions for Claude Code, Codex, and OpenCode
  xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;

  # Skills for agents
  home.file =
    let
      baseFiles = {
        ".claude/CLAUDE.md".source = ./AGENTS.md;
        ".codex/AGENTS.md".source = ./AGENTS.md;
        ".summarize/config.json".text = builtins.toJSON {
          model = {
            mode = "auto";
            rules = [
              {
                when = [ "video" ];
                candidates = [ "google/gemini-3-flash-preview" ];
              }
              {
                candidates = [ "cli/codex/gpt-5.2" ];
              }
            ];
          };
          media = { videoMode = "auto"; };
        };
      } // lib.optionalAttrs isLinux {
        ".clawdbot/extensions" = {
          source = clawdbotExtensions;
          recursive = true;
        };
      };
      skillTargets = [
        {
          name = "dev-browser";
          bases = [
            ".claude/skills"
            ".codex/skills"
          ];
          source = ./skills/dev-browser;
          recursive = true;
        }
        {
          name = "github-pr";
          bases = [
            ".claude/skills"
            ".codex/skills"
            ".clawdbot/skills"
          ];
          source = ./skills/github-pr;
          recursive = true;
        }
        {
          name = "jj-version-control";
          bases = [
            ".claude/skills"
            ".codex/skills"
            ".clawdbot/skills"
          ];
          source = ./skills/jj-version-control;
          recursive = true;
        }
        {
          name = "summarize";
          bases = [
            ".claude/skills"
            ".codex/skills"
            ".clawdbot/skills"
          ];
          source = "${inputs.nix-steipete-tools}/tools/summarize/skills/summarize";
          recursive = true;
        }
        {
          name = "spotify-player";
          bases = [
            ".claude/skills"
            ".codex/skills"
            ".clawdbot/skills"
          ];
          source = ./skills/spotify-player;
          recursive = true;
        }
        {
          name = "transcribe";
          bases = [
            ".claude/skills"
            ".codex/skills"
            ".clawdbot/skills"
          ];
          source = ./skills/transcribe;
          recursive = true;
        }
        {
          name = "openhue";
          bases = [
            ".claude/skills"
            ".codex/skills"
            ".clawdbot/skills"
          ];
          source = ./openhue;
          recursive = true;
        }
        {
          name = "pdf";
          bases = [
            ".claude/skills"
            ".codex/skills"
            ".clawdbot/skills"
          ];
          source = ./skills/pdf;
          recursive = true;
        }
        {
          name = "pptx";
          bases = [
            ".claude/skills"
            ".codex/skills"
            ".clawdbot/skills"
          ];
          source = ./skills/pptx;
          recursive = true;
        }
      ];
      mkSkillEntry = base: skill: {
        name = "${base}/${skill.name}";
        value = {
          source = skill.source;
          recursive = skill.recursive;
        };
      };
    in
    baseFiles
    // builtins.listToAttrs (
      builtins.concatMap
        (skill: map (base: mkSkillEntry base skill) skill.bases)
        skillTargets
    );

  # Create writable directories for dev-browser skill (node_modules, profiles, tmp)
  home.activation.createDevBrowserDirs = ''
    mkdir -p "$HOME/.claude/skills/dev-browser/node_modules"
    mkdir -p "$HOME/.claude/skills/dev-browser/profiles"
    mkdir -p "$HOME/.claude/skills/dev-browser/tmp"
    mkdir -p "$HOME/.codex/skills/dev-browser/node_modules"
    mkdir -p "$HOME/.codex/skills/dev-browser/profiles"
    mkdir -p "$HOME/.codex/skills/dev-browser/tmp"
  '';

  home.activation.fixClawdbotConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    config_path="$HOME/.clawdbot/clawdbot.json"
    if [ -f "$config_path" ]; then
      tmp="$(mktemp)"
      cp "$config_path" "$tmp"
      rm -f "$config_path"
      ${lib.getExe pkgs.jq} '
        if (.messages | type == "object")
          and (.messages | has("_type"))
          and (.messages | has("content")) then
          .messages = .messages.content
        else
          .
        end
        | if (.messages | type == "object")
          and (.messages.queue? != null)
          and (.messages.queue | type == "object")
          and (.messages.queue.byProvider? != null) then
            .messages.queue.byChannel = (.messages.queue.byChannel // .messages.queue.byProvider)
            | del(.messages.queue.byProvider)
          else
            .
          end
      ' "$tmp" > "$config_path"
      rm -f "$tmp"
    fi
  '';
}
