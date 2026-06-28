---
name: plan-file
description: Use BEFORE writing implementation code in /implement, after repo-setup and once a ticket exists. Produces an approval-blocked plan at .claude/plans/<branch>.md (story ref, change summary, affected files, approach, test cases, open questions) and blocks coding until it exists and the user has approved it. Skip only for trivial changes, with an auditable one-line reason.
---

# Plan File

The plan gate in `/implement`'s repo path: runs after `repo-setup`, before any implementation code. Produces a written, **approval-blocked** plan for the branch — coding doesn't start until the plan file exists and the user has approved it. Ported from the work `implementation-plan` skill, genericized.

## When to invoke

Before writing any implementation code, once both are true:
1. A branch + worktree are set up (via `repo-setup`).
2. A story/ticket is the agreed scope for the session.

If implementation is requested and no plan file exists for the current branch, run this first.

## When to skip

Skip only for:
- Single-line fixes, typos, renames, trivial string edits.
- Emergency hotfixes where speed outweighs discipline.
- Spikes or throwaway experiments explicitly flagged as such.

If skipping, **state the reason in one sentence** before proceeding, so the skip is auditable in the session log (and note it in the eventual commit message).

## Plan file location

`.claude/plans/<branch>.md` in the worktree root. **Flatten `/` in the branch name to `-`** so the plan is a single file, not a nested path: `feat/new-thing` → `.claude/plans/feat-new-thing.md`. This `/`→`-` rule is canonical here; `repo-setup`'s plan-file prune and `cleanup-artifacts`' deletion must use the same flattening.

The plan is working scaffolding, not shipped documentation, so `.claude/plans/` **must be gitignored** — don't assume it. Ensure `.claude/plans/` is in the repo's `.gitignore` (add it if missing) before writing the plan. `repo-setup` seeds this alongside `.worktrees/`, but `plan-file` guarantees it too so the property holds even when invoked standalone.

**Deleting the plan is `cleanup-artifacts`' job** (#35) at the draft→ready boundary, not this primitive's. Until `cleanup-artifacts` ships, the gitignore guarantee above is what keeps a plan from leaking into a PR.

## Plan structure

```markdown
# <story-id>: <short-title>

## Story reference
<link to the ticket, plus 2–3 sentences of context — enough that the plan stands alone without opening the ticket>

## Change summary
1–2 sentences: what is changing and why.

## Affected files
- `path/to/file.ext` — new | modified | deleted — one-line note on the change
- `path/to/test.ext` — new | modified — test-side change

## Approach
Bullet list keyed to the files above. Describe the shape of each change, not full pseudocode. Example:

- `src/foo/usage.ts` — add a `usage` accessor that reads from the cache with a short TTL; expose it so the caller can use it directly instead of hitting the cache.
- `src/foo/caller.ts` — replace the direct cache call with the new accessor.

## Test cases
- Happy path: ...
- Edge: ...
- Regression to guard: ...
- Known gotchas from past incidents in this area: ...

## Open questions
Anything the story did not fully answer. Resolve with the user before coding, or mark as explicit assumptions to validate during review.
```

## Process

1. Read the story/ticket to ground the plan in the stated scope.
2. If a plan file already exists for this branch, read it and offer to revise rather than overwrite.
3. Scan the affected files briefly to ground the approach in real code (do not start modifying them).
4. Draft the plan using the structure above.
5. Ensure `.claude/plans/` is gitignored (add it if missing), then write the plan to `.claude/plans/<branch>.md` (flattened name).
6. Show the plan to the user and wait for explicit approval.
7. Iterate on feedback — update the plan file in place.
8. Only after approval does the recipe proceed to implementation — referencing the plan file on subsequent turns as the source of truth.

Approval signals: "looks good", "proceed", "yes", "go ahead", or a direct instruction like "start implementing X."

## Enforcement

Write no implementation code — no file creation, no edits to source or test files beyond the plan file itself — until:
1. The plan file exists at `.claude/plans/<branch>.md`, and
2. The user has approved it.

If the user explicitly says "skip the plan" / "just do it", comply, but record the skip reason in the resulting commit message so the decision is traceable.

## Context recovery

If the conversation context is cleared mid-implementation, the **first action** in the new session is to read the plan file to re-ground. When dispatching a subagent to execute part of the plan, **always pass the plan file path in the subagent's initial prompt** so it reads the plan before acting.

## Living-document caveat

On a greenfield story, the affected-files list and approach often can't be fully specified until implementation begins — that's expected. The plan is a living document for the branch: when the file list or approach changes during implementation, update the plan file before continuing. Its value comes from being current, not from being complete on first draft.

## Output / contract

- **In:** a story/ticket reference + the branch (from `repo-setup`).
- **Out:** an approved plan at `.claude/plans/<flattened-branch>.md`; the path is passed forward to execution and to any dispatched subagent.
- **Side effects:** writes the plan file; **gates** implementation until the plan exists and is approved.

## Project overrides

- **Plan-artifact location** — a repo that tracks plans elsewhere (e.g. `docs/plans/`) overrides the location; keep the flatten rule consistent with `repo-setup` and `cleanup-artifacts`.
- **Size-skip threshold** — a repo may tune what counts as "trivial."

## Future scope

- Size-skip auto-detection (heuristic on diff size / file count) rather than agent judgment.
