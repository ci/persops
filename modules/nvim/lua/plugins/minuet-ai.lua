return {
  "milanglacier/minuet-ai.nvim",
  config = function()
    require("minuet").setup({
      n_completions = 1,
      provider = "gemini",
      provider_options = {
        gemini = {
          api_key = "NVIM_GEMINI_API_KEY",
          optional = {
            generationConfig = {
              maxOutputTokens = 256,
              -- When using `gemini-2.5-flash`, it is recommended to entirely
              -- disable thinking for faster completion retrieval.
              -- thinkingConfig = {
              -- thinkingBudget = 0,
              -- },
            },
          },
        },
      },
      virtualtext = {
        auto_trigger_ft = {
          "bash",
          "c",
          "cpp",
          "css",
          "csv",
          "dockerfile",
          "elixir",
          "go",
          "gomod",
          "html",
          "javascript",
          "javascriptreact",
          "json",
          "jsonc",
          "jsonnet",
          "lua",
          "markdown",
          "nix",
          "php",
          "python",
          "ruby",
          "sql",
          "terraform",
          "toml",
          "typescript",
          "typescriptreact",
          "xml",
          "yaml",
        },
        auto_trigger_ignore_ft = {
          "sh",
        },
        show_on_completion_menu = true,
        keymap = {
          -- accept whole completion
          accept = "<A-a>",
          -- accept one line
          accept_line = "<A-A>",
          -- accept n lines (prompts for number)
          -- e.g. "A-z 2 CR" will accept 2 lines
          accept_n_lines = "<A-z>",
          -- Cycle to prev completion item, or manually invoke completion
          prev = "<A-[>",
          -- Cycle to next completion item, or manually invoke completion
          next = "<A-]>",
          dismiss = "<A-e>",
        },
      },
    })
  end,
  dependencies = { { "nvim-lua/plenary.nvim" } },
}
