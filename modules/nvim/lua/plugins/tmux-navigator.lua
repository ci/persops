return {
  {
    "mrjones2014/smart-splits.nvim",
    event = "VeryLazy",
    dependencies = {
      "pogyomo/submode.nvim",
    },
    keys = {
      {
        "<c-h>",
        function()
          require("smart-splits").move_cursor_left()
        end,
      },
      {
        "<c-j>",
        function()
          require("smart-splits").move_cursor_down()
        end,
      },
      {
        "<c-k>",
        function()
          require("smart-splits").move_cursor_up()
        end,
      },
      {
        "<c-l>",
        function()
          require("smart-splits").move_cursor_right()
        end,
      },
      {
        "<c-\\>",
        function()
          require("smart-splits").move_cursor_previous()
        end,
      },
      {
        "<leader>wh",
        function()
          require("smart-splits").swap_buf_left()
        end,
        desc = "Swap buffer left",
      },
      {
        "<leader>wj",
        function()
          require("smart-splits").swap_buf_down()
        end,
        desc = "Swap buffer down",
      },
      {
        "<leader>wk",
        function()
          require("smart-splits").swap_buf_up()
        end,
        desc = "Swap buffer up",
      },
      {
        "<leader>wl",
        function()
          require("smart-splits").swap_buf_right()
        end,
        desc = "Swap buffer right",
      },
    },
    config = function()
      local submode = require("submode")
      submode.create("WinResize", {
        mode = "n",
        enter = "<leader>wr",
        leave = { "<Esc>", "q", "<C-c>" },
        hook = {
          on_enter = function()
            vim.notify("Resize mode: h/j/k/l or arrows to resize, q/<Esc> to exit")
          end,
          on_leave = function()
            vim.notify("")
          end,
        },
        default = function(register)
          register("h", require("smart-splits").resize_left, { desc = "Resize left" })
          register("j", require("smart-splits").resize_down, { desc = "Resize down" })
          register("k", require("smart-splits").resize_up, { desc = "Resize up" })
          register("l", require("smart-splits").resize_right, { desc = "Resize right" })
          register("<Left>", require("smart-splits").resize_left, { desc = "Resize left" })
          register("<Down>", require("smart-splits").resize_down, { desc = "Resize down" })
          register("<Up>", require("smart-splits").resize_up, { desc = "Resize up" })
          register("<Right>", require("smart-splits").resize_right, { desc = "Resize right" })
        end,
      })
    end,
  },
}
