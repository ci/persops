return {
  "stevearc/conform.nvim",
  vscode = true,
  opts = {
    formatters_by_ft = {
      elixir = { "mix" },
      ruby = { "rubocop" },
      nix = { "nixfmt" },
      ["*"] = { "trim_whitespace" },
    },
    formatters = {
      mix = {
        command = "mix",
        args = { "format", "-" },
        stdin = true,
      },
    },
  },
}
