return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      vtsls = {
        settings = {
          typescript = {
            tsserver = {
              maxTsServerMemory = 6144,
              pluginPaths = {
                "./node_modules",
                "./chat/node_modules", -- monorepo problems
              },
            },
          },
        },
      },
    },
  },
}
