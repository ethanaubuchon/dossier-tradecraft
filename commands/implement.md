---
description: Feature implementation in a repo — ticket → plan gate → develop-to-plan → draft-PR review loop (human gate) → squash-clean finalize. Thin recipe over six overridable primitives; dossier-mcp the only hard dependency.
---

You are starting an `/implement` session. The ticket / spec (if provided): $ARGUMENTS

This is the `/implement` recipe of the dossier-tradecraft framework — Phase 4, feature implementation in a repo. It consumes **one ticket** and drives it through: branch → plan → code → review → PR. The recipe is thin: it sequences six overridable primitives and hosts the interactive review loop in the main conversation.

## Principles

- **The spine is the developer's own flow — not superpowers, not TDD.** Develop to the plan; tests are written alongside and verified, **never test-first**. Superpowers / TDD execution are available as project-level execute-step overrides, not the default.
- **Ticket-driven entry.** v1 assumes a ticket exists (issue# / spec-path / explicit ask). Writing the ticket is `/decompose`'s or an ad-hoc job — out of `/implement`'s scope. The bare no-ticket path is deferred.
- **Thin recipe over overridable primitives.** The recipe sequences and branches; `repo-setup`, `plan-file`, `agent-review`, `open-draft-pr`, `publish-pr`, `cleanup-artifacts` do the work. Each is project-overridable.
- **Review on committed work, in a draft PR, behind a human gate.** Never review unstaged changes. The draft PR exists before review so the PR-framed reviewer agents have a PR to attach to; the human decides when it's ready-for-humans.
- **Squash kills review-iteration noise at draft→ready** — not single-commit dogma.
- **Dependency-free floor; toolkit ceiling via override.** `agent-review` ships a dependency-free reviewer; the `pr-review-toolkit` panel is an opt-in override. Nothing beyond dossier-mcp is required.
- **Repo-shaped.** Vault-path is out of v1 — `/implement` expects a git repo.

## Workflow

1. **Load context.** Invoke the `load-context` skill (vault grounding: profile, inbox check, project pre-warm). Note the cwd, current branch, and whether a project agent-instruction file (CLAUDE.md, AGENTS.md, etc.) is present — its prose carries per-project conventions (test command, sub-agent routing, PR shape). If the working directory is **not** a git repo, stop and say so — `/implement` is repo-shaped in v1.

2. **Resolve the entry ticket.** From `$ARGUMENTS`:
   - **issue number** (e.g. `#42` / `42`) → `gh issue view <n>` and treat the issue (title + body + AC) as the spec.
   - **spec path** → read the file and treat it as the spec.
   - **explicit ask** (prose) → treat the prose as the scope for this session.
   - **nothing / no ticket** → the bare no-ticket path is deferred; ask the user to point at an issue or spec (or write a ticket first via `/decompose` or ad hoc). Don't invent scope.

3. **`repo-setup`.** Invoke the `repo-setup` skill. Derive the branch name from the ticket as `<type>/<desc>` (`feat/`, `fix/`, `chore/`, `story/S-<id>-<desc>`); pass it in. The skill fast-forwards `main`, prunes merged work, and creates the feature branch + worktree. Work proceeds in that worktree.

4. **`plan-file` gate.** Invoke the `plan-file` skill with the ticket reference. It writes an **approval-blocked** plan for the branch (the skill owns the path + naming) and blocks implementation until the plan exists and the user approves it. For genuinely trivial changes, the skill's size-skip applies — state the one-line skip reason so it's auditable. **Write no implementation code before approval.**

5. **Execute (inline).** Develop to the approved plan in the main session. Tests are written alongside and verified — **never test-first; no TDD by default.** Run the project's verify/test command (from the agent-instruction file). Keep the plan current as a living document if the approach shifts.
   - **Sub-agent routing is per-project.** Which steps may be delegated to a subagent vs. must stay in the main session is declared in the repo's agent-instruction file (prose) for soft preferences, or enforced by a primitive override + PreToolUse hook for hard constraints (e.g. a step whose interactive approval needs the main session). Honor both.
   - **Execution override.** A repo that wants superpowers / TDD execution drops a project-level override of this step.

6. **Commit.** Commit the work. Review runs on **committed** work, not unstaged changes.

7. **`open-draft-pr`.** Invoke the `open-draft-pr` skill: push the branch and open a **draft** PR; capture the PR ref. Compose the PR title/body from the plan-file / ticket.

8. **`agent-review` loop (interactive — the human gate lives here).**
   a. Invoke the `agent-review` skill on the committed diff, passing the `plan-file` path + the ticket AC as review context. It returns structured findings.
   b. Present the findings. Address the ones worth fixing (edit + commit fixes on the branch). Re-invoke `agent-review` on the updated diff.
   c. **Loop until the user is satisfied that the PR is ready-for-humans.** This ready-to-publish decision is the human gate — it stays in the recipe, never inside a primitive. Don't self-publish.

9. **Finalize.** In this order (the order matters):
   a. **Source the squash commit message** from the `plan-file` (story ref + change summary) — *before* cleanup deletes the file. If the plan was size-skipped (step 4), source it from the ticket plus the audited skip reason instead.
   b. **`cleanup-artifacts`.** Invoke the skill to delete this branch's plan file.
   c. **`publish-pr`.** Invoke the skill with the branch, the sourced commit message, and the PR ref. It squashes (soft-reset + `git add -A` + recommit + `--force-with-lease`) and marks the PR ready.

10. **Exit.** Surface: the PR ref (URL), a one-line summary of what shipped, and the status — **PR is ready for human review, not merged.** Merging stays a human action; `/implement` ends at "ready."

## Cross-recipe principles

`/implement` is **terminal** — no downstream recipe to hand off to (the forward handoff is the PR, for a human).

- **Kickback to `/scope`** — if implementation surfaces a decision the scope doc never settled, surface: *"this surfaces a scope question — we should pause and kick back to `/scope` to settle it."* The scope doc owns the decision; don't quietly decide it here.
- **Kickback to `/design`** — if implementation reveals a wrong design assumption, surface: *"this challenges a design assumption — we should kick back to `/design`."* User decides whether to context-switch.
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
