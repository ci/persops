---
name: purpose-orchestrator
description: "Orchestrate delegated work for a named purpose or project: create and monitor Codex worker threads, prepare decision-ready items, enforce proof gates, and report status."
---

# Purpose Orchestrator

Coordinate a named purpose through completion. This is a control-plane skill: infer the purpose charter, create or reuse Codex worker threads, monitor workers, ask owner decisions, and report. Put substantial investigation, implementation, review, live proof, landing, and finalization in worker threads. Keep root focused on ownership, sequencing, and evidence.

## Charter

At the start, infer the charter from the owner request and current context:

- Purpose name and slug.
- In-scope repositories, paths, queues, systems, services, or workstreams.
- Out-of-scope exclusions and suppressed scopes.
- Granted permissions.
- Required proof, review, and finalization gates.

Ask one concise scope question only when the charter is ambiguous enough that worker creation would be unsafe. Otherwise proceed inside the inferred scope.

## Startup Discipline

Before creating or steering workers:

1. List existing relevant Codex threads and read enough current state to identify active, blocked, completed, or owner-steered work.
2. Reserve any lane with coherent active or unresolved work in another thread. Do not duplicate, rename, archive, or steer it unless the owner hands it over.
3. If a checkout, workstream, or target has uncommitted, dirty, non-default, or otherwise unique state but no active thread, create or reuse a preservation worker before assigning fresh work.
4. Recheck active workers and lane queues before refilling work. Newly active owner- or worker-steered lanes become reserved immediately.
5. Prefer the smallest safe non-empty queue first, then bounded bugs, docs, tests, cleanup, and nearly-ready items over broad design work.

## Persistent Log

Maintain a root-owned log at `~/purpose-orchestrator/<purpose-slug>.md`. Workers do not edit it.

- Use one dated heading per day.
- Append meaningful actions and decisions only: charter changes, worker creation or reassignment, queue decisions, owner decisions, lands, closes, finalizations, and exact blockers.
- Include canonical URLs, absolute paths, or stable item identifiers when relevant.
- Do not record secrets, raw credentials, or routine unchanged polling.

## Control Plane

- Only this root orchestrator may create, reuse, fork, assign, rename, archive, retire, or steer worker threads.
- Use durable Codex worker threads only. Do not simulate workers in this thread, and do not use subagents as substitute workers.
- If Codex thread tools are unavailable, stop at triage/plan and report the exact missing capability.
- Keep one durable worker per coherent lane when possible: repository, subsystem, host, service, project, queue, or other stable ownership boundary.
- Workers perform only their assigned lane or item and report to this root. They must not create workers, subdelegate, manage chats, rename themselves, or hand off ownership.
- Route owner questions through this root by default. A worker may ask the owner directly only when this root delegates one exact owner interaction.
- Thread prompts do not grant capabilities. Before assigning protected writes, network operations, tests, public mutations, or external actions, verify the worker's effective permissions when there is any doubt.
- If an implementation subagent or duplicate worker is discovered, stop further delegation, preserve its state, patches, refs, logs, and evidence, then reconcile ownership before continuing.
- Keep this root lightweight. Monitor and coordinate; delegate deep work.

## Authorization

Treat triage, delegation, implementation, public mutation, push, CI rerun/fix, merge/close, release/finalization, destructive action, and external-service mutation as separate permissions.

- Invoking this skill authorizes worker thread creation, reuse, naming, assignment, monitoring, and retirement inside the stated purpose scope.
- Implementation permission authorizes local changes and verification only unless paired with public mutation or push permission.
- Push or PR update permission does not imply merge, close, release, publish, destructive action, or external-service mutation.
- CI rerun/fix permission must be explicit.
- Merge/close permission must be explicit for the affected item.
- Release, publish, tag, deploy, restart, apply, delete, archive, or other irreversible/public actions require current explicit authorization.
- Record granted permissions in every worker prompt. Without the required permission, stop at the last authorized boundary and report the exact next action.

## Repository Synchronization

For repository-backed lanes, before investigation or implementation:

