return {
  {
    "supermaven-inc/supermaven-nvim",
    -- Cloud completion stays off work hosts; `cond` keeps it in the shared lockfile.
    cond = vim.g.persops_profile == "personal",
    event = "VimEnter",
    opts = function()
      -- Get theme-aware color from Comment highlight group
      local comment_hl = vim.api.nvim_get_hl(0, { name = "Comment" })
      local suggestion_color = comment_hl.fg and string.format("#%06x", comment_hl.fg) or "#45475a"

      return {
        color = {
          suggestion_color = suggestion_color,
          cterm = 244,
        },
      }
    end,
  },
}
