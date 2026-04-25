# Ruler

Do not edit repo-specific generated agent instruction files directly (for example a repo root `AGENTS.md`, `CLAUDE.md`, or other Ruler-generated outputs). To change those per-repo instructions, update the nearest `.ruler/*.md` file (or add one), then run `bunx @intellectronica/ruler apply` to regenerate agent files.

This rule is only about generated per-repository instruction files. It does not forbid editing source-of-truth global/shared agent instruction files that this repo intentionally manages, such as `modules/ai/AGENTS.md`.
