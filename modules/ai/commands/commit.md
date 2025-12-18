---
description: git commit
model: anthropic/claude-sonnet-4-5
subtask: true
---

Create a commit for the changes.

First, check git status and review what's staged. If there's prior discussion context:
- Stage any relevant unstaged files from the discussion
- Verify already-staged files are relevant to the discussion
- Unstage anything unrelated

If no prior discussion, commit whatever is staged.

Use conventional commits format:
- `feat:` or `feat(<scope>):` - new feature
- `fix:` or `fix(<scope>):` - bug fix
- `docs:` - documentation
- `chore:` - maintenance tasks
- `refactor:` - code restructuring
- `test:` - adding/updating tests
- `ci:` - CI/CD changes
- `style:` - formatting, no code change
- `perf:` - performance improvement

Explain WHY from an end user perspective, not WHAT was changed.

Be specific. Avoid generic messages like "improved experience" or "updated code".
