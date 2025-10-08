return {
  "laytan/cloak.nvim",
  lazy = false,
  config = function()
    require("cloak").setup({
      enabled = true,
      cloak_character = "*",
      highlight_group = "Comment",
      cloak_length = nil,
      try_all_patterns = true,
      cloak_telescope = true,
      patterns = {
        {
          file_pattern = {
            ".env*",
            "wrangler.toml",
            ".dev.vars",
          },
          cloak_pattern = "=.+",
          replace = nil,
        },
      },
    })
  end,
  keys = {
    { "<leader>bct", "<cmd>CloakToggle<cr>", desc = "Toggle cloak mode" },
    { "<leader>bcc", "<cmd>CloakPreviewLine<cr>", desc = "Preview current line with cloak" },
  },
}
