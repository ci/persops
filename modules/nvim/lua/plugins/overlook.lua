return {
  {
    "WilliamHsieh/overlook.nvim",
    opts = {},
    keys = {
      {
        "<leader>cpd",
        function()
          require("overlook.api").peek_definition()
        end,
        desc = "Overlook: Peek definition",
      },
      {
        "<leader>cpc",
        function()
          require("overlook.api").close_all()
        end,
        desc = "Overlook: Close all popup",
      },
      {
        "<leader>cpu",
        function()
          require("overlook.api").restore_popup()
        end,
        desc = "Overlook: Restore popup",
      },
    },
  },
}
