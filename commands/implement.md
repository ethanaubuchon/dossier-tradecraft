---
description: Feature implementation in a repo — ticket → plan gate → develop-to-plan → draft-PR review loop (human gate) → squash-clean finalize. Thin recipe over six overridable primitives; dossier-mcp the only hard dependency.
---

You are starting an `/implement` session. The ticket / spec (if provided): $ARGUMENTS

This is the `/implement` recipe of the dossier-tradecraft framework — Phase 4, feature implementation in a repo. It consumes **one ticket** and drives it through: branch → plan → code → review → PR. The recipe is thin: it sequences six overridable primitives and hosts the interactive review loop in the main conversation.

## Principles

- **The spine is the developer's own flow — not superpowers, not TDD.** Develop to the plan; tests are written alongside and verified, **never test-first**. Superpowers / TDD execution are available as project-level execute-step overrides, not the default.
- **Ticket-driven entry.** v1 assumes a ticket exists (issue# / station ID / spec-path / explicit ask). Writing the ticket is `/decompose`'s or an ad-hoc job — out of `/implement`'s scope. The bare no-ticket path is deferred.
- **Thin recipe over overridable primitives.** The recipe sequences and branches; `repo-setup`, `plan-file`, `agent-review`, `open-draft-pr`, `publish-pr`, `cleanup-artifacts` do the work. Each is project-overridable.
- **Review on committed work, in a draft PR, behind a human gate.** Never review unstaged changes. The draft PR exists before review so the PR-framed reviewer agents have a PR to attach to; the human decides when it's ready-for-humans.
- **Squash kills review-iteration noise at draft→ready** — not single-commit dogma.
- **Dependency-free floor; toolkit ceiling via override.** `agent-review` ships a dependency-free reviewer; the `pr-review-toolkit` panel is an opt-in override. Nothing beyond dossier-mcp is required.
- **Repo-shaped.** Vault-path is out of v1 — `/implement` expects a git repo.

## Workflow

1. **Load context.** Invoke the `load-context` skill (vault grounding: profile, inbox check, project pre-warm). Note the cwd, current branch, and whether a project agent-instruction file (CLAUDE.md, AGENTS.md, etc.) is present — its prose carries per-project conventions (test command, sub-agent routing, PR shape). If the working directory is **not** a git repo, stop and say so — `/implement` is repo-shaped in v1.

2. **Resolve the entry ticket.** First read the tracker config, the same way `/decompose` does: prose in the project's agent-instruction file, or the vault profile/project notes loaded in step 1. A config that names "dossier-station" puts the session in **station mode**. Otherwise the issue-number path below uses GitHub. Then, from `$ARGUMENTS`:
   - **issue number** (e.g. `#42` / `42`) → `gh issue view <n>` and treat the issue (title + body + AC) as the spec.
   - **station ID** (station mode; e.g. `STN-142`) → `mcp__dossier-mcp__get_note(slug: "issues/<id>", vault: <station>)` and treat the issue (title + body + AC) as the spec. Name the station vault (from config, or the only station), because a read without it degrades quietly to the other vaults when the station is down. The prefix is set per instance (1–10 uppercase letters), so match `<PREFIX>-<n>` and don't assume `STN`. A bare number or `#N` is ambiguous in station mode, since it could be a GitHub issue: ask, unless the config names the ID prefix. Note the issue's current `status` for step 3 and the abandon path. If the read fails (dossier-mcp down, no station vault, `not_found`), stop and surface it. Never fall back to `gh`.   - **spec path** → read the file and treat it as the spec.
   - **explicit ask** (prose) → treat the prose as the scope for this session.
   - **nothing / no ticket** → the bare no-ticket path is deferred; ask the user to point at an issue or spec (or write a ticket first via `/decompose` or ad hoc). Don't invent scope.

   **Station writes** (steps 3, 7, 9d). If `update_issue` fails at step 3, pause before any code: surface the error and ask whether to continue without the status move or stop. A failed write at step 7 or 9d doesn't undo the PR. Surface the error with the literal `update_issue` call to retry, and carry on. Exit reports the issue's real status, not the intended one.

3. **`repo-setup`.** Invoke the `repo-setup` skill. Derive the branch name from the ticket as `<type>/<desc>` (`feat/`, `fix/`, `chore/`, `story/S-<id>-<desc>`); pass it in. The skill fast-forwards `main`, prunes merged work, and creates the feature branch + worktree, then switches the session's cwd into it and verifies the switch. Run it in the main session. All later steps run bare from there — no `cd <worktree> &&` / `git -C` prefixes.
   - **Station mode:** the branch name may carry the ID (`feat/STN-142-<desc>`). Once the branch exists, move the issue to `in-progress` with `mcp__dossier-mcp__update_issue(id, status: "in-progress")`, but only from `triage` or `backlog`; it's a no-op if the issue is already `in-progress`. From any other status (`blocked`, `in-review`, `done`, `canceled`), or with open `blocked_by` issues, surface the current state and ask before moving it. If the station answers `invalid_request`, surface it rather than working around it.

4. **`plan-file` gate.** Invoke the `plan-file` skill with the ticket reference. It writes an **approval-blocked** plan for the branch (the skill owns the path + naming) and blocks implementation until the plan exists and the user approves it. For genuinely trivial changes, the skill's size-skip applies — state the one-line skip reason so it's auditable. **Write no implementation code before approval.**

5. **Execute (inline).** Develop to the approved plan in the main session. Tests are written alongside and verified — **never test-first; no TDD by default.** Keep the plan current as a living document if the approach shifts.
   - **Verification is repo-defined.** Source the verify/test command — and what "build", "test", "lint" actually *mean* — from the repo's agent-instruction file; don't assume a host-native command or a default verb meaning. In **containerized** repos the in-container typecheck/test is the source of truth: run it from the worktree, where `repo-setup` already put the session (bind-mounts are relative — running from the repo root silently tests `main`), make sure the worktree has the gitignored secrets it needs (see `repo-setup`'s **Containerized verification seam** override), and **distrust host LSP/build diagnostics** (e.g. "cannot find module") — they're noise when deps live in the container.
   - **Sub-agent routing is per-project.** Which steps may be delegated to a subagent vs. must stay in the main session is declared in the repo's agent-instruction file (prose) for soft preferences, or enforced by a primitive override + PreToolUse hook for hard constraints (e.g. a step whose interactive approval needs the main session). Honor both.
   - **Execution override.** A repo that wants superpowers / TDD execution drops a project-level override of this step.

6. **Commit.** Commit the work. Review runs on **committed** work, not unstaged changes.

7. **`open-draft-pr`.** Invoke the `open-draft-pr` skill: push the branch and open a **draft** PR; capture the PR ref. Compose the PR title/body from the plan-file / ticket.
   - **Station mode:** cite the ticket by its station ID (`STN-142`) in the PR body, with plain boundaries: whitespace or parentheses around it, nothing like `STN-142;` or `/STN-142`. That way a forge whose external tracker points at the station links it. Don't use closing keywords; the station doesn't act on them. Then record the PR on the issue. `update_issue`'s `prs` replaces the stored list, so read the issue's current `prs` first (`get_note`, naming the station vault) and send that list plus the new PR URL.

8. **`agent-review` loop (interactive — the human gate lives here).**
   a. Invoke the `agent-review` skill on the committed diff, passing the `plan-file` path + the ticket AC as review context. It returns structured findings.
   b. Present the findings. Address the ones worth fixing (edit + commit fixes on the branch). Re-invoke `agent-review` on the updated diff.
   c. **Loop until the user is satisfied that the PR is ready-for-humans.** This ready-to-publish decision is the human gate — it stays in the recipe, never inside a primitive. Don't self-publish.

9. **Finalize.** In this order (the order matters):
   a. **Source the squash commit message** from the `plan-file` (story ref + change summary) — *before* cleanup deletes the file. If the plan was size-skipped (step 4), source it from the ticket plus the audited skip reason instead. In station mode the story ref is the station ID, with the same plain boundaries as the PR body.
   b. **`cleanup-artifacts`.** Invoke the skill to delete this branch's plan file.
   c. **`publish-pr`.** Invoke the skill with the branch, the sourced commit message, and the PR ref. It squashes (soft-reset + `git add -A` + recommit + `--force-with-lease`) and marks the PR ready.
   d. **Station mode:** once the PR is ready, call `update_issue(id, status: "in-review")`.

10. **Exit.**
   a. Surface: the PR ref (URL), a one-line summary of what shipped, and the status — **PR is ready for human review, not merged.** Merging stays a human action; `/implement` ends at "ready."
      - **Station mode:** report the issue's actual status (`in-review` unless a step 9d write failed). A merge won't move it. The station has no merge webhook in v1, so `done` is a manual step. Give the user the literal call to make once the PR merges: `update_issue(id: "<id>", status: "done")`. If the PR merges while this session is still open, make that call then. `/decompose`'s re-entry also offers it for `in-review` issues whose PRs have merged.
   b. **Release the worktree lock** `repo-setup` took — from inside the worktree, if its entry in `git worktree list --porcelain` has a `locked` line, `git worktree unlock "$(git rev-parse --show-toplevel)"`. The branch has commits by now, so the prune won't mistake it for merged until the PR really merges.
   c. Return the session to the main checkout — the inverse of `repo-setup`'s enter step (`ExitWorktree(action: "keep")` in Claude Code; load via `ToolSearch` `select:ExitWorktree` if deferred) — leaving the worktree on disk; the next `repo-setup` prunes it once the PR merges. Follow-up work on the PR (human review comments) re-enters the worktree per `repo-setup`'s **Re-entering later** note — never by prefixing commands.

## Cross-recipe principles

`/implement` is **terminal** — no downstream recipe to hand off to (the forward handoff is the PR, for a human).

- **Kickback to `/scope`** — if implementation surfaces a decision the scope doc never settled, surface: *"this surfaces a scope question — we should pause and kick back to `/scope` to settle it."* The scope doc owns the decision; don't quietly decide it here.
- **Kickback to `/design`** — if implementation reveals a wrong design assumption, surface: *"this challenges a design assumption — we should kick back to `/design`."* User decides whether to context-switch.
- **Pause or abandon before step 10.** A kickback or pause keeps the worktree lock — the branch may have no commits yet, and the lock is its only protection from a concurrent prune; resume via `repo-setup`'s **Re-entering later**. If the user explicitly abandons the branch, offer to remove it outright — a branch with unmerged commits is never pruned, so leaving it just strands it: `ExitWorktree(action: "keep")` → `git worktree unlock <path>` → `git worktree remove <path>` (`--force` only if the user confirms discarding uncommitted work) → `git branch -D <branch>`; if a draft PR exists, also offer to close it and delete the remote branch. In station mode, also offer to move the issue back to the status noted in step 2 (e.g. `backlog`). If the draft PR is closed, also offer to drop its URL from `prs`: read the current list and send it back without that URL. Otherwise `/decompose`'s re-entry reads a dead PR as the issue's work. Skip step 10 after this.
- **No `/research` kickback** — research produces information, not owned decisions. Handle it inline via `dispatch-exploration` (vault or web target). Surface: *"we need to look up X — quick check inline (no `/research` kickback)."*
- **Fresh session for post-merge follow-up.** Post-merge dogfooding or agent-definition changes need a fresh session to take effect — note this at exit when relevant.

## Interaction style

- **Thin recipe.** Sequence and branch; let the primitives do the work. Don't inline what a primitive owns.
- **The plan gate is approval-blocked.** No implementation code before an approved plan (or an audited size-skip).
- **The review loop is interactive.** The human decides when the PR is ready-for-humans — re-review until they're satisfied; never self-publish.
- **No superpowers / no TDD by default.** Tests alongside, never test-first. Both available as execute-step overrides.
- **Merge is a human action.** The recipe ends at "PR ready," it does not merge.
- **Finalize ordering is load-bearing.** Source-message → `cleanup-artifacts` → `publish-pr`. The message must be read before the plan file is deleted; cleanup must precede the squash so a tracked plan file folds out of history.
- **Repo-shaped in v1.** Vault-path is deferred — expect a git repo.
