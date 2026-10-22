-- illumos-gate: clangd without a compile database, cstyle lint, cscope.
-- Buffer options live in config/illumos.lua.
local illumos = require("config.illumos")

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local clangd = opts.servers.clangd
      local markers = clangd.root_markers
      clangd.root_dir = function(bufnr, on_dir)
        on_dir(illumos.clangd_root(vim.api.nvim_buf_get_name(bufnr)) or vim.fs.root(bufnr, markers))
      end
      clangd.before_init = function(params, config)
        local flags = config.root_dir and illumos.clangd_flags(config.root_dir)
        if flags then
          params.initializationOptions =
            vim.tbl_extend("force", params.initializationOptions or {}, { fallbackFlags = flags })
        end
      end
    end,
  },

  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft.c = { "cstyle" }
      -- Same checks as `git pbchk`, using the checkout's own cstyle.pl.
      opts.linters.cstyle = {
        cmd = "perl",
        stdin = true,
        args = {
          function()
            return illumos.root(vim.api.nvim_buf_get_name(0)) .. "/usr/src/tools/scripts/cstyle.pl"
          end,
          "-cpP",
        },
        ignore_exitcode = true,
        parser = require("lint.parser").from_errorformat("<stdin>: %l: %m", {
          source = "cstyle",
          severity = vim.diagnostic.severity.WARN,
        }),
        condition = function(ctx)
          return illumos.root(ctx.filename) ~= nil
        end,
      }
    end,
  },

  {
    "dhananjaylatkar/cscope_maps.nvim",
    ft = { "c" },
    cmd = { "Cscope", "Cs", "Cstag" },
    opts = {
      -- LazyVim owns <leader>c (code actions).
      prefix = "<leader>C",
      cscope = {
        picker = "snacks",
        -- Build from the repo root over the whole tree; -k skips /usr/include.
        db_build_cmd = { script = "default", args = { "-Rbqkv" } },
        project_rooter = { enable = true },
        -- Keep <C-]> on the LSP tagfunc everywhere else.
        tag = { keymap = false },
      },
    },
  },
}
