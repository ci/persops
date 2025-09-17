return {
  "ibhagwan/fzf-lua",
  opts = function(_, _)
    local fzf = require("fzf-lua")
    local actions = fzf.actions

    return {
      grep = { rg_glob = true },
      oldfiles = {
        include_current_session = true,
      },
      previewers = {
        builtin = {
          syntax_limit_b = 1024 * 100, -- 100KB
        },
      },
      actions = {
        files = {
          ["alt-i"] = { actions.toggle_ignore },
          ["alt-e"] = { actions.toggle_hidden },
        },
      },
    }
  end,
}
