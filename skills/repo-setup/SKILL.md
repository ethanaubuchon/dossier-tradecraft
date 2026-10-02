---
name: repo-setup
description: Use at the start of /implement's repo path to land in a clean working state — fetch, fast-forward main, prune merged branches/worktrees/plan-files, then create the feature branch + worktree off fresh main and switch the session into it. Repo-only; project-overridable for deep provisioning.
---

# Repo Setup

First step of `/implement`'s repo path. Takes the repo from whatever state it's in to a fresh feature branch + worktree cut off an up-to-date `main` — with the session standing in that worktree — clearing the debris of previously-merged work on the way. Assumes a git repo — the recipe's repo-vs-vault context branch runs before this.

## Input

- **branch** — the feature branch to create, as `<type>/<desc>` (`feat/`, `fix/`, `chore/`, `story/S-<id>-<desc>`). The recipe derives it from the ticket. A bare description is acceptable — default the type to `feat/`.
- (implicit) the current repo and its `origin` remote.

## Steps

0. **Start from the main checkout.** Steps 1–5 resolve relative paths and "current branch" against the main checkout, so get there first — a session may still be standing in a previous run's worktree (a second `/implement` in the same session), have been launched inside one, or sit in a subdirectory.
   - **Resolve the root:** `git worktree list --porcelain | sed -n '1s/^worktree //p'` — the first entry is the main checkout, call it `<root>`. If that entry is followed by a `bare` line, the repo is a bare-repo layout with no main working tree: stop — that layout needs a project override.
   - **Record where you started:** the starting worktree (`git rev-parse --show-toplevel`) and its branch (`git branch --show-current`), before moving. Step 4 must not prune them — they may be a worktree the user owns and the session was launched in.
   - **Move:** if `pwd -P` isn't `<root>`, first try `ExitWorktree(action: "keep")` (load via `ToolSearch` `select:ExitWorktree` if deferred; never `remove` — that's a prior branch's work). Don't rely on remembering whether you entered one — after `/clear` or compaction you may not; the tool reports when no worktree session is active. Then, if `pwd -P` still isn't `<root>`, `cd <root>` — and re-check `pwd -P`: the harness may reset a `cd` that leaves the launch directory, so if it didn't take, stop and surface it. No-op on a normal first run. Steps 4–5 anchor their file paths to `<root>` anyway, so they hold even if cwd drifts.
   - **Ensure local ignores:** make sure `.worktrees/` and `.claude/plans/` are in the repo-local exclude file — append each if missing, no-op if present — so the `.worktrees/` dir never shows as untracked in the main checkout. Two plain commands — resolve the common git dir with a bare `git rev-parse --git-common-dir` (if the output is relative — typically `.git` — prefix it with `<root>/`; if absolute, use it as-is), then run the append with that absolute path substituted as a literal:
     ```
     c='<absolute common dir>'; x="$c/info/exclude"
     if [ -d "$c" ]; then mkdir -p "$c/info"
       [ -s "$x" ] && [ -n "$(tail -c1 "$x")" ] && printf '\n' >> "$x"
       for p in '.worktrees/' '.claude/plans/'; do grep -qxF "$p" "$x" 2>/dev/null || printf '%s\n' "$p" >> "$x"; done
     else echo "no git common dir at $c" >&2; false; fi
     ```
     The exclude file lives in the common git dir, so it applies to the main checkout and every linked worktree, and it isn't tracked — so ignoring never dirties the tree. That's why this runs *before* the step 1 guard: it clears an untracked `.worktrees/` instead of tripping on it — and before step 6, because a worktree-isolated session refuses writes into `<root>/.git`. If the harness refuses the append anyway (e.g. an isolation guard still active after `/clear`), stop and give the user the literal command to run themselves (`! <command>`). The append runs no `git` and embeds no `$(git …)`, so command-shape hooks can verify it; it fails loudly (without exiting a persistent shell) if the path isn't a directory; the newline guard keeps an entry from being glued onto a last line with no trailing newline. This snippet is canonical — `plan-file` reuses it for `.claude/plans/` alone. **repo-setup never edits the tracked `.gitignore`** — a project that wants these entries there adds them through a normal PR. A project that *tracks* plan files under `.claude/plans/` must override this step (and `plan-file`) to skip that entry, or new plans are silently ignored. (`plan-file` re-checks `.claude/plans/` independently, so it holds when invoked standalone.)
