return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      vtsls = {
        settings = {
          typescript = {
            tsserver = {
              -- default heap was the perf pain that originally drove
              -- the move to typescript-tools
              maxTsServerMemory = 6144,
            },
          },
        },
      },
    },
  },
}
