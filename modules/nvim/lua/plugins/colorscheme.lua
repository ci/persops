return {
  {
    "aktersnurra/no-clown-fiesta.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
  },
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
  },
  {
    "morhetz/gruvbox",
    lazy = false,
    priority = 1000,
  },
  {
    "f-person/auto-dark-mode.nvim",
    config = function()
      local auto_dark_mode = require("auto-dark-mode")
      auto_dark_mode.setup({
        update_interval = 1000,
        set_dark_mode = function()
          -- vim.cmd("colorscheme no-clown-fiesta")
          -- vim.cmd("colorscheme github_dark")
          -- vim.cmd("colorscheme gruvbox")
          vim.cmd("colorscheme vscode")
        end,
        set_light_mode = function()
          -- vim.cmd("colorscheme catppuccin-latte")
          vim.o.background = "light"
          vim.cmd("colorscheme vscode")
        end,
      })
      auto_dark_mode.init()
    end,
  },
}
