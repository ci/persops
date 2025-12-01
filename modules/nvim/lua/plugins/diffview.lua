return {
  {
    "sindrets/diffview.nvim",
    keys = {
      { "<leader>gdo", "<cmd>DiffviewOpen<cr>", desc = "Open diffview" },
      { "<leader>gdc", "<cmd>DiffviewClose<cr>", desc = "Close diffview" },
      { "<leader>gdf", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
      { "<leader>gdh", "<cmd>DiffviewFileHistory<cr>", desc = "Branch history" },
    },
    opts = function()
      local actions = require("diffview.actions")

      return {
        enhanced_diff_hl = true,
        file_panel = {
          win_config = {
            width = math.floor(vim.go.columns * 0.2) > 25 and math.floor(vim.go.columns * 0.2) or 25,
          },
        },
        hooks = {
          diff_buf_win_enter = function(_, winid)
            vim.wo[winid].wrap = false
          end,
        },
        keymaps = {
          view = {
            { "n", "q", actions.close, { desc = "Close diffview" } },
            { "n", "<Esc>", actions.close, { desc = "Close diffview" } },
          },
          file_panel = {
            { "n", "q", actions.close, { desc = "Close diffview" } },
            { "n", "<Esc>", actions.close, { desc = "Close diffview" } },
          },
          file_history_panel = {
            { "n", "q", actions.close, { desc = "Close diffview" } },
            { "n", "<Esc>", actions.close, { desc = "Close diffview" } },
          },
        },
      }
    end,
  },
}
