---
description: Feature/story breakdown — consume a ready-for-decompose scope doc and produce a task graph in the issue tracker. Re-entrant; tracker-as-canonical with vault breadcrumb
---

You are starting a `/decompose` session. The topic (if provided): $ARGUMENTS

This is the `/decompose` recipe of the dossier-tradecraft framework — Phase 3, feature/story breakdown. Consumes scope docs at `status: ready-for-decompose` and produces a task graph on the project's issue tracker.

## Principles

- **Tracker is canonical; vault is breadcrumb.** Tasks live in the issue tracker. The scope doc gets a `## Tracked at` append pointing at the issues; no new vault artifact is created. Tracker-as-canonical eliminates the drift between PR auto-close and vault checkboxes.
- **Two-track behavior.** Fast-track for 1–2 issues (small bug fix, single feature). Standard-track for 3+ (sizing + dependency graph; layered fallback for larger breakdowns). Same recipe, different ceremony.
- **The graph is the value.** Sizing and dependencies are coupled — slicing tasks naively loses the parallelism reasoning an LLM is well-suited to do. Don't enumerate; graph.
- **Project-adaptive shape.** Tracker preferences are read from the project's agent-instruction file (CLAUDE.md, AGENTS.md, etc.) (or other project context) as prose — no schema. Vault fallback when no tracker is configured.
- **Cross-team artifact self-containment.** Issue bodies do not reference the vault — issue trackers may be accessed by collaborators without vault access, and vault references are dead-end for them. Vault → tracker links exist one-way only, on the vault side.
- **Agent-judged writes.** Decide sizing call, structure, and prose directly; surface what was done. The only explicit confirmation gate is the fast-track sizing check.
- **Loop exits on natural signal.** No 3-option decision matrix at every cycle.

## Workflow

1. **Load context.** Invoke the `load-context` skill (vault grounding: profile, inbox check, project area pre-warm). If the working directory is inside a git repo, also note the cwd, current branch, and whether a project agent-instruction file (CLAUDE.md, AGENTS.md, etc.) is present, as additional context for the session.

2. **Resolve scope doc.** Search the vault for the scope doc this session is decomposing.
   - Use `mcp__dossier-mcp__search_notes` with the topic terms; filter for `tag:scope` if the search supports it, otherwise check the `tags` field on each candidate.
   - **1 match** → call `mcp__dossier-mcp__get_note` to load it. Read the `status` frontmatter and branch:
     - `ready-for-decompose` → continue to Step 3 and proceed with breakdown.
     - `tracked` → enter RE-ENTRY MODE (see below).
     - `shaping` → surface "scope doc is still `shaping`; want to kick back to `/scope` and finalize before decomposing?" and let the user redirect.
     - `archived` → surface "scope doc is `archived`; reopen for further breakdown?" before proceeding.
   - **>1 match** → list candidates briefly (slug + title + status) and ask which to continue with.
   - **0 matches** → surface "no scope doc found for this topic — `/decompose` consumes scope docs; want to start with `/scope` first?" Don't proceed without one.

