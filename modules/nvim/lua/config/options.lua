-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.lazyvim_prettier_needs_config = true
vim.g.tmux_navigator_disable_when_zoomed = 1

vim.g.ai_cmp = false -- use inline suggestions instead of cmp

-- When editing over SSH, use OSC52 so remote yanks land in the local clipboard.
-- Requires a terminal that supports OSC52; tmux passthrough is enabled in tmux.conf.
if vim.env.SSH_TTY then
  vim.g.clipboard = "osc52"
  vim.opt.clipboard = "unnamedplus"
end
