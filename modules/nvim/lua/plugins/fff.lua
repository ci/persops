local function picker_cwd(root)
  if root == false then
    return vim.uv.cwd()
  end
  return LazyVim.root({ normalize = true })
end

local function find_files(root)
  return function()
    require("fff").find_files({ cwd = picker_cwd(root) })
  end
end

local function find_config_files()
  return function()
    require("fff").find_files({ cwd = vim.fn.stdpath("config") })
  end
end

local function live_grep(root, query)
  return function()
    require("fff").live_grep({ cwd = picker_cwd(root), query = query })
  end
end

local function grep_word(root)
  return function()
    live_grep(root, vim.fn.expand("<cword>"))()
  end
end

local function grep_visual(root)
  return function()
    local save_reg = vim.fn.getreg("v")
    local save_type = vim.fn.getregtype("v")
    vim.cmd([[normal! "vy]])
    local query = vim.fn.getreg("v")
    vim.fn.setreg("v", save_reg, save_type)
    live_grep(root, query)()
  end
end

return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  lazy = false,
  opts = {
    lazy_sync = true,
    debug = {
      enabled = false,
    },
  },
  keys = {
    { "<leader><space>", find_files(true), desc = "Find Files (Root Dir)" },
    { "<leader>ff", find_files(true), desc = "Find Files (Root Dir)" },
    { "<leader>fF", find_files(false), desc = "Find Files (cwd)" },
    { "<leader>fc", find_config_files(), desc = "Find Config File" },
    { "<leader>fg", find_files(true), desc = "Find Files (git-aware)" },
    { "<leader>/", live_grep(true), desc = "Grep (Root Dir)" },
    { "<leader>sg", live_grep(true), desc = "Grep (Root Dir)" },
    { "<leader>sG", live_grep(false), desc = "Grep (cwd)" },
    { "<leader>sw", grep_word(true), desc = "Word (Root Dir)" },
    { "<leader>sW", grep_word(false), desc = "Word (cwd)" },
    { "<leader>sw", grep_visual(true), mode = "x", desc = "Selection (Root Dir)" },
    { "<leader>sW", grep_visual(false), mode = "x", desc = "Selection (cwd)" },
  },
}
