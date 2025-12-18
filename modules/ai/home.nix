{ lib, pkgs, inputs, ... }:
let
  llmAgents = inputs.llm-agents.packages.${pkgs.system};
in {
  # AI agent packages
  home.packages = with pkgs; [
    llmAgents.amp
    llmAgents.beads
    codex
    claude-code
    llmAgents.claude-code-acp
    llmAgents.claude-plugins
    llmAgents.codex-acp
    llmAgents.copilot-cli
    llmAgents.cursor-agent
    llmAgents.gemini-cli
    llmAgents.opencode
    llm
  ];

  # OpenCode configuration
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    plugin = [
      "oh-my-opencode"
      "opencode-openai-codex-auth@4.1.1"
      "opencode-antigravity-auth@1.1.2"
    ];
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
}
