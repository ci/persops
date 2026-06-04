---
name: repro-fidelity
description: "Reproduce reported bugs with the relevant runtime, version, deployment shape, and state model before accepting the diagnosis or root cause."
---

# Repro Fidelity

Use when a user asks whether a bug report is real, asks to reproduce a failure,
or mentions a runtime/deployment-specific issue such as a particular language
version, worker mode, platform, package manager, browser, SDK, or service model.

If the user asks for investigation only, combine this with `$thoughts`: verify
locally, report, and stop.

## Contract

- Reproduce before accepting the report's diagnosis.
- Match the reported environment when feasible: runtime version, package
  version, OS/platform, deployment mode, long-lived process model, flags, and
  relevant data/state shape.
- Separate "the symptom is real" from "the proposed root cause is real".
- Prefer small, explicit repro harnesses over broad app runs.
- Do not treat sandbox, dependency, or local-service failures as product bugs
  until rerun with the right permission/runtime model.

## Workflow

1. Pin the report:
   - exact symptom, expected/actual result, affected version, runtime,
     deployment shape, input/data pattern, and proposed root cause
   - current branch/base and whether `main` or a previous commit should be
     compared
2. Build the smallest repro:
   - use the repo package manager and local docs
   - use the requested runtime/version; try nix-comma or `nix shell` when the
     tool is missing
   - keep scratch harnesses in `/tmp` or a throwaway worktree when needed
3. Increase fidelity only as needed:
   - CLI/unit repro
   - target runtime/version
   - deployment mode such as worker/server/browser/device
   - long-lived process/state accumulation
   - before/after or A/B against the proposed fix
4. Prove or falsify root cause:
   - collect direct measurements such as logs, counters, memory, stored payloads,
     traces, generated files, or persisted state
   - if a suggested patch does not change the symptom, say the diagnosis was
     falsified even if the bug is real
5. Close out:
   - state what reproduced, what did not, exact commands, environment, and
     remaining fidelity gaps
   - if implementing, add the smallest meaningful regression test once the
     failing path is known

## Output

Lead with the verdict:

- Reproduced / not reproduced / partially reproduced.
- Root cause: confirmed / falsified / still unknown.
- Fidelity: what matched the report and what still differs.
- Proof: key commands and observed output, not a transcript.
- Next action: fix shape, test to add, or evidence needed.
