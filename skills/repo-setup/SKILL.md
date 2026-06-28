---
name: repo-setup
description: Use at the start of /implement's repo path to land in a clean working state — fetch, fast-forward main, prune merged branches/worktrees/plan-files, then create the feature branch + worktree off fresh main. Repo-only; project-overridable for deep provisioning.
---

# Repo Setup

First step of `/implement`'s repo path. Takes the repo from whatever state it's in to a fresh feature branch + worktree cut off an up-to-date `main`, clearing the debris of previously-merged work on the way. Assumes a git repo — the recipe's repo-vs-vault context branch runs before this.

## Input

- **branch** — the feature branch to create, as `<type>/<desc>` (`feat/`, `fix/`, `chore/`, `story/S-<id>-<desc>`). The recipe derives it from the ticket. A bare description is acceptable — default the type to `feat/`.
- (implicit) the current repo and its `origin` remote.

## Steps

1. **Guard a dirty tree.** If `git status --porcelain` is non-empty, stop and surface the changes — don't fetch/prune over dirty state. (A project override may stash-and-restore instead.)
2. **Fetch.** `git fetch --prune origin` — updates remote-tracking refs and drops refs for branches deleted on the remote.
3. **Fast-forward `main`.** Bring local `main` to `origin/main`, never a merge commit:
   - on `main` → `git merge --ff-only origin/main`
   - not on `main` → `git fetch origin main:main` (fast-forward-only update of the local ref; refuses if it would diverge).
4. **Prune merged work.** Enumerate merged branches with `git branch --merged origin/main`, add the squash-merged ones (see caveat), and for each — excluding `main` and the current branch:
   - Remove its worktree if present: `git worktree remove .worktrees/<branch>` (`--force` only if an override opts in).
   - Delete its plan file: `rm -f .claude/plans/<branch>.md` using the `/`→`-` flattened branch name (`feat/foo` → `.claude/plans/feat-foo.md`, matching `plan-file`); gitignored, per-branch, safe.
   - Delete the branch: `git branch -d <branch>` for merge-commit / fast-forward merges; `git branch -D <branch>` for squash-merged branches (`-d` refuses them — `-D` is safe because the caveat's check already confirmed the content landed).

   Then `git worktree prune` to clear stale administrative entries.

   **Squash-merge caveat.** `git branch --merged origin/main` catches merge-commit and fast-forward merges but **not squash-merges** — and `/implement` squashes by default, so a just-merged branch won't show as merged (and `git branch -d` would refuse to delete it). Detect those separately, in order of reliability:
   - `gh pr list --state merged --head <branch>` reports it merged — robust, but needs network + auth.
   - `git diff origin/main..<branch>` (two-dot — compares the tip *trees*) is empty when the branch's change already landed and `main` hasn't moved since. Network-free fallback; a `main` that has advanced since the squash defeats it.

   Delete the matches with `git branch -D`. Without `gh` auth and with an advanced `main`, a squash-merged branch may survive the prune — acceptable; the next clean run catches it.
5. **Create the feature branch + worktree off fresh main.** `git worktree add .worktrees/<branch> -b <branch> origin/main` — one step: branch cut from up-to-date `main`, checked out in an isolated worktree.
6. **Ensure ignores.** From the main checkout, make sure `.worktrees/` and `.claude/plans/` are in the repo's `.gitignore` — append each if missing, no-op if present — so the `.worktrees/` dir never shows as untracked here:
   ```
   [ -s .gitignore ] && [ -n "$(tail -c1 .gitignore)" ] && printf '\n' >> .gitignore
   for p in '.worktrees/' '.claude/plans/'; do grep -qxF "$p" .gitignore 2>/dev/null || printf '%s\n' "$p" >> .gitignore; done
   ```
   The leading guard appends a newline first if the file doesn't end in one, so an entry isn't glued onto the last line. Idempotent — a one-time addition per repo, committed via a normal branch/PR. (`.claude/plans/` is also ensured independently by `plan-file` in the worktree where plans are actually written — step 6 covers the root checkout; `plan-file` is the real plan-leak backstop.)

## Output / contract

- **In:** repo state + a branch name.
- **Out:** the created branch name and its worktree path (`.worktrees/<branch>`), surfaced so `plan-file` and the later primitives operate inside the worktree.
- **Side effects:** local `main` fast-forwarded; previously-merged branches + their worktrees + their plan files removed; new branch + worktree created; `.worktrees/` and `.claude/plans/` ensured in `.gitignore`. No pushes or other network *writes*; the optional squash-merge `gh pr list` check is a network *read* and needs auth.

## Project overrides

This primitive stops at "branch + worktree exist." Deep, stack-specific provisioning is project-override territory, layered *after* the generic steps:

- **Port / secret / compose setup** — e.g. domainator's `setup-feature.sh` (slot-based ports, `.env` secret-gen, `compose up`).
- **Worktree policy** — a repo that doesn't want worktrees overrides step 5 with a plain `git switch -c <branch> origin/main`.
- **Dirty-tree handling** — stash-and-restore instead of stop.
- **Containerized verification seam** — when tests run via `podman/docker compose`, a bare worktree breaks two ways: the gitignored `.env` (and other secrets) won't exist in `.worktrees/<branch>`, so compose's `env_file` fails — symlink or copy them in; and compose must be run **from inside the worktree dir**, because bind-mounts are relative and running from the repo root silently exercises `main`, not your branch. Override `repo-setup` (and see `/implement`'s execute step) to set this up.

Overrides must honor the contract (same name, same "fresh branch + worktree off updated main" outcome) so the rest of `/implement` keeps working. (Step 6 already ensures `.worktrees/` and `.claude/plans/` are gitignored.)

## Future scope

- Vault / non-repo path (deferred out of v1 — `/implement` is repo-shaped for now).
- Branch-name derivation from the ticket (currently the recipe's job, passed in).
