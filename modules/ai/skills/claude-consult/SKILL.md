---
name: claude-consult
description: "Consult Claude Fable for an owner-requested second opinion."
---

# Claude Consult

Codex sessions only. Claude and other harnesses: skip; never self-delegate.

Use only when the owner explicitly asks Codex to ask or consult Claude. Keep Claude in a consultant or reviewer role; Codex retains ownership, verifies the answer, and performs any authorized actions itself.

## Prepare

Write a scoped prompt file containing the question, necessary context or excerpts, constraints, non-goals, requested output shape, and an explicit instruction not to delegate or invoke Codex or other agents. Do not pass secrets without current owner authorization.

Choose the working directory intentionally. Claude receives unrestricted filesystem and command access, so the directory is context rather than a security boundary.

## Invoke

Set `PROMPT_FILE` to the prompt file and `CLAUDE_MAX_BUDGET_USD` to a bounded numeric cap appropriate for the owner-requested consultation, then run:

```bash
command claude --print \
  --no-session-persistence \
  --model claude-fable-5 \
  --effort high \
  --dangerously-skip-permissions \
  --max-budget-usd "$CLAUDE_MAX_BUDGET_USD" \
  --output-format json <"$PROMPT_FILE"
```

- Keep `claude-fable-5` explicit; do not substitute an alias or fallback model.
- Keep `--effort high`, `--print`, no persistence, and prompt-file input.
- `--dangerously-skip-permissions` is the installed CLI's full permission-bypass mode. It grants Claude unrestricted filesystem and command access without approval prompts. Use it only for an explicit owner-requested Claude consultation.
- Permission bypass is capability, not authorization. Keep the prompt advisory-only and forbid mutations unless the owner separately and explicitly requested them.
- Treat one explicit owner request as authorization for one metered call. Report cap or model failures and ask before retrying unless the owner already authorized iteration.

## Verify

Require a successful result record and inspect the complete JSON evidence:

- Confirm `claude-fable-5` from the model fields the installed CLI emits, such as init and assistant events or `modelUsage`. State the proof limitation if independent model evidence is absent.
- Report `total_cost_usd` and any permission denials when present.
- Treat `--effort high` as invocation evidence only when the output does not expose an effort field; do not claim stronger metadata proof.
- Verify Claude's factual claims against the supplied source, local state, or tests. Its answer is advisory.

Claude can technically delegate, modify files, run commands, access credentials, send messages through available integrations, or mutate external systems in this mode. The prompt must forbid those actions unless separately authorized, and Codex must inspect resulting local and external state rather than trusting the response.
