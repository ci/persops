return {
  "HiPhish/rainbow-delimiters.nvim",
  vscode = true,
  config = function()
    require("rainbow-delimiters.setup").setup({
      highlight = {
        "RainbowDelimiterYellow",
        "RainbowDelimiterBlue",
        "RainbowDelimiterOrange",
        "RainbowDelimiterGreen",
        "RainbowDelimiterViolet",
        "RainbowDelimiterCyan",
      },
    })
  end,
}
