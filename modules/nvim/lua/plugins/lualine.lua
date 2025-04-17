return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = function()
    -- Color table for highlights
    local colors = {
      bg = "#202328",
      fg = "#bbc2cf",
      yellow = "#ECBE7B",
      cyan = "#008080",
      darkblue = "#081633",
      green = "#98be65",
      orange = "#FF8800",
      violet = "#a9a1e1",
      magenta = "#c678dd",
      blue = "#51afef",
      red = "#ec5f67",
    }

    local conditions = {
      buffer_not_empty = function()
        return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
      end,
      hide_in_width = function()
        return vim.fn.winwidth(0) > 80
      end,
      check_git_workspace = function()
        local filepath = vim.fn.expand("%:p:h")
        local gitdir = vim.fn.finddir(".git", filepath .. ";")
        return gitdir and #gitdir > 0 and #gitdir < #filepath
      end,
    }

    local config = {
      options = {
        component_separators = "",
        section_separators = "",
        theme = {
          normal = { c = { fg = colors.fg, bg = colors.bg } },
          inactive = { c = { fg = colors.fg, bg = colors.bg } },
        },
        disabled_filetypes = { statusline = { "dashboard", "alpha" } },
      },
      sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_y = {},
        lualine_z = {},
        lualine_c = {},
        lualine_x = {},
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_y = {},
        lualine_z = {},
        lualine_c = {},
        lualine_x = {},
      },
    }

    -- Inserts a component in lualine_c at left section
    local function ins_left(component)
      table.insert(config.sections.lualine_c, component)
    end

    -- Inserts a component in lualine_x at right section
    local function ins_right(component)
      table.insert(config.sections.lualine_x, component)
    end

    -- ins_left({
    --   function()
    --     return "▊"
    --   end,
    --   color = { fg = colors.blue },
    --   padding = { left = 0, right = 1 },
    -- })

    -- Mode component with visible text indicator
    ins_left({
      function()
        local mode_map = {
          n = "normal",
          i = "insert",
          v = "visual",
          [""] = "v-block", -- This isn't showing correctly
          ["\22"] = "v-block", -- Added this line to fix V-BLOCK
          V = "v-line",
          c = "command",
          no = "op-pending",
          s = "select",
          S = "s-line",
          [""] = "s-block",
          ic = "ins-comp",
          R = "replace",
          Rv = "v-replace",
          cv = "ex",
          ce = "normal ex",
          r = "prompt",
          rm = "more",
          ["r?"] = "confirm",
          ["!"] = "shell",
          t = "terminal",
        }
        return mode_map[vim.fn.mode()] or vim.fn.mode()
      end,
      color = function()
        local mode_color = {
          n = colors.blue, -- Changed from red to blue for normal mode
          i = colors.green,
          v = colors.blue,
          [""] = colors.blue,
          ["\22"] = colors.blue, -- Added for V-BLOCK
          V = colors.blue,
          c = colors.magenta,
          no = colors.red,
          s = colors.orange,
          S = colors.orange,
          [""] = colors.orange,
          ic = colors.yellow,
          R = colors.violet,
          Rv = colors.violet,
          cv = colors.red,
          ce = colors.red,
          r = colors.cyan,
          rm = colors.cyan,
          ["r?"] = colors.cyan,
          ["!"] = colors.red,
          t = colors.red,
        }
        return { fg = colors.bg, bg = mode_color[vim.fn.mode()] or colors.blue, gui = "bold" }
      end,
      padding = { left = 1, right = 1 },
    })

    ins_left({
      "filesize",
      cond = conditions.buffer_not_empty,
    })

    ins_left({
      "filename",
      cond = conditions.buffer_not_empty,
      color = { fg = colors.magenta, gui = "bold" },
    })

    ins_left({ "location" })

    ins_left({ "progress", color = { fg = colors.fg, gui = "bold" } })

    ins_left({
      "diagnostics",
      sources = { "nvim_diagnostic" },
      symbols = { error = " ", warn = " ", info = " " },
      diagnostics_color = {
        error = { fg = colors.red },
        warn = { fg = colors.yellow },
        info = { fg = colors.cyan },
      },
    })

    -- Insert mid section. You can make any number of sections in neovim :)
    -- for lualine it's any number greater then 2
    ins_left({
      function()
        return "%="
      end,
    })

    -- Improved LSP component with better styling
    ins_left({
      function()
        local buf_ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
        local clients = vim.lsp.get_clients()
        local active_lsps = {}

        if next(clients) == nil then
          return "no lsp"
        end

        for _, client in ipairs(clients) do
          local filetypes = client.config.filetypes
          if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
            table.insert(active_lsps, client.name)
          end
        end

        return #active_lsps > 0 and table.concat(active_lsps, ", ") or "no lsp"
      end,
      icon = " ",
      color = { fg = colors.cyan, gui = "bold" },
    })

    ins_right({
      "o:encoding",
      fmt = function(str)
        return string.lower(str)
      end, -- Changed to lowercase
      cond = conditions.hide_in_width,
      color = { fg = colors.green, gui = "bold" },
    })

    ins_right({
      "fileformat",
      fmt = function(str)
        return string.lower(str)
      end, -- Changed to lowercase
      icons_enabled = false,
      color = { fg = colors.green, gui = "bold" },
    })

    ins_right({
      "branch",
      icon = "",
      color = { fg = colors.violet, gui = "bold" },
    })

    ins_right({
      "diff",
      symbols = { added = " ", modified = "󰝤 ", removed = " " },
      diff_color = {
        added = { fg = colors.green },
        modified = { fg = colors.orange },
        removed = { fg = colors.red },
      },
      cond = conditions.hide_in_width,
    })

    -- ins_right({
    --   function()
    --     return "▊"
    --   end,
    --   color = { fg = colors.blue },
    --   padding = { left = 1 },
    -- })

    return config
  end,
}
