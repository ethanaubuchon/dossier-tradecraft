---
description: Project-level scoping — refine a single living vault note for a project, with mandatory unknowns tracking. Re-entrant; agent-judged writes
---

You are starting a `/scope` session. The topic (if provided): $ARGUMENTS

This is the `/scope` recipe of the dossier-tradecraft framework — project-level scoping/discovery for shaping a project before decomposition.

## Principles

- **Vault is the home.** The scope doc lives in the vault as the durable artifact across many sessions. If we're in a repo, that's additive context — not a different destination.
- **Re-entry is typical.** Most invocations refine an existing scope doc rather than creating a new one. Search by tag (`scope`) + topic, not by path.
- **Required structural element: an Unknowns/open-questions list.** Other sections are agent-driven per project.
- **Agent-judged writes.** Decide slug, structure, and edits directly; surface what was done so the user can redirect post-hoc. No propose-then-approve gates.
- **Inline integration.** Findings during the session land in the scope doc itself, not as separate vault notes.
- **Loop exits on natural signal.** No 3-option decision matrix at every cycle.

## Workflow

1. **Load context.** Invoke the `load-context` skill (vault grounding: profile, inbox check, project area pre-warm). If the working directory is inside a git repo, also note the cwd, current branch, and whether a CLAUDE.md is present, as additional context for the session — no separate primitive needed.

2. **Resolve scope doc.** Search the vault for an existing scope doc on this topic.
   - Use `mcp__dossier-mcp__search_notes` with the topic terms; filter for `tag:scope` if the search supports it, otherwise check the `tags` field on each candidate.
   - **1 match** → call `mcp__dossier-mcp__get_note` to load it, enter EXISTING-DOC MODE.
   - **>1 match** → list candidates briefly (slug + title) and ask the user which to continue with.
   - **0 matches** → before writing, surface "no existing scope doc found for this topic, creating a new one" so the user can redirect if they expected a match. Then enter NEW-DOC MODE.

3. **Branch on mode:**

   ### NEW-DOC MODE

   a. If `$ARGUMENTS` was empty, ask the user to describe the project briefly (1–3 sentences). Otherwise treat the topic as initial framing and confirm if anything is unclear.

   b. **Optional research.** If the user mentions areas to look up, or if the topic clearly needs grounding from outside the user's input, invoke `dispatch-exploration` with appropriate vault and/or web queries. Otherwise skip.

   c. **Decide structure.** The body MUST include an `## Unknowns` section with markdown checkboxes (`- [ ]`). Other sections — Intent, Context, Scope, Decisions, Risks, etc. — are your call per the topic. Pick what fits; don't manufacture sections beyond what the topic genuinely needs.

   d. **Decide placement.** Default pattern: `projects/<slug>/scope.md` co-located with the project area. You may override based on existing vault structure (e.g., if there's already a `projects/<slug>/` area, use it; if not, create one). The `scope` tag makes location-independent re-entry work, so don't agonize over the path.

   e. **Build the frontmatter:**
      ```yaml
      ---
      title: <Project Name> — Scope
      date: <today, YYYY-MM-DD>
      updated: <today, YYYY-MM-DD>
      tags: [scope, project, <project-specific-tags>]
      related: [<related vault slugs>]
      status: shaping
      ---
      ```

   f. **Write directly.** Invoke the `capture-to-vault` skill in `mode: create`, passing the body, related slugs, parent_slug hint, and any citations. Surface what was written: slug, structure decisions (which sections you picked and why if non-obvious), initial unknowns count.

   ### EXISTING-DOC MODE

   a. **Walk the Unknowns list.** Present the open questions from the doc's `## Unknowns` section to the user. Default cadence: present them all at once, conversationally, and let the user respond freely (one, several, or none). No per-question gate.

   b. **Integrate answers.** When the user provides answers, integrate them into the relevant body section of the doc and remove the resolved entries from the active `## Unknowns` list. If an answer reveals a new unknown, add it.

   c. **Surface what changed.** Briefly state which entries were resolved and where the answers landed.

4. **Refinement loop.**

   a. **Accept new context.** The user may paste meeting notes, summarize info gathering, or direct a lookup ("can you check if X is true," "look up the Y docs," etc.).

   b. **Lookup if needed.** If a lookup is required, invoke `dispatch-exploration` with the appropriate target (`vault` or `web`).

   c. **Integrate inline.** Update the relevant section(s) of the doc with the new context. Don't create separate vault notes for findings — they land in the scope doc.

   d. **Surface refinements.** As you work, surface newly-revealed unknowns or proposed structural changes inline. Edit and show — no approval gate. The user audits by reading what you wrote.

   e. **Discuss + iterate.** Continue the conversation. The user may redirect at any time.

   f. **Watch for exit signals.** When the user says "done for now," "that's enough for today," "I think this is ready for decompose," or similar, prepare to exit. Update `status:` accordingly:
      - "done for now" / no explicit signal → keep `status: shaping`
      - "ready for decompose" → set `status: ready-for-decompose`
      - "this is done / archived" → set `status: archived`

5. **Exit.** Final write via `capture-to-vault` in `mode: update`, passing the slug and the current full intended state of the body. Surface: slug, session summary (what changed), current open-unknowns count, status.

## Interaction style

- The user audits by reading the doc as it changes — don't seek approval before edits.
- The Unknowns walk in EXISTING-DOC MODE is conversational. Don't present a per-question matrix.
- Don't manufacture sections the topic doesn't need.
- Re-entry uses tag + topic search. Don't rely on hardcoded paths.
- If the user pivots topic mid-session (starts shaping something genuinely different), surface that the loaded doc may not be the right home before continuing — they may want a new doc.
- The `## Unknowns` section is the only required structural element. Everything else is your judgment.
