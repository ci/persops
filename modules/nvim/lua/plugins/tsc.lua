return {
  "dmmulroy/tsc.nvim",
  opts = {
    auto_start_watch_mode = false,
    use_trouble_qflist = false,
    run_as_monorepo = true,
    flags = {
      watch = false,
    },
  },
  keys = {
    { "<leader>ctc", ft = { "typescript", "typescriptreact" }, "<cmd>TSC<cr>", desc = "Type Check" },
    { "<leader>ctq", ft = { "typescript", "typescriptreact" }, "<cmd>TSCOpen<cr>", desc = "Type Check Quickfix" },
  },
  ft = {
    "typescript",
    "typescriptreact",
  },
  cmd = {
    "TSC",
    "TSCOpen",
    "TSCClose",
  },
}
