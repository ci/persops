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
keymap("n", "<C-d>", "<C-d>zz")
keymap("n", "<C-u>", "<C-u>zz")
