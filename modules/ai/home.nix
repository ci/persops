{ pkgs, inputs, lib, ... }:
let
  llmAgents = inputs.llm-agents.packages.${pkgs.system};
  summarizePackage = pkgs.callPackage ./summarize.nix {
    nodejs = if pkgs ? nodejs_22 then pkgs.nodejs_22 else pkgs.nodejs;
    pnpm = if pkgs ? pnpm_10 then pkgs.pnpm_10 else pkgs.pnpm;
    pkgs = pkgs;
  };
  gifgrepPackage = pkgs.callPackage ./gifgrep.nix { };
  osgrepPackage = pkgs.callPackage ./osgrep.nix { };
  spogoPackage = pkgs.callPackage ./spogo.nix { };
  cudaPkgs =
    if isLinux && pkgs.system == "x86_64-linux" then
      pkgs.cudaPackages_12.overrideScope (final: prev: {
        cuda_compat = pkgs.stdenvNoCC.mkDerivation {
          pname = "cuda_compat";
          version = "disabled";
          dontUnpack = true;
          dontBuild = true;
          installPhase = "mkdir -p $out";
          meta = (prev.cuda_compat.meta or { }) // { available = false; };
        };
      })
    else
      null;
  sherpaOnnxOfflinePackage =
    if cudaPkgs == null then
      null
    else
      pkgs.callPackage ./sherpa-onnx-offline.nix {
        cudaPackages = cudaPkgs;
      };
  isLinux = pkgs.stdenv.isLinux;
  summarizeEnabled = true;
in {

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
    llmAgents.gemini-cli
    llmAgents.opencode
    yt-dlp
    gifgrepPackage
    osgrepPackage
    spogoPackage
    # llm
  ] ++ lib.optionals (summarizeEnabled && isLinux && pkgs.system == "x86_64-linux") [
    summarizePackage
  ] ++ lib.optionals (sherpaOnnxOfflinePackage != null) [
    sherpaOnnxOfflinePackage
  ];

  # OpenCode configuration
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    keybinds = {
      leader = "ctrl+x";
      messages_half_page_up = "ctrl+u";
      messages_half_page_down = "ctrl+d";
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
      };
      defaultSkillBases = [
        ".claude/skills"
        ".codex/skills"
        ".clawdbot/skills"
      ];
      skillTargets = [
        { name = "dev-browser"; source = ./skills/dev-browser; recursive = true; }
        { name = "frontend-design"; source = ./skills/frontend-design; }
        { name = "github-pr"; source = ./skills/github-pr; }
        { name = "jj-version-control"; source = ./skills/jj-version-control; }
        { name = "summarize"; source = "${inputs.nix-steipete-tools}/tools/summarize/skills/summarize"; }
        { name = "spotify-player"; source = ./skills/spotify-player; }
        { name = "transcribe"; source = ./skills/transcribe; }
        { name = "openhue"; source = ./openhue; }
        { name = "opentui"; source = ./skills/opentui; }
        { name = "pdf"; source = ./skills/pdf; }
        { name = "pptx"; source = ./skills/pptx; }
      ];
      mkSkillEntry = base: skill: {
        name = "${base}/${skill.name}";
        value = {
          source = skill.source;
          recursive = skill.recursive or false;
        };
      };
    in
    baseFiles
    // builtins.listToAttrs (
      builtins.concatMap
        (skill: map (base: mkSkillEntry base skill) (skill.bases or defaultSkillBases))
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
    mkdir -p "$HOME/.clawdbot/skills/dev-browser/node_modules"
    mkdir -p "$HOME/.clawdbot/skills/dev-browser/profiles"
    mkdir -p "$HOME/.clawdbot/skills/dev-browser/tmp"
  '';

}
