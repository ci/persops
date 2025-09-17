return {
  "stevearc/oil.nvim",
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    default_file_explorer = false,
    -- float = {
    --   max_height = 20,
    --   max_width = 60,
    -- },
  },
  dependencies = { { "nvim-mini/mini.icons", opts = {} } },
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
  keys = {
    { "-", "<CMD>Oil --float<CR>", desc = "Open parent directory" },
  },
}
