return {
  {
    "echasnovski/mini.cursorword",
    version = false,
    event = "LazyFile",
    config = function(_, opts)
      require("mini.cursorword").setup(opts)
    end,
  },
}
