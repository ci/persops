{ pkgs, inputs, ... }:
let
  llmAgents = inputs.llm-agents.packages.${pkgs.system};
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
    # disabled temp: https://github.com/numtide/llm-agents.nix/issues/1644
    # llmAgents.gemini-cli
    llmAgents.opencode
    # llm
  ];

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
  home.file.".claude/CLAUDE.md".source = ./AGENTS.md;
  home.file.".codex/AGENTS.md".source = ./AGENTS.md;
  xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;
}
