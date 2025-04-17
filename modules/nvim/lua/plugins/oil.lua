return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    default_file_explorer = false,
    float = {
      max_height = 20,
      max_width = 60,
    },
  },
  keys = {
    { "-", "<CMD>Oil --float<CR>", desc = "Open parent directory" },
  },
}
