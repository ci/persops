# nvim config

## Oxide repos

- Rust: rust-analyzer runs clippy on save with default features only. Set
  features for a repo in a `rust-analyzer.toml` at its root.
- Hubris: launch from the checkout root with the task to analyze, e.g.
  `HUBRIS_TASK=app/cosmo/rev-a.toml:control_plane_agent nvim`, so
  rust-analyzer runs through `cargo xtask rust-analyzer`.
- illumos-gate: buffers get hard tabs (8), no format-on-save, and cstyle
  (`-cpP`, as in `git pbchk`) diagnostics. clangd gets fallback flags: one
  client for `usr/src/uts` (`_KERNEL`), one for userland. Build the cscope
  database with `<leader>Cb` from the checkout root; `<leader>C` holds the
  other cscope queries.
