return {
  "williamboman/mason.nvim",
  opts = {
    ensure_installed = {
      "debugpy", -- Python
      "js-debug-adapter", -- JavaScript/TypeScript
      "delve", -- Go
      "codelldb", -- C/C++/Rust
      "stylua",
      "black",
      "gomodifytags",
      "impl",
      "goimports",
      "gofumpt",
    },
  },
}
