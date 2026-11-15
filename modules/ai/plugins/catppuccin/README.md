# persops-catppuccin

A Catppuccin look for Claude in the desktop and mobile apps, matching the
Catppuccin Mocha setup used across persops (Ghostty, Neovim, tmux, starship,
fish, yazi, jjui and Pi).

- Dark mode: Catppuccin Mocha surfaces and text, with the page on `base`.
- Light mode: Catppuccin Latte.
- Accent: mauve. Danger is red, success green, warning yellow and the "pro"
  role peach, so code picks up Catppuccin's usual syntax colors where the app
  allows it. Git colors follow Catppuccin too.

It is a function-hooks mod: `hooks/register.ts` calls `$.theme.set` once at
session start. Terminals and editors draw no look, so it only changes the
desktop and mobile apps.

`hooks/make-colors.js` and `hooks/make-colors.d.ts` are copied unchanged from
Claude Code's plugin-authoring skill. Copy them again when Claude Code updates.

## Install

At the prompt of a terminal session:

```
/plugin install persops-catppuccin --marketplace ci/persops-public
```

In the desktop app: + next to the prompt box, then Plugins, Add marketplace
with `ci/persops-public`, then add `persops-catppuccin`. For cloud sessions, add it in
Project settings > Plugins.
