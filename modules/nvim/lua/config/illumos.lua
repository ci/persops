-- Helpers for illumos-gate checkouts, which can't be built (so have no
-- compile_commands.json) off illumos. Used by plugins/illumos.lua.
local M = {}

---Root of the illumos-gate checkout containing `path`, if any.
---@param path string
---@return string?
function M.root(path)
  if path == "" then
    return nil
  end
  for dir in vim.fs.parents(path) do
    if vim.uv.fs_stat(dir .. "/usr/src/tools/scripts/cstyle.pl") then
      return dir
    end
  end
end

---clangd root for `path`: the kernel (usr/src/uts) and userland get separate
---clients so each can have its own fallback flags.
---@param path string
---@return string?
function M.clangd_root(path)
  local root = M.root(path)
  if not root then
    return nil
  end
  local uts = root .. "/usr/src/uts"
  return vim.startswith(path, uts .. "/") and uts or root
end

---Fallback compile flags if `dir` is a root from `clangd_root`. Generated
---headers (e.g. sys/priv_names.h) stay missing; clangd recovers past them.
---@param dir string
---@return string[]?
function M.clangd_flags(dir)
  if M.clangd_root(dir .. "/_") ~= dir then
    return nil
  end
  local flags = { "--target=x86_64-pc-solaris2.11", "-std=gnu99", "-nostdlibinc" }
  if vim.endswith(dir, "/usr/src/uts") then
    -- Oxide's platform is uts/oxide; upstream gate only has i86pc.
    local platform = vim.uv.fs_stat(dir .. "/oxide") and "oxide" or "i86pc"
    vim.list_extend(flags, {
      "-D_KERNEL",
      "-I" .. dir .. "/" .. platform,
      "-I" .. dir .. "/intel",
      "-I" .. dir .. "/common",
    })
  else
    local src = dir .. "/usr/src"
    vim.list_extend(flags, { "-I" .. src .. "/head", "-I" .. src .. "/uts/common", "-I" .. src .. "/uts/intel" })
    for _, lib in ipairs(vim.fn.glob(src .. "/lib/*/common", false, true)) do
      table.insert(flags, "-I" .. lib)
    end
  end
  return flags
end

---Match the gate's style (cstyle): hard tabs, 8 wide, 80 columns. Formatting
---on save would rewrite files in LLVM style, so turn it off.
function M.setup()
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("persops_illumos", { clear = true }),
    callback = function(ev)
      if not M.root(vim.api.nvim_buf_get_name(ev.buf)) then
        return
      end
      vim.b[ev.buf].autoformat = false
      local bo = vim.bo[ev.buf]
      bo.expandtab = false
      bo.tabstop = 8
      bo.shiftwidth = 8
      bo.softtabstop = 0
      bo.textwidth = 80
      -- Continuation lines are indented 4 spaces past the statement.
      bo.cinoptions = "(4,u4,+4"
    end,
  })
end

return M
