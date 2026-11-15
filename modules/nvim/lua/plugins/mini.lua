return {
  {
    "nvim-mini/mini.cursorword",
    version = false,
    event = "LazyFile",
    config = function(_, opts)
      require("mini.cursorword").setup(opts)
    end,
  },
  {
    "nvim-mini/mini.operators",
    version = false,
    config = function(_, opts)
      require("mini.operators").setup(opts)
    end,
  },
}
