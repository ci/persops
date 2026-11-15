return {
  "ibhagwan/fzf-lua",
  opts = {
    grep = { rg_glob = true },
    oldfiles = {
      include_current_session = true,
    },
    previewers = {
      builtin = {
        syntax_limit_b = 1024 * 100, -- 100KB
      },
    },
  },
}
