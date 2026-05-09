---
description: Early-stage design exploration — settle the shape of a feature/recipe/system before scoping its implementation. Re-entrant; agent-judged writes
---

You are starting a `/design` session. The topic (if provided): $ARGUMENTS

This is the `/design` recipe of the dossier-tradecraft framework — early-stage design exploration for settling the shape of a feature/recipe/system before its implementation gets scoped.

## Principles

- **Vault is the home.** The design note lives in the vault as long-lived rationale across many sessions. If we're in a repo, that's additive context — not a different destination.
- **Re-entry is typical.** Most invocations refine an existing design note rather than creating a new one. Search by tag (`design`) + topic, not by path.
- **Required structural element: an `## Approach` section.** Forces synthesis posture; prevents option-collection-without-decision. Other sections are agent-driven per topic.
- **Holistic refinement, not Unknowns walk.** Design iteration touches intertwined elements (architecture, components, data flow). EXISTING-DESIGN mode presents a summary and invites refinement — no checklist to walk.
- **Agent-judged writes.** Decide slug, structure, and edits directly; surface what was done so the user can redirect post-hoc. No propose-then-approve gates.
- **Inline integration.** Findings during the session land in the design note itself. Substantive web research that warrants standalone capture goes through `/research` (see Step 4.c).
- **Loop exits on natural signal.** No 3-option decision matrix at every cycle.

## Workflow

1. **Load context.** Invoke the `load-context` skill (vault grounding: profile, inbox check, project area pre-warm). If the working directory is inside a git repo, also note the cwd, current branch, and whether a project agent-instruction file (CLAUDE.md, AGENTS.md, etc.) is present.

2. **Resolve design doc.** Search the vault for an existing design note on this topic.
   - Use `mcp__dossier-mcp__search_notes` with the topic terms; filter for `tag:design` if the search supports it, otherwise check the `tags` field on each candidate.
   - **1 match** → call `mcp__dossier-mcp__get_note` to load it, enter EXISTING-DESIGN MODE.
   - **>1 match** → list candidates briefly (slug + title) and ask the user which to continue with.
   - **0 matches** → before writing, surface "no existing design note found for this topic, creating a new one" so the user can redirect if they expected a match. Then enter NEW-DESIGN MODE.

3. **Branch on mode:**

   ### NEW-DESIGN MODE

   a. If `$ARGUMENTS` was empty, ask the user to describe the problem briefly (1–3 sentences). Otherwise treat the topic as initial framing and confirm if anything is unclear.

   b. **Optional vault grounding.** If the topic clearly needs grounding from existing vault context, invoke `dispatch-exploration` with appropriate vault queries. Otherwise skip. For substantive web research, see Step 4.c (research side-jump) — don't absorb `/research` into `/design`.

   c. **Conversational design dialog.** Ask clarifying questions one at a time, multi-choice when possible. Propose 2–3 approaches with tradeoffs; lead with your recommendation and reasoning. Iterate until the user converges on a consolidated design. The dialog is the work — don't seek synthesis prematurely.

   d. **Decide structure.** The body MUST include an `## Approach` section — the chosen design statement, current best-state, written even when status is `shaping`. Recommended optional sections (include only when the cue applies):
      - `## Considered alternatives` — when the design space had real tradeoffs you considered and rejected
      - `## Open considerations` — only when items remain genuinely unsettled at session-end; don't manufacture content
      - `## Out of scope` / `## Deferred to v2 / future` — when intentionally deferring future items the design *could* address but won't
      - `## Decisions log` — when the chosen design has non-obvious decisions whose rationale future-you will want to recall
      - `## Failure modes / motivation` — when the problem-space has specific failure modes the design addresses
      - `## Adjacent context` — when positioning vs related work matters

   e. **Decide placement.** Default pattern: `projects/<area>/<topic>-design` co-located with the project area. If no related project area exists, create one at write time (agent picks the area slug from topic + adjacent vault structure). For multi-area topics, pick a primary based on strongest topic match and list cross-references via `related`. Surface the chosen path so the user can redirect post-hoc. The `design` tag makes location-independent re-entry work, so don't agonize over the path.

   f. **Build the frontmatter:**
      ```yaml
      ---
      title: <Context> — <Topic Description> Design
      date: <today, YYYY-MM-DD>
      updated: <today, YYYY-MM-DD>
      tags: [design, <1-3 topic-specific tags>]
      related: [<related vault slugs>]
      status: shaping
      ---
      ```
      Title: when the topic is a recipe-modification, prefix with the modified recipe (e.g. `/research — Source Cross-Verification Design`); otherwise lead with the topic name. Trailing "Design" marks the doc type. The `design` tag is required; topic-specific tags are agent judgment (`<topic-slug>-recipe` is the convention for recipe-modification designs).

   g. **Write directly.** Invoke the `capture-to-vault` skill in `mode: create`, passing the body, related slugs, parent_slug hint. Surface what was written: slug, structure decisions (which optional sections you picked and why if non-obvious), placement choice if non-obvious.

   ### EXISTING-DESIGN MODE

   a. **Present the current design summary.** Read from the loaded doc and surface:
      - Problem statement (one paragraph)
      - Approach (key bullets from `## Approach`)
      - Status of major considerations (decided / open / deferred-to-v2)
      - Recent kickback or refinement context if visible

   b. **Invite refinement.** Ask the user: "what do you want to iterate on?" Open-shaped dialog from there. *Don't walk the doc section-by-section* — design iteration is holistic, not list-driven.

