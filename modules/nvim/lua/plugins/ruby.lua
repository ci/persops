-- Work hosts skip Ruby tooling (Mason gem installs fail there). Overrides the
-- lang.ruby extra instead of dropping its import so the shared lazy-lock.json
-- keeps its plugins.
if vim.g.persops_profile ~= "work" then
  return {}
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruby_lsp = { enabled = false },
        rubocop = { enabled = false },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return pkg ~= "erb-formatter" and pkg ~= "erb-lint"
      end, opts.ensure_installed or {})
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft.ruby = nil
      opts.formatters_by_ft.eruby = nil
    end,
  },
}
