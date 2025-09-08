return {
  "olimorris/codecompanion.nvim",
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
        model = "claude-opus-4.1",
      },
      inline = {
        adapter = "claude_code",
        model = "claude-opus-4.1",
      },
      cmd = {
        adapter = "claude_code",
        model = "claude-opus-4.1",
      },
    },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
}
