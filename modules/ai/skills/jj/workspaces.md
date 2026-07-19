# Workspaces for Isolation and Parallel Agents

Workspaces provide isolated working copies that share the full revision graph. Each workspace has its own `@` (working-copy commit) and lives outside every other workspace's tracked tree, usually in a sibling directory or `/tmp`. This is jj's equivalent of `git worktree`.

**Target version: jj 0.36+**

For the complete parallel agent setup guide, see:
- [references/parallel-agents.md](references/parallel-agents.md) — Detailed workflow, decision checklist, troubleshooting, agent instruction templates

**Authority:** jj official docs (working-copy.md, glossary.md).

## When to Use Workspaces

**Use when:**
- A task must not disturb the primary checkout or its unrelated changes
- A branch/PR review, repro, or closeout needs a disposable checkout
- A slow build or test should run while other work continues
- 3+ truly independent tasks can run simultaneously
- Tasks touch different files
- Time savings justify setup/cleanup overhead

**Don't use when:**
- A small task is safe in the current clean workspace
- Parallel tasks are sequential or dependent
- Tasks modify the same files
- Parallel tasks are small/fast enough to do sequentially

**Authority:** jj official docs; parallel-task heuristics are detailed in `parallel-agents.md`.

## Core Commands

| Command | Purpose |
|---------|---------|
| `jj workspace add <path> --name <name> -r <rev> -m <message>` | Create workspace on an explicit revision |
| `jj workspace forget <name>` | Unregister workspace (commits preserved) |
| `jj workspace list` | Show all workspaces and their `@` |
| `jj workspace update-stale` | Refresh files after external modification |
| `jj workspace root --name <name>` | Print workspace root path |

## Single Isolated Workspace

Place it outside the current workspace tree and select the intended parent explicitly:

```bash
jj workspace add /tmp/ws-review-auth --name review-auth -r 'auth@origin' -m 'chore: isolate auth review'
```

Without `-r`, the new working-copy commit shares the current `@`'s parents; it is a sibling of `@`, not its child. Always pass `-r` for branch/PR isolation. Inside the new workspace, `@` is an empty child of the selected revision; inspect the selected revision when reviewing pushed code.

## Parallel Setup Workflow

### 1. Create Workspaces

Workspaces must be outside another workspace's tracked tree. Sibling directories are convenient for durable workspaces; `/tmp` is useful for disposable ones:

```bash
jj workspace add ../ws-auth --name auth
jj workspace add ../ws-api --name api
jj workspace add ../ws-docs --name docs
```

These unqualified adds intentionally start beside the current `@`; step 3 moves each workspace onto an explicit task change. For a workspace that should start directly on a known revision, pass `-r` during `workspace add`.

### 2. Create Task Commits

```bash
jj new trunk() --no-edit -m "feat: add auth middleware"
jj new trunk() --no-edit -m "feat: add API endpoints"
jj new trunk() --no-edit -m "docs: update API reference"
```

### 3. Assign Agents

Give each agent:
- **Absolute path** to its workspace (agents lose track of relative cwd)
- **Change ID** of its task commit

The agent must run `jj edit <change-id>` before doing any work.

### 4. Monitor Progress

```bash
# See all workspace working copies
jj log -r 'working_copies()'

# Check a specific workspace
jj log -r 'auth@'
```

### 5. Integrate Results

```bash
# Merge all task commits
jj new <auth-id> <api-id> <docs-id> -m "merge: integrate parallel work"

# Check for conflicts
jj st
```

### 6. Clean Up

```bash
jj workspace list
jj workspace root --name auth
jj workspace root --name api
jj workspace root --name docs
jj workspace forget auth
jj workspace forget api
jj workspace forget docs
```

Before forgetting, inspect each workspace's `@`, diff, name, and exact root. `forget` only unregisters the workspace: commits and files are preserved. Afterward, abandon only a captured change ID that you verified is a disposable empty working-copy commit; never abandon integrated work. Remove only the exact resolved workspace directories, and prefer a recoverable deletion method when available.

## Agent Instruction Template

When tasking an agent with workspace work, provide:

```
Work in workspace: /absolute/path/to/ws-auth
Your change ID: <change-id>

Before starting:
  cd /absolute/path/to/ws-auth
  jj edit <change-id>

Rules:
  - Always use -m for messages (no editors)
  - Run jj st after every mutation
  - Do not modify files outside your assigned scope
```

**Always use absolute paths.** Agents navigate directories during work; relative paths break.

## Stale Working Copies

An independent operation in another workspace does not make every workspace
stale. Staleness occurs when another operation rewrites or updates the commit
recorded as this workspace's working copy.

**Fix:** `jj workspace update-stale`

Run it explicitly, then re-inspect before moving shared bookmarks:

```bash
jj workspace update-stale
jj status
jj log -r '@ | @- | bookmarks()'
```

Do not hide it in `jj workspace update-stale 2>/dev/null || true`; that masks
real errors and permits later commands to use an unverified graph. If an
operation was lost (`jj op abandon`), `update-stale` creates a recovery commit
preserving the workspace's disk state. `snapshot.auto-update-stale = true` is
available, but explicit fail-closed recovery is safer for agent sessions.

**Authority:** jj official docs (working-copy.md — stale working copy section).

## Conflict Mitigation

| Source | Prevention |
|--------|------------|
| Build outputs | Cover in `.gitignore` |
| Shared config files | Assign one agent to own them |
| Lock files | Only one task adds deps, or resolve at integration |
| Same source files | Redesign task boundaries |

Conflicts at integration are normal jj conflicts — edit markers, verify with `jj st`.

## Revset Expressions for Workspaces

| Expression | Meaning |
|------------|---------|
| `working_copies()` | All workspace `@`s |
| `auth@` | Specific workspace's `@` |
| `@` | Current workspace's `@` |

## Common Mistakes

- **Creating a workspace inside another workspace** — child paths get tracked by jj. Use a sibling directory or `/tmp`.
- **Omitting `-r` for isolated branch work** — the new `@` becomes a sibling of the current `@`, not a child of the target branch. Pass the intended revision explicitly.
- **Using relative paths in agent instructions** — agents navigate; paths break. Always use absolute paths.
- **Forgetting to `jj edit <change-id>`** before starting work — the agent works on the wrong commit.
- **Treating every concurrent operation as stale** — only graph changes that affect this workspace's recorded commit stale it.
- **Ignoring a real stale message** — run `jj workspace update-stale`, then re-check status and bookmarks.
- **Thinking `forget` deletes work** — it only unregisters the workspace. Commits remain in the repo.
- **Assuming `forget` cleans everything** — it leaves both files and commits. Resolve and verify each exact target before separate commit or directory cleanup.
