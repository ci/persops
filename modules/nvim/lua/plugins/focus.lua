return {
  "nvim-focus/focus.nvim",
  version = false,
  event = "BufEnter",
  config = function()
    require("focus").setup()
  end,
}
