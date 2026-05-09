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
   - **Missing** → surface: *"No issue tracker config in context — which tracker (GitHub / Shortcut / Jira) or vault fallback? I can write your choice to your project's agent-instruction file (`AGENTS.md` or `CLAUDE.md`, whichever exists; defaults to `AGENTS.md` if creating new) if you want it persistent."* User picks; persistence is opt-in per-prompt; do not silently edit the agent-instruction file.
   - v1 implements **GitHub** (via the `gh` CLI) and **vault fallback**. If the user picks Shortcut or Jira, surface the limitation and offer vault fallback for the session.

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
   - **Cross-issue links** — inline plaintext `Blocks: #N`, `Blocked by: #N`, `Related: #N` where applicable. GitHub auto-creates back-references when issue numbers appear in bodies — no special API needed.
   - **Per-tracker required fields** — per the project's agent-instruction file (e.g., `--label` flags for GitHub).

   **Do not include vault backlinks in issue bodies.** Issue trackers may be accessed by collaborators without vault access; vault references are dead-end for them. Vault → tracker links live only on the vault side, in `## Tracked at`.

8. **Write the issues.**

   ### GitHub mode

   For each issue: invoke `gh issue create --title "..." --body "..."` (with `--label` and any other per-tracker fields per the project's agent-instruction file). Capture the returned issue URL/number. Cross-issue links use plaintext `#N` references in bodies; write parents first so children can reference their numbers.

   On mid-write failure: stop, surface the error and the partial state (issues already written), and **stay at `ready-for-decompose`**. Do not flip status — the status is meaningful only when the breakdown is complete.

   ### Vault fallback mode

   No `gh` calls. The breakdown lands inline in the scope doc as a `## Tasks` section (handled in Step 9 via `capture-to-vault`).

9. **Update the scope doc.** Edit the scope doc in place via the `capture-to-vault` skill in `mode: update`, passing the slug and the intended new state of the body. Preserve all existing frontmatter (the skill auto-bumps `updated:`).

   **GitHub mode:**
   - Append (or update) a `## Tracked at` section.
     - **Flat:** plain markdown list of issue links with titles.
     - **Layered:** grouped by `### <Milestone>` headings, each with the milestone's issue list under it.
   - Flip `status:` from `ready-for-decompose` to `tracked`. Only after every planned issue has been written successfully — no half-flips.

   **Vault fallback mode:**
   - Grow a `## Tasks` section in the scope doc.
     - Flat markdown checklist (`- [ ]`) of tasks.
     - Group under `### <Milestone>` headings only when the breakdown is layered.
     - Dependencies in prose form, e.g. `(blocked by: setup)`.
     - Acceptance criteria as a nested checklist under each task.
   - Skip `## Tracked at` — the `## Tasks` section is the breadcrumb.
   - Flip `status:` from `ready-for-decompose` to `tracked`. Drift between checklist state and reality is the accepted cost of zero-tracker setup.

10. **Exit.** Surface: scope-doc slug, count of issues created, any cross-issue links, tracker target, and the new status. The user audits by reading the scope doc and the tracker.

## RE-ENTRY MODE (status: tracked)

When the resolved scope doc is already `tracked`:

a. Read the scope doc's `## Tracked at` (GitHub mode) or `## Tasks` (vault fallback) to enumerate the breakdown.

b. **Pull live status.**
   - **GitHub mode:** call `gh issue list` filtered by the labels referenced in the project's agent-instruction file, or by the issue numbers from `## Tracked at`. Surface a concise summary, e.g. *"5 of 7 issues closed."*
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
  - Forward handoff to `/implement` (when it ships) is via the tracker (issue numbers), not via the vault.
- Status flips are atomic — `ready-for-decompose → tracked` happens only after every planned issue lands successfully.
- Don't write half a breakdown. If the user pivots mid-session, surface that rather than silently re-shaping mid-write.
