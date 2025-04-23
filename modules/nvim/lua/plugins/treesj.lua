return {
  "Wansmer/treesj",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  vscode = true,
  config = function()
    require("treesj").setup({})
  end,
  keys = {
    {
      "<leader>m",
      function()
        require("treesj").toggle()
      end,
      desc = "Toggle TreeSJ",
    },
    {
      "<leader>M",
      function()
        require("treesj").toggle({ split = { recursive = true } })
      end,
      desc = "Toggle TreeSJ recursive",
    },
  },
}
