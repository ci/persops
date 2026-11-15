# persops

The public slice of my personal ops monorepo: agent skills and instructions,
a Claude Code plugin marketplace, and a few dotfile modules (Neovim, fish,
iamb). The rest of the repo, the machine and home configuration, is private.

This repo is generated. Each push to the private repo's `main` publishes the
paths in [`.public-paths`](.public-paths) here with
[`scripts/publish-public`](scripts/publish-public), which refuses to publish if
the copy contains private details. Pull requests here can't be merged; the
next publish would overwrite them.

## Claude Code plugins

```sh
/plugin marketplace add ci/persops-public
/plugin install persops@persops
```

The marketplace has `persops` (general skills such as autoreview, propose,
pr-closeout), `persops-web` (TypeScript, React, TUI), `persops-jj` (Jujutsu)
and `persops-catppuccin` (a Catppuccin theme for the Claude apps). Skills live
in [`modules/ai/skills`](modules/ai/skills).

## Dotfiles

The Nix modules here are home-manager modules taken out of a larger flake, so
they don't build on their own. Read them for ideas rather than importing them.
