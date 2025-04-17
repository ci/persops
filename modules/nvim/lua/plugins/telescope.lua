return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make", lazy = true },
  },
  config = function()
    -- local wk = require("which-key")
    local actions = require("telescope.actions")
    -- local icons = require("lazyvim.config").icons

    -- wk.register({
    --   ["<leader>bb"] = { "<cmd>Telescope buffers previewer=false<cr>", "Find buffers" },
    --   ["<leader>,"] = { "<cmd>Telescope buffers preview=false<cr>", "Find buffers" },
    --   ["<leader>gb"] = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
    --   ["<leader>fk"] = { "<cmd>Telescope keymaps<cr>", "Keymaps" },
    --   ["<leader>ff"] = { "<cmd>Telescope find_files<cr>", "Find files" },
    --   ["<leader>fp"] = { "<cmd>lua require('telescope').extensions.projects.projects()<cr>", "Projects" },
    --   ["<leader>fg"] = { "<cmd>Telescope live_grep<cr>", "Find grep" },
    --   ["<leader>fh"] = { "<cmd>Telescope help_tags<cr>", "Help" },
    --   ["<leader>cb"] = { "<cmd>Telescope current_buffer_fuzzy_find<cr>", "Current buffer" },
    --   ["<leader>fr"] = { "<cmd>Telescope oldfiles<cr>", "Recent file" },
    -- })

    require("telescope").setup({
      defaults = {
        -- prompt_prefix = icons.ui.Telescope .. " ",
        -- selection_caret = icons.ui.Forward .. " ",
        entry_prefix = "   ",
        initial_mode = "insert",
        selection_strategy = "reset",
        path_display = { "smart" },
        color_devicons = true,
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--hidden",
          "--glob=!.git/",
        },
        mappings = {
          i = {
            ["<C-n>"] = actions.cycle_history_next,
            ["<C-p>"] = actions.cycle_history_prev,
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
          },
          n = {
            ["<esc>"] = actions.close,
            ["j"] = actions.move_selection_next,
            ["k"] = actions.move_selection_previous,
            ["q"] = actions.close,
          },
        },
      },
      pickers = {
        live_grep = { theme = "dropdown" },
        grep_string = { theme = "dropdown" },
        find_files = { theme = "dropdown", previewer = false },
        buffers = {
          theme = "dropdown",
          previewer = false,
          initial_mode = "normal",
          mappings = {
            i = { ["<C-d>"] = actions.delete_buffer },
            n = { ["dd"] = actions.delete_buffer },
          },
        },
        planets = { show_pluto = true, show_moon = true },
        colorscheme = { enable_preview = true },
        lsp_references = { theme = "dropdown", initial_mode = "normal" },
        lsp_definitions = { theme = "dropdown", initial_mode = "normal" },
        lsp_declarations = { theme = "dropdown", initial_mode = "normal" },
        lsp_implementations = { theme = "dropdown", initial_mode = "normal" },
      },
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
      },
    })
  end,
}