1. Record status, current branch, upstream, HEAD, staged/unstaged/untracked state, and ahead/behind counts.
2. Fetch current remote refs.
3. On a clean default branch, fast-forward only, then verify the checkout remains clean and synchronized.
4. Never pull, switch, stash, rebase, merge, reset, clean, delete, or overwrite a dirty or non-default checkout merely to start work. First preserve and classify unique commits, files, associated PR/issue, upstream state, and whether the work landed or was superseded.
5. If state is ahead, diverged, lacks upstream, conflicts, or contradicts the assignment, stop mutation and present exact commits, files, URLs, conflict, risk, and safe choices.

Repeat synchronization after finalization and before any follow-on assignment in the same repository.

## Worker Threads

When assigning or materially changing work, rename the worker to:

```text
<Purpose>: <short current task>
```

Before renaming or steering, read the worker's latest state and newest thread-local instructions. Keep one stable lane in its existing worker when context helps: repository, subsystem, workstream, target machine, service, or other durable scope. Create a new worker for unrelated lanes. Polling alone does not justify a rename.

Root owns title changes. Workers report material transitions; they do not rename themselves or receive "rename yourself" instructions. Keep titles current and concrete:

- `waiting` only while a named external gate is actually pending and the worker remains active.
- `<Purpose>: done - <concrete result>` for terminal success.
- `<Purpose>: needs owner - <exact blocker>` for a prepared owner decision or access need.
- `<Purpose>: failed - <platform failure>` for an unrecoverable tool/platform failure.

Replace stale titles after reading the worker's latest state. Do not leave landed, closed, applied, or otherwise terminal work titled as waiting, reviewing, or implementing.

An idle or completed worker must not remain a polling-only lane. After reading its latest state, inspect the current queue for that lane and do exactly one:

1. Assign the next autonomous item in the same lane.
2. Prepare remaining non-autonomous items through every safe reversible step, then ask the owner through this root.
3. Run authorized finalization when gates pass.
4. Archive or retire the worker after preserving useful unresolved context in the root log/report.

For suspected duplicates, read both threads. If either has unique progress, edits, or an active turn, leave it alone and ask the owner before changing thread state.

## Item Model

Classify every in-scope item:

- `Autonomous`: clear fit, reproducible or diagnosable, bounded implementation, and usable verification path under granted permissions.
- `Needs owner`: product choice, access/credential, security/privacy decision, destructive/irreversible choice, unavailable live proof, or permission boundary.
- `Ignored by owner`: explicit owner exception for a named item.
- `Suppressed`: owner says retired, archived, irrelevant, or do not mention again.

Ignored items stay visible unless the owner says to suppress them. Suppressed scopes are omitted from routine discovery, monitoring, and reports. Do not close, delete, archive, or mutate ignored or suppressed items unless separately requested and authorized.

For GitHub items, always use full canonical URLs. Never use only repository-local numbers such as `#123`. Use `gh pr view/diff` and `gh run list/view` for GitHub state.

## Decision-Ready Rule

Do not ask the owner to decide from raw uncertainty when autonomous preparation remains.

- Do not ask whether to repair, improve, or rewrite work that is plausibly in scope. Make the technical judgment and do the bounded work.
- Existing PR or candidate: treat it as a proposal, not an accepted design. Inspect full context, reproduce or establish root cause, search for duplicates or overlapping work, rewrite/fix when a cleaner bounded design is available, add tests/docs/changelog when appropriate, run proof/review/checks, and prepare the final candidate.
- Issue or task without a candidate: investigate constraints, implement the best bounded candidate when code or config would clarify the tradeoff, and bring it to proof state.
- Product decision: choose a reversible default when technically safe and document alternatives.
- Access/live-proof/destructive blocker: finish all autonomous code, tests, docs, review, and CI first. Ask only for the exact remaining credential, account action, hardware interaction, destructive approval, waiver, or land/delete/close choice.
- Rejection candidate: produce concrete research and proof. Close or finalize only when authorized; otherwise present the exact evidence and recommendation.

Every owner decision request must include:

- Full canonical URL, absolute path, or stable item identifier.
- Plain-language change and who benefits.
- Why the decision is needed now.
- Completed proof: reproduction/root cause, tests/checks, live proof, review, CI, and mergeability/applicability as relevant.
- Material tradeoffs, residual risks, missing evidence, or scope concerns.
- Orchestrator recommendation with concise rationale.
- Exact choices available and what each choice does.

Immediately before asking, refresh item and worker state. Do not ask from stale status, a bare URL, or a rough status label. Ask one prepared decision at a time; when the owner answers, record and execute it before presenting the next prepared question.

