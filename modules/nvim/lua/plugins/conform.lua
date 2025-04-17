return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  opts = function()
    require("conform").setup({
      formatters_by_ft = {
        elixir = { "mix" },
        nix = { "nixpkgs_fmt" },
        ["*"] = { "trim_whitespace" },
      },

      format_on_save = {
        timeout_ms = 500,
        lsp_format = "fallback",
      },

      formatters = {
        mix = {
          command = "mix",
          args = { "format", "-" },
          stdin = true,
        },
      },
    })
  end,
}
