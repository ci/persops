return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      vtsls = {
        settings = {
          typescript = {
            inlayHints = {
              enumMemberValues = { enabled = false },
              functionLikeReturnTypes = { enabled = false },
              parameterNames = { enabled = "literals" },
              parameterTypes = { enabled = false },
              propertyDeclarationTypes = { enabled = false },
              variableTypes = { enabled = false },
            },
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
