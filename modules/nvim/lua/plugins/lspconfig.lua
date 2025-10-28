return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      vtsls = {
        experimental = {
          maxInlayHintLength = 30,
          completion = {
            enableServerSideFuzzyMatch = true,
            entriesLimit = 200,
          },
        },
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
