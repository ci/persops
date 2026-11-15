---
name: effect-ts
description: "Set up Effect or work with Effect APIs using the project's installed version, package guidance, and source."
---

# Effect

## Existing projects

Check the project's package manifest, lockfile, and existing Effect patterns first. Preserve its Effect version and package manager unless the task authorizes a dependency change; do not migrate an existing project to a prerelease just because this skill mentions one.

Before writing Effect code, read `node_modules/effect/AGENTS.md` when present. Resolve the package from the relevant workspace if the monorepo uses a different installation layout. Follow its links as needed and search the installed package's source for API details the guide does not cover.

If that release does not include agent guidance or source, use official documentation or upstream source matching the installed version. An existing local Effect checkout is useful only when its version matches; creating or vendoring one is not a prerequisite.

## Requested setup

When the user asks to install Effect, choose the release line appropriate to the project and task. Upstream's current v4 setup uses `effect@rc`; confirm the current package dist-tags before a new installation. Keep related packages compatible with the selected release.

Use the project's package manager. For example, when v4 RC setup is intended:

```sh
pnpm add effect@rc
```

In a monorepo, add dependencies to the workspace that uses them. A root development dependency is optional when the project needs shared source access; do not add it solely to satisfy this skill.

## Requested instruction updates

When repository instruction updates are part of the task, add a short pointer to the installed package's guidance and source. Use the repository's existing agent-instruction file; do not create a parallel `CLAUDE.md` when it uses `AGENTS.md`.

For a package version that ships these paths, the pointer can say:

> Before writing Effect code, read `node_modules/effect/AGENTS.md` and follow its links as needed. For API details not covered there, inspect `node_modules/effect/src`.

Adapt the paths to the actual workspace layout. A request to fix Effect code alone does not authorize dependency installation or instruction-file changes.