3. **Resolve tracker config.** Read tracker hints from auto-loaded session context (the project's agent-instruction file auto-loads in repo sessions; the vault profile and project notes loaded in Step 1 may also pin a tracker). Look for tracker name + shape preferences in prose form (e.g., "issues in GitHub, flat with labels for grouping").
   - **Found** → use the configured tracker and shape.
   - **Missing** → surface: *"No issue tracker config in context — which tracker (GitHub / dossier-station / Shortcut / Jira) or vault fallback? I can write your choice to your project's agent-instruction file (`AGENTS.md` or `CLAUDE.md`, whichever exists; defaults to `AGENTS.md` if creating new) if you want it persistent."* User picks; persistence is opt-in per-prompt; do not silently edit the agent-instruction file.
   - v1 implements **GitHub** (via the `gh` CLI), **dossier-station** (via dossier-mcp's station issue tools) and **vault fallback**. If the user picks Shortcut or Jira, surface the limitation and offer vault fallback for the session.
   - **Dossier-station** is selected when the tracker config names "dossier-station" (e.g., "issues in dossier-station, project `homelab`"). The config may also name the station `project` slug, the station vault and the instance's ID prefix; ask for the project slug if it's missing. Station mode needs dossier-mcp connected with a station vault configured. If the issue tools fail (server down, no station vault), stop and surface the error. Never fall back to GitHub or the vault on your own, because that would silently file the breakdown in the wrong tracker.
     - **Name the station on every read.** Pass the station's `vault` (from config, or the only station) to `search_notes` and to `get_note` on `issues/<id>`. Without it, a station that's down degrades to a notice, and the read quietly answers from the other vaults.
     - **One repo per issue** is the station convention. While proposing the graph (Step 5), split any task that spans repos into one issue per repo, so Step 8 files only what the user has seen.

4. **Sizing call (fast-track vs standard-track).** Read the scope doc's Decisions, Intent, and structural sections. Estimate distinct concerns: 1–2 → fast-track; 3+ → standard-track. Use scope-doc complexity and distinct-concern count as priors; don't apply a brittle threshold.
   - Surface your estimate. For fast-track: *"This looks fast-track-shaped — collapse to a single issue?"* (or *"…to a pair: setup + feature?"*) and let the user confirm or override. For standard-track, just announce: *"This is standard-track — I'll propose a graph (tasks + sizing + deps)."*

5. **Branch on mode:**

   ### FAST-TRACK MODE

   a. Draft 1–2 issues per the universal floor (Step 7).
   b. Surface the drafts inline; iterate with the user.
   c. Once converged, write the issues per the configured tracker (Step 8) and update the scope doc (Step 9).

   ### STANDARD-TRACK MODE

   a. **Flat proposal.** For 3–5 issues with no clear sub-areas: propose a flat task list with sizing + dependencies in a single pass. Iterate with the user until converged.

   b. **Layered proposal for larger breakdowns.** If the work has clear sub-areas or feels overwhelming as a flat list, walk three phases:
      - **Phase 1 — Milestones.** Propose milestone groupings; iterate to convergence before moving on.
      - **Phase 2 — Per-milestone tasks + within-milestone dependencies.** Walk one milestone at a time; tasks + sizing + intra-milestone deps.
      - **Phase 3 — Cross-milestone dependencies.** Surface deps that cross milestones.
      - **Intra-recipe kickback.** If Phase 2 or 3 reveals a milestone reshape (a task belongs elsewhere, two milestones should merge, one should split), surface: *"this rebalances the milestones — pause and revisit Phase 1?"* Mid-session iteration is conversation-only — no rollback cost.

   c. Once converged, write the issues per the configured tracker (Step 8) and update the scope doc (Step 9).

6. **Refinement loop (during proposal).**

   a. **Inline lookup if needed.** If a quick or factual lookup is required (e.g., "does `gh` support sub-issues?"), invoke `dispatch-exploration` with `target: vault` (or `web` for fast factual checks). Findings integrate into the breakdown conversation directly. **No `/research` kickback** — research produces information, not owned decisions, so handle it inline. Surface: *"we need to look up X — quick web check inline (no `/research` kickback)."*

   b. **Cross-recipe kickback to `/scope`.** If breakdown surfaces a decision the scope doc didn't settle, surface: *"this surfaces a scope question — we should pause and kick back to update the scope doc."* User decides whether to context-switch. The scope doc is the artifact owner; updating it inline from `/decompose` would create vault/breakdown disagreement.

   c. **Cross-recipe kickback to `/design`.** If breakdown surfaces a wrong design assumption, surface: *"this challenges a design assumption — we should kick back to `/design` to revisit."* User decides. Same artifact-ownership reasoning.

   d. After kickback, on re-entry to `/decompose`, the recipe re-reads the scope doc fresh and re-shapes the breakdown accordingly.

7. **Issue body — universal floor.**

   Every issue includes:
   - **Title** — imperative, scoped to the task.
   - **Description** — 1–3 sentence prose paragraph stating what the task is and why it exists.
   - **Acceptance criteria** — markdown checklist (`- [ ]`) of concrete done conditions.
   - **Cross-issue links** — inline plaintext `Blocks: #N`, `Blocked by: #N`, `Related: #N` where applicable. GitHub auto-creates back-references when issue numbers appear in bodies — no special API needed. In dossier-station mode, blockers go in the `blocked_by` field instead, and `Blocks:` is dropped (it's the inverse of `blocked-by`, and a dependant's ID doesn't exist yet when its blocker is filed). `Related:` stays as plaintext station IDs (`Related: STN-140`) for issues that already exist. When the related issue is filed later in the same breakdown, it carries `Related:` in its own body, and the earlier issue gets a `comment_issue` with `Related: <new ID>` once the later one exists. Station issue bodies can't be edited through the tools.
   - **Per-tracker required fields** — per the project's agent-instruction file (e.g., `--label` flags for GitHub).

   **Do not include vault backlinks in issue bodies.** Issue trackers may be accessed by collaborators without vault access; vault references are dead-end for them. Vault → tracker links live only on the vault side, in `## Tracked at`.

8. **Write the issues.**

   ### GitHub mode

   For each issue: invoke `gh issue create --title "..." --body "..."` (with `--label` and any other per-tracker fields per the project's agent-instruction file). Capture the returned issue URL/number. Cross-issue links use plaintext `#N` references in bodies; write parents first so children can reference their numbers.

   On mid-write failure: stop, surface the error and the partial state (issues already written), and **stay at `ready-for-decompose`**. Do not flip status — the status is meaningful only when the breakdown is complete.

   ### Dossier-station mode

   **Pre-check, before writing.** Look for issues the station already tracks: `query_issues` with the configured `project`, plus `search_notes(type: "issue")` on each task's key terms. Fold matches into the graph as pre-existing issues before filing anything, under the same rules as the duplicate check below (adopting, `done`/`canceled` candidates, marking, exit audit). The duplicate check is the station's safety net, not the first look. On a re-run after a partial write, the issues this breakdown already filed are its own. Identify them from the earlier partial-state report, or ask the user, then take them back as written without commenting on them or marking them pre-existing.

   For each issue, call `mcp__dossier-mcp__create_issue` with:
   - `title` and `body` (the universal floor)
   - `project`: the station project slug from config
   - `repos`: the bare repo name, e.g. `[home-ansible]`, not `owner/name`. One per issue (split during the proposal, per Step 3).
   - `labels`: per the project's agent-instruction file
   - `blocked_by`: the station IDs of the task's blockers

   Write blockers first (topological order), so every `blocked_by` names an issue that already exists. Capture each ID from the `Created issue <id>: "<title>".` result. Agent-filed issues always land in `triage`; that's station policy, so don't try to set an initial status.

   **Duplicate check.** A result starting `No issue was created:` is not an error. The station found existing issues that may already cover this one, and it lists up to 5 candidates (`id`, `title`, `status`, `score`). Read each plausible candidate (`get_note` on `issues/<id>`) and decide:
   - **A candidate covers the task.** `comment_issue` on it with what this breakdown adds (scope, AC, dependencies). Then use its existing ID in the graph and in `## Tracked at`, marked as pre-existing. Don't file the task again. If the graph gives it blockers, offer `update_issue` with its current `blocked_by` plus the new IDs; the list is replaced, not merged.
   - **Every candidate is ruled out.** Re-send the same `create_issue` call with `confirm_new: true`. Mention any related-but-distinct candidate's ID in the body (`Related: STN-99`). Use `blocked_by` only when that candidate really blocks this task.
   - **Ambiguous**, or the only match is `done` or `canceled`. Ask the user before commenting or re-filing. A closed match may mean the work already shipped, or it may need reopening.

   Clear matches and clear misses are agent-judged, as everywhere in this recipe. Record every duplicate decision for the exit summary.

   On mid-write failure (any error result, including an `invalid_request` or an unknown blocker): same as GitHub mode. Stop, surface the error, the issues already written, and any comments already posted on adopted issues, and **stay at `ready-for-decompose`**.

   ### Vault fallback mode

   No `gh` calls. The breakdown lands inline in the scope doc as a `## Tasks` section (handled in Step 9 via `capture-to-vault`).

9. **Update the scope doc.** Edit the scope doc in place via the `capture-to-vault` skill in `mode: update`, passing the slug and the intended new state of the body. Preserve all existing frontmatter (the skill auto-bumps `updated:`).

   **GitHub mode:**
   - Append (or update) a `## Tracked at` section.
     - **Flat:** plain markdown list of issue links with titles.
     - **Layered:** grouped by `### <Milestone>` headings, each with the milestone's issue list under it.
   - Flip `status:` from `ready-for-decompose` to `tracked`. Only after every planned issue has been written successfully — no half-flips.

   **Dossier-station mode:**
   - Append (or update) a `## Tracked at` section listing station IDs as plain text with titles: `- STN-142 — <title>`. Don't use wiki-links, because the scope doc and the station may be in different vaults.
     - Mark pre-existing issues (adopted in the pre-check or the duplicate check), e.g. `- STN-99 — <title> (pre-existing)`.
     - **Flat** or **Layered** grouping as in GitHub mode.
   - Flip `status:` from `ready-for-decompose` to `tracked`, under the same rule as GitHub mode: only after every planned issue has been written.

   **Vault fallback mode:**
   - Grow a `## Tasks` section in the scope doc.
     - Flat markdown checklist (`- [ ]`) of tasks.
     - Group under `### <Milestone>` headings only when the breakdown is layered.
     - Dependencies in prose form, e.g. `(blocked by: setup)`.
     - Acceptance criteria as a nested checklist under each task.
   - Skip `## Tracked at` — the `## Tasks` section is the breadcrumb.
   - Flip `status:` from `ready-for-decompose` to `tracked`. Drift between checklist state and reality is the accepted cost of zero-tracker setup.

10. **Exit.** Surface: scope-doc slug, count of issues created, any cross-issue links, tracker target, and the new status. In dossier-station mode, report created and adopted issues as separate counts. Also list each adoption and duplicate decision, from the pre-check and the duplicate check: the issue adopted (and commented on), or the candidates ruled out before `confirm_new`. The user audits by reading the scope doc and the tracker.

## RE-ENTRY MODE (status: tracked)

When the resolved scope doc is already `tracked`:

a. Read the scope doc's `## Tracked at` (GitHub or dossier-station mode) or `## Tasks` (vault fallback) to enumerate the breakdown.

b. **Pull live status.**
   - **GitHub mode:** call `gh issue list` filtered by the labels referenced in the project's agent-instruction file, or by the issue numbers from `## Tracked at`. Surface a concise summary, e.g. *"5 of 7 issues closed."*
   - **Dossier-station mode:** call `mcp__dossier-mcp__query_issues` with the configured `project`, and keep the IDs listed in `## Tracked at`. Fall back to `get_note` on `issues/<id>`, naming the station `vault`, for any ID the query misses, e.g. one that has moved to another project. `done` and `canceled` count as closed. Surface a concise summary, e.g. *"5 of 7 issues done, 1 in review."*
     - **`in-review` issues with merged PRs.** Merges don't move station status in v1: there's no merge webhook, and `prs:` is recorded but nothing acts on it. For each `in-review` issue, check the state of each PR in `prs:` with the forge's CLI (`gh pr view <url> --json state` for GitHub), or ask the user when there's no CLI for that forge. Offer to move the ones whose PRs have all merged to `done` via `update_issue`, then count them as closed.
   - **Vault fallback mode:** read the `## Tasks` checkbox state from the doc and summarize.

c. **If all closed/done** → surface *"all tracked issues are closed — archive scope?"* On user confirmation, flip `status:` to `archived` via `capture-to-vault` in `mode: update`.

d. **If partial** → ask the user what they want to do (add issues, adjust the graph, revisit a milestone, kick back to `/scope` or `/design`). New issues follow the same universal-floor and write path; the scope doc's `## Tracked at` (or `## Tasks`) updates in place; status stays `tracked`.

## Interaction style

- The user audits by reading the breakdown drafts and the scope doc as they update — don't seek approval before edits beyond the fast-track sizing confirmation.
- The graph (sizing + deps + parallelism) is the primary value — don't degrade the recipe to a list of titles.
- Re-entry uses tag (`scope`) + topic search. Don't rely on hardcoded paths.
- **Kickback awareness.**
  - Upstream kickback to `/scope` (missing decision) and `/design` (wrong assumption) — surface conversationally with the wordings in Step 6.
  - **No `/research` kickback** — research produces information, not owned decisions, so handle inline via `dispatch-exploration`.
  - Forward handoff to `/implement` (when it ships) is via the tracker (issue numbers or station IDs), not via the vault.
- Status flips are atomic — `ready-for-decompose → tracked` happens only after every planned issue lands successfully.
- Don't write half a breakdown. If the user pivots mid-session, surface that rather than silently re-shaping mid-write.
