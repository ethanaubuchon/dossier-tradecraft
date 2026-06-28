---
name: publish-pr
description: Use in /implement at the draft→ready boundary to squash the branch's review-iteration commits into one (non-interactive soft-reset + recommit + force-with-lease) and mark the draft PR ready. Takes the commit message as input (sourced from the plan-file before cleanup). GitHub-specific (gh) behind a host-neutral contract.
---

# Publish PR

The finalize step of `/implement`'s repo path: collapse the review-iteration commit noise into one clean commit, then mark the draft PR ready for humans. Runs **after** `cleanup-artifacts` (so a tracked plan-file deletion folds into the squashed commit).

The squash is a **non-interactive** local rewrite — `git rebase -i` isn't available in this harness, and isn't needed.

## Input

- **branch** — the current feature branch (committed; reviewed in its draft PR).
- **commit message** — the final squashed-commit message. The recipe sources it from the `plan-file` (story ref + change summary) **before** `cleanup-artifacts` deletes that file.
- **PR ref** — the draft PR to mark ready (from `open-draft-pr`).

## Steps

1. **Squash** the branch to one commit:
   ```
   git reset --soft "$(git merge-base origin/main HEAD)"
   git add -A
   git commit -m "<commit message>"
   ```
   Soft-reset to the branch point keeps the branch's work staged; `git add -A` then folds in working-tree changes the index doesn't yet reflect — notably `cleanup-artifacts`' plan-file *deletion*, so a **tracked** plan file isn't re-committed into the squash (the `reset --soft` index still holds it otherwise). No-op for the gitignored default. One commit then collapses the WIP + review-feedback commits. The goal is eliminating review-iteration noise, **not** single-commit dogma — squash-to-one is just the simplest mechanism that guarantees no feedback-churn commits survive. If the branch has no changes vs the merge-base, there's nothing to finalize — treat it as a no-op rather than letting `git commit` error on an empty index. (`git add -A` assumes the finalize tree is clean apart from `cleanup-artifacts`' deletions; stray untracked scratch/build files would otherwise be swept into the squash.)
2. **Force-push** the rewritten branch with an explicit refspec: `git push --force-with-lease origin <branch>` (explicit so it doesn't depend on a configured upstream; the lease guards against clobbering an unexpected remote update; safe on a solo feature branch).
3. **Mark the PR ready:** `gh pr ready <PR ref>`.

## Output / contract

- **In:** (branch, commit message, PR ref).
- **Out:** a single-commit branch, force-pushed; the PR marked ready for review.
- **Side effects:** rewrites branch history (force-push); changes PR state draft→ready. **No merge** — merging stays a human action.

## Project overrides

- A repo that prefers GitHub's squash-at-merge over a local pre-ready squash overrides steps 1–2; the contract (clean history at draft→ready) still holds.

## Future scope

- **Absorb PR creation (post-v1).** Under the flow simplification, `open-draft-pr` goes away and `publish-pr` *creates* the PR at the end (review having happened on the branch). Don't hard-assume a pre-existing draft beyond the `gh pr ready` step, so that shift stays cheap.