4. **Refinement loop.**

   a. **Accept new context.** The user may paste notes, summarize info gathering, direct a lookup, or arrive with kickback context from a downstream recipe.

   b. **Inline lookup if needed.** If a quick or factual lookup is required, invoke `dispatch-exploration` with `target: vault` (or `web` for fast factual checks). Keep these tight — they're grounding, not standalone research.

   c. **Surface research side-jump if substantive.** If a question surfaces that needs deeper research (landscape scan, multi-source comparison, exploratory), surface conversationally: *"this looks like `/research` territory; should we step out and come back?"* User decides. After `/research` returns, re-invoke `/design` with the new context as refinement input.

   d. **Surface upstream kickback if it arises.** Rare for `/design` — research is the only upstream phase, and a kickback to research is structurally a side-jump (4.c). If user direction reveals the framing was wrong, the recipe is already re-entrant; refinement absorbs it.

   e. **Integrate inline.** Update the relevant section(s) of the doc. Don't create separate vault notes for findings — they land in the design note.

   f. **Surface refinements.** Edit and show — no approval gate. The user audits by reading what you wrote.

   g. **Discuss + iterate.** Continue the conversation. The user may redirect at any time.

   h. **Watch for exit signals.** When the user says "done for now," "ready for `/scope`," "this is locked," or similar, prepare to exit. Update `status:` accordingly:
      - "done for now" / no explicit signal → keep `status: shaping`
      - "ready for `/scope`" / "locked" → set `status: ready-for-scope`
      - "this is done / archived" → set `status: archived`

5. **Exit.** Final write via `capture-to-vault` in `mode: update`, passing the slug and the current full intended state of the body. Surface: slug, session summary (what changed), current status.

## Interaction style

- The user audits by reading the doc as it changes — don't seek approval before edits.
- EXISTING-DESIGN MODE is "present summary, invite refinement," not Unknowns walk. Design iteration is holistic.
- Don't manufacture sections the topic doesn't need — especially `## Open considerations`. Include only when there are genuinely open items.
- Re-entry uses tag + topic search. Don't rely on hardcoded paths.
- If the user pivots topic mid-session, surface that the loaded doc may not be the right home before continuing — they may want a new doc.
- The `## Approach` section is the only required structural element. Everything else is your judgment.
- **Kickback awareness.** Watch for research side-jump cues (Step 4.c). `/design` is more often the *target* of kickback from `/scope` downstream — receive that context and integrate it as refinement input. Doc state stays as-is during a downstream kickback; the recipe doesn't need to do anything special on re-entry beyond the standard load-context refresh.
