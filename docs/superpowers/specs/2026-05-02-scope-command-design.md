# `/scope` Command — Design

**Date:** 2026-05-02
**Status:** Approved, ready for implementation plan
**Project:** Personal Claude Workflows — vault note `projects/workflows/overview`

## Context

The original Phase 2 design called for a single `/plan` recipe spanning multiple shapes of planning work. Brainstorming surfaced that "planning" is too abstract for one recipe — it conflates project-level discovery (research-coupled, fuzzy input, living-doc output) with feature-level decomposition (structured input, task-list output). These have different mechanics and benefit from being distinct workflows.

This spec covers the project-level discovery shape: **`/scope`**. Feature-level decomposition is deferred to a later recipe (likely `/decompose`).

## Problem

Project-level scoping/discovery is the part of Ethan's workflow that:
- Most strongly outperforms ad-hoc prompting from coworkers
- Is hardest to explain in prose because the moves are tacit
- Is most uniquely served by combining vault context, research, and decomposition
- Most often produces planning that doesn't need correction during implementation

The shareability frame (capture Ethan's working process so others can reproduce it via the workflow rather than via Ethan's intuition) drives the recipe to be more explicit and scaffolded than a personal-use design would be.

The user-described session pattern this recipe captures:

1. **Re-entry pattern (typical mode):** Start session → walk the scope doc's unknowns/open-questions list → user reports what's been answered → user adds new context (paste from meetings, info gathering) → doc gets refined.
2. **Required structural element:** The unknowns/open-questions list. Other sections are agent-driven per project.
3. **Living doc:** The scope doc is the durable artifact across many sessions. Conversations come and go; the doc accretes intent.

## Solution

A new slash command `/scope [topic]` that orchestrates a doc-shaping workflow against a single living vault note. Re-entrant by design — most invocations refine an existing doc rather than creating a new one. Research-coupled but lightweight (no full `/research` loop); the doc is the artifact.

## Recipe shape

```
/scope [topic]

1. LOAD CONTEXT
   - Invoke load-context (vault grounding: profile, inbox check, project area pre-warm)
   - If in a repo: lightweight cwd / branch / CLAUDE.md presence snapshot for
     additional context (not used as primary state)

2. RESOLVE SCOPE DOC
   - Search vault for existing scope doc on this topic (search_notes for
     topic + tag:scope)
   - 1 match → load it, enter EXISTING-DOC MODE
   - >1 match → ask user which to continue
   - 0 matches → enter NEW-DOC MODE

3a. NEW-DOC MODE
   - Brief intake: 1–3 sentences from user about the project
   - Optional: dispatch-exploration if user mentions areas to look up
   - Agent decides slug, sections, and body content (Unknowns section required)
   - Writes directly via capture-to-vault (mode: create)
   - Surfaces: slug, what was written, initial unknowns count
     User redirects or revises post-hoc

3b. EXISTING-DOC MODE
   - Load doc into conversation
   - Walk the Unknowns list — agent presents the open questions and asks
     which have answers. Default cadence: present all open unknowns at once
     and let the user respond freely (one, several, or none). Conversational,
     not a per-question gate.
   - Integrate answers directly into the doc body; remove resolved entries
     from the active list
   - Surface what changed

4. REFINEMENT LOOP
   a. User provides new context (paste meeting notes, summarize info gathering,
      direct a lookup)
   b. Agent integrates inline; surfaces what changed
   c. Agent surfaces newly-revealed unknowns or proposed restructures inline
      (no approval gate — just edit and show)
   d. Discuss + iterate; user redirects naturally
   e. Recipe exits on natural user signal ("done for now" /
      "ready for decompose") — status frontmatter updated accordingly

5. EXIT
   - Final write via capture-to-vault (mode: update)
   - Surface: slug, session summary, current unknowns count, status
```

**Design principles:**

- **Vault-only destination.** Repo-md output is deferred. Workflows are dossier-coupled by intent and demonstrate dossier's value.
- **Repo presence is additive context, not a mode switch.** Recipe doesn't branch on repo vs. vault — vault is always the home.
- **Inline research/integration.** Scope sessions don't spawn separate vault notes for findings; updates land in the scope doc itself. Future extension may add an opt-in carve-out for findings worth a standalone note (e.g. a reusable pattern or tool comparison that has value beyond this project).
- **Agent-judged writes throughout.** No propose-then-approve gates. Agent decides slug, structure, and edits directly; surfaces what was done so the user can redirect post-hoc. Matches `/research` v2 capture pattern.
- **Re-entry is the typical mode.** The recipe optimizes for "continue refining an existing doc" rather than "create from scratch." Search by tag + topic, not by path.
- **Loop exits on natural signal, not a decision matrix.** No 3-option prompt at every cycle.

## Scope doc structure

**Frontmatter (required fields):**

```yaml
---
title: <Project Name> — Scope
date: <creation date>          # YYYY-MM-DD
updated: <last edit date>      # YYYY-MM-DD, auto-bumped on every update
tags: [scope, project, <project-specific-tags>]
related: [<related vault slugs>]
status: shaping                # one of: shaping | ready-for-decompose | archived
---
```

**Required body element — the Unknowns section:**

```markdown
## Unknowns

- [ ] Question one — short context for why it matters
- [ ] Question two
```

Conventions:
- Active list contains only *open* unknowns. When a question is answered, the agent moves the answer into the relevant section of the body and removes the entry from the active list. No struck-through items kept active.
- Markdown checkbox syntax (`- [ ]`) — semantically meaningful, the agent can walk and update consistently.

