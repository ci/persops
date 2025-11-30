return {
  "olimorris/codecompanion.nvim",
  tag = "v17.33.0",
  opts = {
    adapters = {
      acp = {
        claude_code = function()
          return require("codecompanion.adapters").extend("claude_code", {
            env = {
              CLAUDE_CODE_OAUTH_TOKEN = "cmd:cat ~/.config/claude-code-oauth.token",
            },
          })
        end,
      },
    },
    strategies = {
      chat = {
        adapter = "claude_code",
        model = "claude-opus-4.5",
      },
      inline = {
        adapter = "claude_code",
        model = "claude-opus-4.5",
      },
      cmd = {
        adapter = "claude_code",
        model = "claude-opus-4.5",
      },
    },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
}
