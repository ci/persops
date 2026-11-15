return {
  "mrcjkb/rustaceanvim",
  opts = function(_, opts)
    local ra = opts.server.default_settings["rust-analyzer"]
    -- LazyVim enables every feature, which pulls in hardware-only code paths
    -- (dendrite's tofino_asic needs the Tofino SDE). Pick features per repo
    -- with a rust-analyzer.toml at its root instead.
    ra.cargo.allFeatures = false
    ra.check = { command = "clippy" }

    -- Hubris needs its xtask shim as the server, configured per (app, task):
    --   HUBRIS_TASK=app/cosmo/rev-a.toml:control_plane_agent nvim
    -- Launch from the hubris checkout root; see its README.
    if vim.env.HUBRIS_TASK then
      opts.server.cmd = { "cargo", "run", "-q", "-pxtask", "--", "rust-analyzer", vim.env.HUBRIS_TASK }
    end
  end,
}
