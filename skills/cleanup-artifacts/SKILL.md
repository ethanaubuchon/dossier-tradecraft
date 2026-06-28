---
name: cleanup-artifacts
description: Use in /implement at the draft→ready boundary, before publish-pr's squash, to delete this branch's transient plan/spec artifacts so they don't ship in the PR. Deletes .claude/plans/<branch>.md (flattened name). Distinct from repo-setup's prune of previously-merged branches' artifacts.
---

# Cleanup Artifacts

Deletes **this** branch's transient working artifacts — the plan file and any spec scratch — at the draft→ready boundary, so they don't ship in the PR. One of `/implement`'s two distinct cleanups:

- `repo-setup` prunes *previously-merged* branches' worktrees + plan files (at setup).
- `cleanup-artifacts` deletes *this* branch's plan file (at finalize).

Runs **before** `publish-pr`'s squash.

## Input

- **branch** — the current feature branch.

## Steps

1. Delete this branch's plan file: `rm -f .claude/plans/<branch>.md`, using the `/`→`-` flattened branch name (`feat/foo` → `.claude/plans/feat-foo.md`, matching `plan-file`).
2. Delete any other transient spec/scratch artifacts the project marks for this branch.

## Output / contract

- **In:** the branch.
- **Out:** working tree with this branch's plan/spec artifacts removed.
- **Side effects:** deletes the plan file. With the default **gitignored** plan location the deletion isn't part of the diff (pure housekeeping); if a project **tracks** plan files, the deletion is a real change — which is why it must run *before* `publish-pr`'s squash, so it folds into the single commit (no plan file in PR history). `publish-pr` stages this deletion with `git add -A` before committing — without that staging the `reset --soft` index would re-commit the tracked plan file.

## Project overrides

- **Plan-artifact location** — a repo that stores plans/specs elsewhere (e.g. `docs/plans/`) overrides the path; keep the flatten rule consistent with `plan-file` and `repo-setup`.

## Future scope

- (none beyond per-project artifact locations.)
