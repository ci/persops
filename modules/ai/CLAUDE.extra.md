## Model routing (workflows & subagents) — Claude Code only

Source: `~/p/persops/modules/ai/CLAUDE.extra.md`; loads only into `~/.claude/CLAUDE.md`, never Codex/Pi/OpenCode.

Rankings, higher = better. Cost = what I actually pay, not list price. Intelligence = how hard a problem it handles unsupervised. Taste = UI/UX, code quality, API design, copy.

| model           | cost | intelligence | taste |
| --------------- | ---- | ------------ | ----- |
| gpt-5.5 (codex) | 9    | 8            | 5     |
| haiku-4.5       | 9    | 3            | 4     |
| sonnet-5        | 5    | 5            | 7     |
| opus-4.8        | 4    | 7            | 8     |
| fable-5         | 2    | 9            | 9     |

How to apply:

- Defaults, not limits. Standing permission to escalate: cheap output below bar => redo with smarter model, no asking. Judge output, not price tag.
- Anything that ships: intelligence > taste > cost. Cost is tie-breaker only.
- Bulk/mechanical (clear-spec impl, migrations, data analysis): gpt-5.5 — effectively free.
- Token-hungry work (computer use, whole-codebase sweeps, long docs): delegate to other models; report results back to the main loop.
- User-facing (UI, copy, API design): taste >= 7.
- Plan/impl reviews: fable-5 or opus-4.8; gpt-5.5 via `codex review` as extra independent perspective (matches $autoreview default).
- Haiku: high-fan-out trivial lookups only; never for anything that ships.
- Mechanics: gpt-5.5 only via Codex CLI (`codex exec` / `codex review`; `~/.codex/config.toml` defaults gpt-5.5 xhigh). Investigations: `codex exec -s read-only` with a self-contained prompt, or the codex plugin (codex:rescue skill / codex-rescue agent).
- Claude models via Agent/Workflow `model` param ('haiku'|'sonnet'|'opus'|'fable').
- gpt-5.5 inside workflows/subagents (model param takes Claude models only): use agentType 'codex:codex-rescue', or a thin `model: 'sonnet', effort: 'low'` wrapper agent that writes a self-contained codex prompt, runs `codex exec` via Bash, and returns raw stdout.
