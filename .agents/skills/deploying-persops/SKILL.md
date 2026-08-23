---
name: deploying-persops
description: "Deploys persops configurations to aglaea and amalthea. Use when asked to build, apply, switch, or deploy persops locally or through an Amp runner."
---

# Deploying Persops

Use `make deploy` as the deployment entry point. It snapshots the current flake,
checks the selected machine configurations, deploys Amalthea first, then switches
Aglaea locally when selected.

## Current Capability Matrix

| Controller | aglaea target | amalthea target |
| --- | --- | --- |
| aglaea | local switch | remote deploy-rs switch |
| amalthea | unavailable | local switch |
| orb | delegate to a runner | delegate to a runner |

Aglaea has no remote SSH deployment yet. Never bypass the controller guard or
try to activate Aglaea from Amalthea.

## Before Applying

1. Run `git status --short --branch` and identify the exact source state.
2. Confirm the requested targets. A switch changes live machines and requires
   explicit authorization; a request to inspect, build, or check does not imply it.
3. Preserve unrelated working-copy changes. The deploy command intentionally
   snapshots tracked and non-ignored untracked files from the current checkout.

## Commands

```sh
make deploy                                  # controller defaults
make deploy TARGETS=amalthea
make deploy TARGETS=aglaea                   # aglaea only
make deploy TARGETS="aglaea amalthea"        # aglaea only
```

Controller defaults:

- Aglaea deploys Amalthea first, then Aglaea.
- Amalthea deploys only itself.
- Every other host fails and directs the operator to an Amp runner.

The command runs repository checks and evaluates only the selected targets against
one immutable Nix store snapshot before activation. A remote Amalthea deployment
checks its deploy-rs profile; a local Amalthea deployment checks its NixOS config.
Amalthea is verified with `scripts/remote-verify`; Aglaea runs `ops-status` after
its local switch. Use `make check` separately to evaluate every machine config.

## Delegating From an Orb

List live runners immediately before delegation. If Aglaea is among the targets,
the Aglaea runner is the only valid controller. For Amalthea-only deployments,
ask which valid runner to use when the user has not selected one.

Runner and orb workspaces are separate. Deploy only an exact source state that
the runner can access:

- Prefer a committed Git revision already available to the runner.
- Do not push merely to transfer it without explicit push authorization.
- For unpushed work, transfer a patch or bundle and apply it in an isolated
  runner checkout; never overwrite the runner's shared checkout.

Tell the runner thread the targets, exact revision or patch, and that live
activation is authorized. Do not ask it to push. Account for a local switch
restarting the runner: finish remote work first and place the controller's local
switch last.

## Failure Handling

- Stop on failed checks, preflight, activation, or verification.
- Deploy-rs provides rollback for remote Amalthea activation, but the two-machine
  operation is not atomic.
- Do not retry a failed switch unchanged. Inspect the exact failure and current
  target state first.