**Other body sections — agent's choice per project, no fixed schema.** Common-but-not-required candidates: Intent, Context, Scope (in/out), Decisions, Risks. Agent picks structure that fits the topic; surfaces choices post-write.

**Default placement:** Agent-determined. Sensible default pattern is `projects/<slug>/scope.md` co-located with the project area. Re-entry uses tag + topic search, so location is location-independent in practice.

**Optional `## Session log` section:** if a doc gets long-lived enough, the agent can add dated entries. Not enforced.

## `capture-to-vault` extension

Current behavior: creates a new vault note via `mcp__dossier-mcp__create_note`.

Add an `update` mode for refining an existing note:

```
mode: create (default, current behavior unchanged)
  - Agent drafts slug + frontmatter + body + citations
  - Writes via mcp__dossier-mcp__create_note
  - Surfaces: slug, what was written, placement decisions

mode: update
  - Caller passes the slug of the note to update
  - Agent generates the full new content (frontmatter + body),
    preserving required fields and auto-bumping `updated:` to today
  - Writes via mcp__dossier-mcp__update_note
  - Surfaces: slug, section-level summary of what changed, updated unknowns
    count if applicable
```

**Why extend rather than ship a new skill:** the agent's drafting work is the same in both modes — judgment about structure and content for one vault note. Splitting create/update across two skills would duplicate the drafting guidance for marginal clarity gain.

The skill's existing inputs (`body`, `related`, `citations`, `parent_slug`) carry over. Update mode adds:
- `slug` (required) — the existing note to update
- `mode` (optional, defaults to `create`) — `create | update`

Other recipes can adopt `mode: update` if they ever need to refine existing notes.

## Files affected

**New:**
- `commands/scope.md` — the slash command recipe.

**Modified:**
- `skills/capture-to-vault/SKILL.md` — add `mode` parameter and `update`-mode steps to the documented Process section.

**Unchanged:**
- `install.sh` — already symlinks `commands/*.md` and `skills/*/`. No edits.
- `skills/load-context/SKILL.md`, `skills/dispatch-exploration/SKILL.md` — used as-is.
- All agents.

## Scope

**In v1:**
- `commands/scope.md` recipe with the workflow above
- `capture-to-vault` extension to support `mode: update`
- Vault destination only
- Re-entry via tag + topic search
- Agent-judged structure with required Unknowns section
- Status frontmatter (`shaping | ready-for-decompose | archived`)

**Deferred (likely v2 or later):**

- **Repo-md destination** for work projects. Defer until v1 has dogfood signal.
- **`/scope-audit` drift check.** Separate command, separate brainstorm. Periodic, fresh-context-required mechanics make it structurally distinct.
- **`/decompose` recipe.** Downstream consumer of scope docs marked `status: ready-for-decompose`. Phase 3 work.
- **Cross-doc utilities.** "Show me all open unknowns across all scope docs," etc. Useful but not core.
- **Auto-detection of "ready for decompose."** v1 only flips status on explicit user signal.
- **Project-area scaffolding.** When `/scope` creates a doc for a topic with no project area, v1 creates only the scope doc. No multi-note skeleton.
- **Optional carve-out to standalone vault notes** during a scope session (when a finding has value beyond this project) — extend later if it proves useful.

**Explicit non-goals:**

- **Replace `/research`.** Complementary. `/research` accretes findings into many notes; `/scope` refines one doc.
- **Become a project-management tool.** No priorities, time estimates, assignees, due dates. That's `/decompose` + the issue tracker.
- **Autonomous shaping.** Always interactive.
- **Issue-tracker integration.** Lives in `/decompose`. Scope docs reference concepts and vault notes, not Linear/Jira/GitHub issues.
- **Lock the doc.** Users can edit the `.md` outside `/scope` sessions; recipe doesn't claim ownership. Re-entry just re-reads what's there.

## Success criteria for v1

- Across ~3 scope-shaped projects (mix of personal + work-flavored), `/scope` is preferred over ad-hoc prompting.
- Re-entry into an existing scope doc reliably loads it and walks the unknowns.
- The unknowns list pattern is durable across sessions — the agent doesn't drift its structure.
- The `capture-to-vault` extension supports both modes without bugs.
- The doc is shareable: someone reading it cold (without conversation history) can understand the project's current state.

## Risks

- **Search-based re-entry may produce ambiguous matches.** If multiple scope docs match a topic, the recipe asks the user to disambiguate. If the user's topic phrasing varies session-to-session, search may miss the existing doc and the recipe enters NEW-DOC MODE incorrectly. Mitigation: surface "no existing match found, creating new doc" before writing, so the user can redirect.
- **Agent drift on doc structure.** Without a fixed schema, sections may shift over many sessions. The future `/scope-audit` drift-check addresses this; for v1 the user-side audit (reading the doc as it changes) is the primary safeguard.
- **Capture-to-vault mode misuse.** The recipe must call `mode: create` only for genuinely new docs and `mode: update` for refinements. Bug here either creates duplicate docs or fails to update. Mitigation: recipe explicitly determines mode in step 2, before any write.

## Related

- `projects/workflows/design` — parent architecture
- `projects/workflows/overview` — project status
- `commands/research.md` — pattern reference for agent-judged writes and conversation-shaped loops
- `skills/capture-to-vault/SKILL.md` — the skill being extended
- `skills/load-context/SKILL.md` — invoked at recipe start