1. **Guard a dirty tree.** If `git status --porcelain` is non-empty, stop and surface the changes — don't fetch/prune over dirty state. (A project override may stash-and-restore instead.) A `.gitignore` whose only change is adding `.worktrees/` / `.claude/plans/` is left over from an older repo-setup that wrote there; surface it like any other change — reverting a modified one (or deleting an untracked one holding only those lines) is safe, step 0's exclude entries now cover it.
2. **Fetch.** `git fetch --prune origin` — updates remote-tracking refs and drops refs for branches deleted on the remote.
3. **Fast-forward `main`.** Bring local `main` to `origin/main`, never a merge commit:
   - on `main` → `git merge --ff-only origin/main`
   - not on `main` → `git fetch origin main:main` (fast-forward-only update of the local ref; refuses if it would diverge).
4. **Prune merged work.** Enumerate merged branches with `git branch --merged origin/main`, add the squash-merged ones (see caveat), then drop `main`, the current branch, the starting branch/worktree recorded in step 0, and the in-use candidates below.

   **In-use exclusions.** Another session's freshly cut branch has no commits yet, so its tip is at or behind `origin/main` — indistinguishable from a fast-forward merge (and, at `origin/main`'s tip, its two-dot diff is empty too). Removing its worktree also deletes the plan file `plan-file` wrote inside it, since ignored files don't block `git worktree remove`. Skip the whole candidate — worktree, plan file, and branch, whichever list (merged or squash-merged) it came from — when either holds:
   - **Its worktree is locked** — a `locked` line under its entry in `git worktree list --porcelain`. Step 5 locks every worktree it creates; `/implement` unlocks it at a normal exit and keeps it through a kickback or pause. List each skipped locked worktree in the output with its path — it may be a live or paused session, or a stale lock left by a crashed one; flag one as "merged but locked — unlock to prune" only when the tip-matched `gh` check below confirmed its PR merged (`--merged` alone also lists every fresh in-flight branch). The fix for a stale one is `git worktree unlock <path>` once the user confirms that session is gone. Never unlock automatically.
   - **Its tip equals `origin/main`** (`git rev-parse <branch>` = `git rev-parse origin/main`) — it has no commits of its own, so there is nothing to have merged. A real fast-forward merge caught by this survives until `origin/main` advances past it.

   For each remaining candidate:
   - Remove its worktree if present: `git worktree remove <root>/.worktrees/<branch>` (`--force` only if an override opts in).
   - Delete its plan file: `rm -f <root>/.claude/plans/<branch>.md` using the `/`→`-` flattened branch name (`feat/foo` → `.claude/plans/feat-foo.md`, matching `plan-file`); gitignored, per-branch, safe.
   - Delete the branch: `git branch -d <branch>` for merge-commit / fast-forward merges; `git branch -D <branch>` for squash-merged branches (`-d` refuses them — `-D` is safe because the caveat's check already confirmed the content landed).

   Then `git worktree prune` to clear stale administrative entries.

   **Squash-merge caveat.** `git branch --merged origin/main` catches merge-commit and fast-forward merges but **not squash-merges** — and `/implement` squashes by default, so a just-merged branch won't show as merged (and `git branch -d` would refuse to delete it). Detect those separately, in order of reliability:
   - `gh pr list --state merged --head <branch> --json headRefOid` reports a merged PR whose `headRefOid` equals the local branch tip — robust, but needs network + auth. The tip match matters: a reused branch name also matches an old merged PR.
   - `git diff origin/main..<branch>` (two-dot — compares the tip *trees*) is empty when the branch's change already landed and `main` hasn't moved since. Network-free fallback; a `main` that has advanced since the squash defeats it.

   Delete the matches (subject to the in-use exclusions above) with `git branch -D`. Without `gh` auth and with an advanced `main`, a squash-merged branch may survive the prune — acceptable; the next clean run catches it. One whose PR gained commits the local branch lacks (pushed from elsewhere or via the GitHub UI) fails the tip match and survives every run — it fails safe; once confirmed merged, remove it manually: `git worktree remove <path>` (unlock first if locked), then `git branch -D <branch>`.
5. **Create the feature branch + worktree off fresh main.** `git worktree add --lock --reason "/implement in progress" <root>/.worktrees/<branch> -b <branch> origin/main` — one step: branch cut from up-to-date `main`, checked out in an isolated worktree, locked so a concurrent session's step 4 skips it. `/implement` releases the lock at its normal exit (step 10).
6. **Enter the worktree.** Switch the session's working directory into it, using the absolute path `<root>/.worktrees/<branch>`:
   - **Claude Code** → `EnterWorktree(path: "<root>/.worktrees/<branch>")` — the `path` form accepts a worktree made by `git worktree add`. Invoking `/implement` / `repo-setup` *is* the explicit instruction to work in a worktree that the tool's usage rule asks for; don't skip it on those grounds. If the tool is deferred, load it first (`ToolSearch` `select:EnterWorktree`).
   - **Harness without an equivalent tool** → one persistent `cd <root>/.worktrees/<branch>`.
   - **Main session only.** Run this step in the main session, not a subagent — a subagent's cwd is pinned, so the switch is rejected or affects only that agent. Subagents dispatched later get the worktree's absolute path in their prompt.

   **Verify the switch:** `realpath "$(git rev-parse --show-toplevel)"` must equal `realpath "<root>/.worktrees/<branch>"` (canonicalize both — a symlinked path would otherwise mismatch) and `git branch --show-current` must print `<branch>`. If either doesn't match (or the tool call was rejected), **stop and surface it to the user** — don't fall back to prefixing commands.

   From here on every command runs bare: **never prefix commands with `cd .worktrees/<branch> &&` or `git -C …`** — prefixed commands are harder to read and break hooks that match on the command's prefix or cwd.

   **Re-entering later.** To resume an existing branch's worktree (e.g. addressing human review comments after `/implement` exited), don't re-run this skill — repo-setup only creates new branches. Re-enter with the same enter-and-verify as this step: `EnterWorktree(path: "<root>/.worktrees/<branch>")` (or `cd`), then the verify. Leave the worktree lock as found — a paused session's lock stays, and a worktree unlocked at a normal exit isn't re-locked (its commits already protect it).

## Output / contract

- **In:** repo state + a branch name.
- **Out:** the created branch name and its absolute worktree path (`<root>/.worktrees/<branch>`), with the session's working directory switched into it so `plan-file` and the later primitives operate inside the worktree.
- **Side effects:** local `main` fast-forwarded; previously-merged branches + their worktrees + their plan files removed (locked worktrees skipped and listed); new branch + locked worktree created; `.worktrees/` and `.claude/plans/` ensured in the repo-local `info/exclude` (no tracked file is modified); session cwd moved out of any prior worktree (step 0) and into the new one (step 6). No pushes or other network *writes*; the optional squash-merge `gh pr list` check is a network *read* and needs auth.

## Project overrides

This primitive stops at "branch + worktree exist, session inside it." Deep, stack-specific provisioning is project-override territory, layered *after* the generic steps:

- **Port / secret / compose setup** — e.g. domainator's `setup-feature.sh` (slot-based ports, `.env` secret-gen, `compose up`).
- **Worktree policy** — a repo that doesn't want worktrees overrides step 5 with a plain `git switch -c <branch> origin/main` (and drops step 6).
- **Dirty-tree handling** — stash-and-restore instead of stop.
- **Containerized verification seam** — when tests run via `podman/docker compose`, a bare worktree breaks two ways: the gitignored `.env` (and other secrets) won't exist in `.worktrees/<branch>`, so compose's `env_file` fails — symlink or copy them in; and compose must be run **from inside the worktree dir** (step 6 puts the session there), because bind-mounts are relative and running from the repo root silently exercises `main`, not your branch. Override `repo-setup` (and see `/implement`'s execute step) to set this up.

Overrides must honor the contract (same name, same "fresh branch + worktree off updated main, session cwd inside it" outcome) so the rest of `/implement` keeps working. An override that creates the worktree itself must create it locked (`--lock`, or `git worktree lock` right after) — step 4's concurrency protection and `/implement`'s exit unlock depend on it. (Step 0 already ensures `.worktrees/` and `.claude/plans/` are ignored.)

## Future scope

- Vault / non-repo path (deferred out of v1 — `/implement` is repo-shaped for now).
- Branch-name derivation from the ticket (currently the recipe's job, passed in).
