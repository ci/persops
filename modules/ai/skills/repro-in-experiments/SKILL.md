---
name: repro-in-experiments
description: "Build a scratch repro app under ~/p/experiments against the local PostHog instance. Use when asked to repro a customer issue, SDK bug, ticket, or GitHub issue in a fresh app."
---

# Repro in Experiments

Reproduce a reported issue (customer ticket, GitHub issue, SDK bug) in a
minimal, real-looking app under `~/p/experiments`, pointed at the local
PostHog instance. The goal is a clean confirmed-or-falsified verdict with
exact versions, not a polished project.

## Workspace

- One folder per repro: `~/p/experiments/<short-slug>` describing the case
  (e.g. `vite-css-empty-map-onboarding`, `next-turbopack-chunkids`).
- New variant or stack = new folder; don't mutate a previous repro in place.
- Throwaway by design — no git setup needed unless the toolchain requires it.

## Versions

- If the user, ticket, or issue names specific versions, pin exactly those
  (framework, bundler, PostHog SDK, plugins). State the pins in your report.
- Otherwise use the latest published versions of everything.
- Record the resolved versions either way (`npm ls`/lockfile) — a repro
  verdict without exact versions is incomplete.

## PostHog target

- Point SDKs at the local instance: `http://localhost:8010`.
- API/project tokens and host live in `~/p/local-dev-creds`. Make sure
  `hogli` is running before relying on them.
- Testing an unreleased fix: link/pack the local SDK build from the sibling
  repo in `~/p/` (e.g. `../posthog-js`) instead of the published package, and
  say so in the report.

## Workflow

1. Restate the failure you're trying to reproduce in one line (expected vs
   observed). Pull config from the ticket/issue verbatim when provided
   (vite.config, next.config, gradle files, etc.).
2. Scaffold the minimal app that matches the reporter's stack. Real-looking
   beats minimal-toy when the bug may depend on build pipeline behavior.
3. Build/run and exercise the failing path.
4. Verify end-to-end, not just locally: confirm events/sourcemaps/chunk IDs
   actually arrive in the local PostHog instance before declaring success or
   failure. A repro that never ingests proves nothing.
5. Report: reproduced or not, exact versions, the smallest config delta that
   flips the behavior (if found), and the repro folder path.

If runtime/deployment fidelity is in doubt (worker mode, SSR vs client,
platform-specific), consult `$repro-fidelity` before trusting the verdict.
