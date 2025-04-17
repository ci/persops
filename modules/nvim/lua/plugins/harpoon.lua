return {
  "ThePrimeagen/harpoon",
  event = "VeryLazy",
  dependencies = {
    { "nvim-lua/plenary.nvim" },
  },
  config = function()
    vim.keymap.set("n", "<s-m>", function()
      require("harpoon.mark").add_file()
      vim.notify("marked file")
    end, { noremap = true, silent = true })
    vim.keymap.set("n", "<TAB>", function()
      require("harpoon.ui").toggle_quick_menu()
    end, { noremap = true, silent = true })
  end,
}
