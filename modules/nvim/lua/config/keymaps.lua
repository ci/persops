-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- keymap("n", "<Space>", "", opts)
-- vim.g.mapleader = " "
-- vim.g.maplocalleader = ","

keymap("n", "<C-i>", "<C-i>", opts)
keymap("n", "n", "nzz", opts)
keymap("n", "N", "Nzz", opts)
keymap("n", "*", "*zz", opts)
keymap("n", "#", "#zz", opts)
keymap("n", "g*", "g*zz", opts)
keymap("n", "g#", "g#zz", opts)
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)
keymap("x", "p", [["_dP]])

keymap({ "n", "x" }, "j", "gj", opts)
keymap({ "n", "x" }, "k", "gk", opts)

keymap("n", "<BS>", "<cmd>b#<CR>")

keymap("n", "J", "mzJ`z")
-- keymap("n", "<C-d>", "<C-d>zz")
-- keymap("n", "<C-u>", "<C-u>zz")

keymap("n", "<leader>fyy", '<cmd>let @+ = expand("%:p")<CR>', { desc = "copy path (full)" })
keymap("n", "<leader>fyp", '<cmd>let @+ = expand("%:p")<CR>', { desc = "copy path (full)" })
keymap("n", "<leader>fyP", '<cmd>let @+ = expand("%")<CR>', { desc = "copy relative path (relative)" })
keymap("n", "<leader>fyd", '<cmd>let @+ = expand("%:p:h")<CR>', { desc = "copy directory (full)" })
keymap("n", "<leader>fyD", '<cmd>let @+ = expand("%:h")<CR>', { desc = "copy directory (relative)" })
keymap("n", "<leader>fyn", '<cmd>let @+ = expand("%:t")<CR>', { desc = "copy filename" })
keymap("n", "<leader>fyN", '<cmd>let @+ = expand("%:t:r")<CR>', { desc = "copy filename without extension" })