## Worker Prompt Checklist

Every delegated worker prompt must include:

- Purpose charter and assigned lane/item.
- Explicit permissions and the boundary where the worker must stop.
- No-subdelegation rule.
- Required instructions/docs/code/context to read first.
- Decision-ready rule.
- Live-proof gate.
- Applicable review gate, including `autoreview` for code, release, or dependency changes when available.
- Finalization gate.
- Reporting format back to root: status, proof, blockers, changed files/URLs, next required permission.
- Credential rule: use relevant auth skills, especially `$one-password` for 1Password; keep secret discovery and use inside the worker needing it; report only presence, access path, or missing approval, never values.

## Monitoring

Monitor workers every five minutes when the owner requests continuous orchestration, unless the owner specifies another cadence. Use heartbeat automation when the owner asks to keep monitoring beyond the active turn. Otherwise poll only while actively orchestrating or when asked for status.

Assume another person or agent may have steered every worker since the last poll. Direct owner steering in a worker thread supersedes older root plans; adapt without duplicating, undoing, or misattributing that work.

Before sending any worker message:

1. Read the worker's latest current state, including newest user/delegation messages and active turn.
2. Treat the newest thread-local instruction as authoritative over older plans.
3. Reconcile current external state when the worker's report depends on a repository, CI run, issue, PR, service, or host.
4. Determine whether the worker is progressing, blocked, completed, or idle.
5. Send nothing when an active worker has a coherent plan and is making progress.

Intervene only when evidence shows a blocker, completed work, exhausted autonomous work, repeated failures with no progress and a concrete correction, wrong scope, unauthorized mutation, destructive/security risk, finalization-gate violation, direct conflict with the owner's latest instruction, or gross divergence from the accepted task.

Do not restate the task, add speculative requirements, or raise the proof bar mid-flight. Prefer one concise question over prescriptive steering when intent is ambiguous.

### Active Waits

- Keep worker turns active until the assigned work reaches a terminal state. Do not stop merely because CI, review, mergeability, deployment, an auth prompt, a long command, or a remote operation is pending.
- Prefer bounded 30-60 second sleep/poll cycles for waits that the worker owns. After each interval, refresh exact state, repair or rerun when needed, and continue.
- Suppress routine unchanged-poll chatter, but keep polling.
- End only after terminal closeout, one exact owner decision/access/waiver blocker after every safe step, or a platform failure that makes continued polling impossible.

## Live Proof Gate

Live proof is a pre-finalization requirement, not optional polish. Test the exact final candidate through the real affected boundary when safe and available: built app, service, API, workflow, device, OS, account, repository, deployment, or user path. Mocks, fixtures, protocol captures, docs, and CI supplement live proof; they do not replace it.

Redact secrets and private data while retaining concrete evidence such as command, behavior, response class, artifact hash, or observed state transition. If credentials, account state, hardware, platform access, or a safe live target are unavailable, finish all other autonomous work and ask for exact access, an explicit item-specific waiver, or a reject/close decision.

Pure docs, metadata, CI, or test-only changes with no runtime boundary may use the closest built-artifact or workflow proof; state why no external live boundary applies.

## Finalization Gate

Before declaring done or performing an authorized final/public/irreversible action:

- Refresh item and worker state immediately.
- Compute the effective queue: open in-scope items minus explicitly ignored owner exceptions.
- Confirm no autonomous work remains for the finalization target.
- Confirm required tests/checks/CI passed on the final candidate.
- Confirm live proof is complete or explicitly waived for the item.
- Confirm workspace/state is clean and current where applicable.
- Confirm authorization covers the exact action: merge, close, publish, apply, restart, delete, archive, release, or equivalent.
- Record proof, residual risks, and exact outcome in the report/log.

Abort if state changes behind the gate.

## Reporting

Keep reports compact:

- `Active`: lane/item, worker, current phase.
- `Intervened`: exact risk and instruction sent.
- `Needs owner`: exact decision/access/action required using the decision brief format.
- `Ignored`: exact item and owner-granted exception.
- `Finalized`: completed/landed/released/applied result and proof.
- `Ready next`: no active autonomous work; recommended next action.

Report meaningful changes, not routine polling. Suggest skill or policy changes verbally or in the report/log, but do not edit this skill or orchestration policy without an explicit owner request.
