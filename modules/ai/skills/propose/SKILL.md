---
name: propose
description: "Investigate a problem and present options with pros/cons and a recommendation — no implementation. Use for /propose, 'propose some ideas', 'explore solutions with pros/cons', 'what would you do'."
---

# Propose

Options-first exploration. The deliverable is a decision-ready writeup, not
code.

Use when the user asks to investigate and propose ideas/solutions with
pros/cons, explore approaches or design options, asks "what would you do", or
types `/propose <question>`.

## Contract

- No implementation, no branches, no PRs until the user picks. Read-only plus
  local verification while exploring (same spirit as `thoughts`).
- Ground every option in the actual codebase: map the relevant surfaces first;
  fan out explore subagents when the area is broad.
- 2-4 real options; no strawmen. Include the "do less / do nothing" option when
  it's honest.
- UI/UX questions: labeled options (A/B/C) with sketches or mockups when they
  help the pick.
- End with a clear recommendation and why — the "what I would do" answer — not
  a neutral survey.
- After the user picks, flow into normal delivery (implement, gate, autoreview,
  PR per repo and global conventions).

## Output shape

Per option: what it is (2-3 sentences), how it fits the existing code (name
files), pros, cons, effort (S/M/L), risk. Then the recommendation with
reasoning. Keep the whole thing skimmable; no padding.
