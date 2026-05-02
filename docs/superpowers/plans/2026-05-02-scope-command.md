# `/scope` Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/scope [topic]`, a slash command that orchestrates a doc-shaping workflow against a single living vault note (the "scope doc"). Re-entrant by design. Includes an extension to `capture-to-vault` to support an `update` mode for refining existing notes.

**Architecture:** Two changes — (1) extend the `capture-to-vault` skill to document an `update` mode that wraps `mcp__dossier-mcp__update_note` and auto-bumps the `updated:` frontmatter field; (2) add a new thin recipe at `commands/scope.md` that resolves an existing scope doc by tag-and-topic search or creates one, walks the Unknowns list on re-entry, and refines via the extended skill. Existing primitives (`load-context`, `dispatch-exploration`) and agents (none new) are reused without modification.

**Tech Stack:** Markdown (skill + slash command files), the existing claude-workflows symlink installer, and the `mcp__dossier-mcp__*` MCP tools (`get_note`, `create_note`, `update_note`, `search_notes`).

**Note on testing:** Skills and slash command recipes are markdown files with no programmatic surface — no automated test framework exercises them. Validation is manual: invoke the recipe in a fresh Claude Code session and observe behavior. The plan reflects this honestly with explicit user-run validation tasks rather than fabricated tests.

---

## File Structure

**New:**
- `commands/scope.md` — the `/scope` slash command recipe. Frontmatter `description:`, body documents principles + the 5-phase workflow.

**Modified:**
- `skills/capture-to-vault/SKILL.md` — add `mode` and `slug` to documented inputs; split the Process section into two paths (`create` and `update`); update the skill description to reflect the two modes.

**Unchanged:**
- `install.sh` — already loops over `commands/*.md` and `skills/*/`. No edits.
- `skills/load-context/SKILL.md`, `skills/dispatch-exploration/SKILL.md`, all agents — used as-is.

---

### Task 1: Extend `capture-to-vault` skill with `update` mode

**Files:**
- Modify: `skills/capture-to-vault/SKILL.md`

- [ ] **Step 1: Read the current skill file**

```bash
cat skills/capture-to-vault/SKILL.md
```

Confirm the existing structure (frontmatter, Input section, Process section with 7 steps, Style guidance, Future scope).

- [ ] **Step 2: Replace the file with the extended version**

Write `skills/capture-to-vault/SKILL.md` with the following exact contents:

```markdown
---
name: capture-to-vault
description: Use during /research, /scope (or any recipe) to write or update a vault note via dossier-mcp. Agent drafts slug + frontmatter + body + citations, writes the note, and surfaces what was captured so the user can redirect afterward. Supports create (new note) and update (refine existing note) modes.
---

# Capture to Vault

Draft a note and write it. Surface the slug and any non-obvious placement decisions afterward so the user can redirect or revise. Do not wait for approval before writing. One note per call.

## Modes

- **create** (default) — write a new vault note via `mcp__dossier-mcp__create_note`.
- **update** — refine an existing note in place via `mcp__dossier-mcp__update_note`. Preserves required frontmatter and auto-bumps the `updated:` field.

## Input

- `mode` (optional) — `create` (default) or `update`.
- `body` — the finding, decision, or synthesis. Markdown. Lead with the conclusion or key takeaway. In update mode, this represents the intended new state of the body (or a description sufficient to derive it from the loaded current state).
- `slug` (required for update mode) — the existing note's slug.
- `related` (optional) — vault slugs the note references. If absent, infer from body content and recent session context.
- `citations` (optional) — list of `{title, url, accessed}` entries from web-researcher findings. Include whenever the body draws on web sources.
- `parent_slug` (optional, create mode only) — path prefix hint, e.g. `projects/relocation`. If absent, infer from content and vault structure. Ignored in update mode.

## Process — create mode

1. **Draft the destination slug.**
   - If `parent_slug` is supplied: `<parent_slug>/<topic-slug>`.
   - Else: infer from body content and related notes. Place as a sibling to the most relevant related note. Avoid `inbox/` unless nothing better fits.

2. **Draft the frontmatter:**
   - `title` — readable title derived from the body's main claim
   - `date` — today's date (YYYY-MM-DD)
   - `tags` — 2–4 tags inferred from body
   - `related` — the input `related` (or inferred list)

3. **Draft the body.** Ensure:
   - Lead with the conclusion or key takeaway
   - Density over readability — pack in conclusions and reasoning, not just facts
   - Self-contained — key context inline, not only via links
   - If `citations` present: include a `## Sources` section at the end listing each citation (title — URL — accessed date)

4. **Write the note.** Call `mcp__dossier-mcp__create_note` with the draft.

5. **Backlink.** For each slug in `related`, call `mcp__dossier-mcp__update_note` to add the new note's slug to that note's `related` field. Skip if already present.

6. **Surface what was written.** Briefly state the created slug and any non-obvious placement decisions (tag choices, parent folder selection). The user can redirect, revise, or ask for edits *after* the write. If the user redirects, update/move the note rather than abandoning the write.

7. **Return:** the created slug.

## Process — update mode

1. **Read the existing note.** Call `mcp__dossier-mcp__get_note` with the supplied `slug` to load its current frontmatter and body.

2. **Generate the updated content.**
   - Preserve all required frontmatter fields from the existing note (`title`, `date`, `tags`, `related`, plus any recipe-specific fields like `status` for scope docs). Do not drop or rename them.
   - Auto-bump the `updated:` field to today's date (YYYY-MM-DD). Add the field if it doesn't exist.
   - If new tags emerge from the new content, merge them into existing `tags` (no duplicates). Do not replace.
   - Merge any new entries in `related` with existing ones (no duplicates). Do not replace.
   - Compose the new full body — integrate the input `body` into the doc as the caller intends. The caller is responsible for handing you a body that represents the desired new state.
   - If `citations` present: integrate into the existing `## Sources` section if there is one, or add one.

3. **Write the note.** Call `mcp__dossier-mcp__update_note` with the updated content. Pass `slug`, `title`, `tags`, `related`, and `content` per the tool's required parameters.

4. **Backlink any new related slugs.** For each slug newly added to `related` (not previously present), call `mcp__dossier-mcp__update_note` on that target note to add this note's slug to its `related` field. Skip already-linked targets.

5. **Surface what changed.** Briefly state the slug and a section-level summary of changes — e.g., "added 2 new unknowns, integrated 3 answers into the Context section, added a Risks section." Avoid byte counts; describe the meaningful changes. The user can redirect or revise post-hoc.

6. **Return:** the slug.

## Style guidance (from `profile.md`)

- **Density over readability** — pack in conclusions and reasoning, not just facts.
- **Self-contained** — key context inline, not only via links.
- **Lead with the conclusion** if there is one.

## Future scope

- Stricter frontmatter validation
- Multi-note splitting for large captures
- Dedup against existing notes before writing
```

- [ ] **Step 3: Verify the file is well-formed**

Run:
```bash
head -1 skills/capture-to-vault/SKILL.md
```
Expected: `---`

Run:
```bash
grep -c '^## Process — ' skills/capture-to-vault/SKILL.md
```
Expected: `2` (one for create, one for update)

Run:
```bash
grep -c '^## Modes$' skills/capture-to-vault/SKILL.md
```
Expected: `1`

- [ ] **Step 4: Commit the change**

```bash
git add skills/capture-to-vault/SKILL.md
git commit -m "$(cat <<'EOF'
Extend capture-to-vault with update mode

Adds an update mode that wraps mcp__dossier-mcp__update_note for
refining existing notes in place. Preserves required frontmatter,
auto-bumps the `updated:` field, merges (rather than replaces) tags
and related slugs, and surfaces a section-level summary of changes.

The /scope recipe relies on this for refinement-loop writes against
the living scope doc. Other recipes can adopt update mode when they
need to refine existing notes rather than create new ones.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Create the `/scope` command file

**Files:**
- Create: `commands/scope.md`

- [ ] **Step 1: Write `commands/scope.md`**

Write the file with the following exact contents:

````markdown
---
description: Project-level scoping — refine a single living vault note for a project, with mandatory unknowns tracking. Re-entrant; agent-judged writes
---

You are starting a `/scope` session. The topic (if provided): $ARGUMENTS

This is the `/scope` recipe of the personal workflows framework — project-level scoping/discovery for shaping a project before decomposition. See `projects/workflows/design` in the vault for the broader architecture.

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
````

- [ ] **Step 2: Verify the file is well-formed**

Run:
```bash
head -1 commands/scope.md
```
Expected: `---`

Run:
```bash
grep -c '^description:' commands/scope.md
```
Expected: `1`

Run:
```bash
grep -c '^## Workflow$' commands/scope.md
```
Expected: `1`

Run:
```bash
grep -c '^   ### NEW-DOC MODE$' commands/scope.md
```
Expected: `1`

Run:
```bash
grep -c '^   ### EXISTING-DOC MODE$' commands/scope.md
```
Expected: `1`

- [ ] **Step 3: Commit the new file**

```bash
git add commands/scope.md
git commit -m "$(cat <<'EOF'
Add /scope slash command

Phase 2 of the workflows project. Project-level scoping/discovery
recipe for refining a single living vault note (the "scope doc")
across many sessions.

Re-entrant by design — most invocations search by tag+topic for an
existing doc and walk its Unknowns list. New-doc mode creates the
artifact. Refinement loop accepts pasted context, integrates inline
via the capture-to-vault update mode added in the previous commit.

Vault-only destination for v1; repo-md, /scope-audit drift check,
and /decompose deferred per the design spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Run installer to symlink the new files

**Files:** No file changes; runs the existing `install.sh`.

- [ ] **Step 1: Run the installer**

```bash
./install.sh
```

Expected output includes:
```
linked /home/ethan/.claude/commands/scope.md -> /home/ethan/workspace/claude-workflows/commands/scope.md
```

The skill `capture-to-vault` was already symlinked, so the modification is picked up via the existing symlink — no new linkage needed for that file.

- [ ] **Step 2: Verify the new symlink**

Run:
```bash
readlink ~/.claude/commands/scope.md
```
Expected: `/home/ethan/workspace/claude-workflows/commands/scope.md`

Run:
```bash
readlink ~/.claude/skills/capture-to-vault
```
Expected: `/home/ethan/workspace/claude-workflows/skills/capture-to-vault`

(Should be unchanged — the directory symlink already exists.)

- [ ] **Step 3: Confirm Claude Code can resolve the slash command**

In a fresh terminal Claude Code session, type `/` and verify `/scope` appears in the slash command list with the description "Project-level scoping...". Sanity check that the file is discovered.

(No commit step — `install.sh` only writes outside the repo.)

---

### Task 4: Manual validation — NEW-DOC MODE

**Files:** none.

This task verifies the new-doc creation path: invoking `/scope` with a fresh topic should run load-context, search for existing scope docs, find none, prompt for project framing, and write a new vault note with required frontmatter and an `## Unknowns` section.

- [ ] **Step 1: Open a fresh Claude Code session**

A fresh session ensures no stale context interferes.

- [ ] **Step 2: Invoke `/scope` with a deliberately new topic**

Pick a topic that does NOT have an existing scope doc in the vault. Examples (pick whichever fits):
- `/scope test-throwaway-2026-05-02` — a deliberately throwaway topic
- `/scope <some genuinely new project idea you've had>`

If unsure whether a topic is new, run `mcp__dossier-mcp__search_notes` for it first via Claude.

- [ ] **Step 3: Observe expected behavior**

The agent should:
1. Call `mcp__dossier-mcp__get_vault_context` (via load-context) before any other action.
2. Call `mcp__dossier-mcp__list_notes` for the inbox (via load-context).
3. Call `mcp__dossier-mcp__search_notes` to look for an existing scope doc on the topic.
4. Surface: "no existing scope doc found for this topic, creating a new one" (or similar wording).
5. Ask the user for 1–3 sentences of project framing if `$ARGUMENTS` alone wasn't enough context.
6. Write a new vault note via `capture-to-vault` (`mode: create`) at a sensible slug under `projects/<slug>/scope.md` or similar.
7. Surface: created slug, what sections it picked, initial unknowns count.

- [ ] **Step 4: Inspect the written doc**

Use `mcp__dossier-mcp__get_note` (via Claude) to load the just-written note. Verify:
- Frontmatter contains `title`, `date`, `updated`, `tags` (must include `scope`), `related`, `status: shaping`.
- Body contains an `## Unknowns` section with at least one `- [ ]` entry.
- Body has additional sections that fit the topic (agent's choice).

- [ ] **Step 5: Clean up the test note (optional)**

If you used a throwaway topic, delete the note via `mcp__dossier-mcp__delete_note` so it doesn't pollute the vault.

- [ ] **Step 6: Record outcome**

If all expected behavior fired, mark this task complete. If something was missing (e.g., no inbox check, no Unknowns section, wrong tag), note the gap — implementation may need a fix.

---

### Task 5: Manual validation — EXISTING-DOC MODE (walk Unknowns)

**Files:** none.

This task verifies the re-entry path: invoking `/scope` with a topic that has an existing scope doc should load the doc, walk its Unknowns list, and integrate any answers via the `capture-to-vault` update mode.

- [ ] **Step 1: Set up a test scope doc** (or reuse the one from Task 4, if you didn't delete it)

If you don't have a scope doc available, first run Task 4 with a topic you'd like to test against. Make sure the doc has at least 2 entries in its `## Unknowns` section.

- [ ] **Step 2: Open a fresh Claude Code session**

- [ ] **Step 3: Invoke `/scope` with the same topic as the existing doc**

Example: `/scope test-throwaway-2026-05-02` (or whatever topic the existing doc covers).

- [ ] **Step 4: Observe expected behavior**

The agent should:
1. Call `mcp__dossier-mcp__get_vault_context` and inbox check.
2. Call `mcp__dossier-mcp__search_notes` for the topic.
3. Find the existing doc and call `mcp__dossier-mcp__get_note` to load it.
4. Present the doc's open Unknowns list to the user (all at once, conversationally).
5. Ask which entries have answers.

- [ ] **Step 5: Provide an answer to one or more unknowns**

Respond with answers to one or more questions from the list (something like: "the answer to question 1 is X; question 2 is still open").

- [ ] **Step 6: Observe the integration**

The agent should:
1. Call `mcp__dossier-mcp__update_note` (via `capture-to-vault` update mode) with the new full doc state.
2. The updated note should have the answer integrated into the relevant body section.
3. The resolved unknown should be removed from the `## Unknowns` list.
4. The `updated:` frontmatter field should be bumped to today.
5. Other frontmatter fields should be preserved.
6. The agent should surface what changed (e.g., "integrated answer to Q1 into Context; removed from Unknowns").

- [ ] **Step 7: Inspect the updated doc**

Load the note via `mcp__dossier-mcp__get_note`. Verify:
- `updated:` is today's date.
- `title`, `date`, `tags`, `status` are preserved (not overwritten or dropped).
- The answered question is no longer in `## Unknowns`.
- The answer text is integrated into a body section.

- [ ] **Step 8: Record outcome**

If all expected behavior fired, mark this task complete. If frontmatter was lost, the wrong note was updated, or the unknowns list wasn't walked, note the gap.

---

### Task 6: Manual validation — refinement loop with pasted context

**Files:** none.

This task verifies the refinement loop: pasting new context (e.g., simulated meeting notes) into the session should cause the agent to integrate that context into the relevant doc section and surface what changed.

- [ ] **Step 1: Continue from the same Claude Code session as Task 5** (or open a fresh one and re-invoke `/scope <topic>`)

- [ ] **Step 2: Paste simulated new context into the conversation**

Send something like:
```
New from a meeting today: we decided to defer the X subsystem until phase 2; Y is now a hard requirement; the team flagged a risk around Z performance.
```

Adjust the content to be plausibly relevant to whatever scope doc you're working on.

- [ ] **Step 3: Observe expected behavior**

The agent should:
1. Identify which body section(s) the new context belongs in (Context, Decisions, Scope, Risks — whichever fit).
2. Call `mcp__dossier-mcp__update_note` (via `capture-to-vault` update mode) with the integrated content.
3. Surface what was integrated and where (e.g., "added Y as a hard requirement under Scope; added Z performance risk under Risks; noted X deferral in Decisions").
4. If new unknowns surface naturally from the context (e.g., "what's the current Z latency baseline?"), add them to `## Unknowns`.

- [ ] **Step 4: Inspect the doc**

Verify the changes landed in the right sections and the `updated:` field bumped.

- [ ] **Step 5: Signal exit**

Tell the agent something like: "I think we're done for now" or "this is ready for decompose." Verify:
- For "done for now": `status:` remains `shaping`.
- For "ready for decompose": `status:` is set to `ready-for-decompose`.
- The agent surfaces a session summary on exit (slug, what changed, unknowns count, status).

- [ ] **Step 6: Record outcome**

If all expected behavior fired, mark this task complete.

---

### Task 7: Update vault project overview note (optional)

**Files:**
- Modify: vault note `projects/workflows/overview` (via `mcp__dossier-mcp__update_note`).

This task notes the new `/scope` command in the workflows project overview. Optional — skip if you prefer to batch vault updates separately.

- [ ] **Step 1: Read the current overview note**

Via Claude, run:
```
mcp__dossier-mcp__get_note(slug: "projects/workflows/overview")
```

- [ ] **Step 2: Add a Phase 2 section above the Auxiliary commands section**

Add a new `## Phase 2 — what shipped (<date>)` section that briefly notes:
- `/scope` recipe shipped, vault-only, with mandatory Unknowns list and re-entrant by tag+topic search
- `capture-to-vault` extended with `update` mode

Keep the diff minimal. Do not edit unrelated sections.

- [ ] **Step 3: Save via `update_note`**

Via Claude, call `mcp__dossier-mcp__update_note` with the modified body. The `updated:` frontmatter field is auto-bumped by the skill convention; if the underlying tool requires it explicitly, set it to today's date.

(No git commit step — vault changes are tracked by dossier-mcp, not this repo.)

---

## Self-Review

**Spec coverage check:**
- Spec "Recipe shape" 5-phase workflow → Task 2 implements all phases ✓
- Spec "Scope doc structure" frontmatter (title/date/updated/tags/related/status) → Task 2 specifies in NEW-DOC MODE step (e); Task 1 update mode preserves these ✓
- Spec "Required body element — Unknowns section with `- [ ]`" → Task 2 NEW-DOC MODE step (c) requires it; Task 4 verifies; Task 5 walks it ✓
- Spec "Default placement: projects/<slug>/scope.md, agent-determined" → Task 2 NEW-DOC MODE step (d) ✓
- Spec "capture-to-vault extension" with mode/slug/auto-bump-updated → Task 1 implements all three ✓
- Spec "Files affected — new commands/scope.md, modified skills/capture-to-vault/SKILL.md" → Tasks 1, 2 ✓
- Spec "Files affected — install.sh unchanged" → Task 3 just runs it; doesn't edit ✓
- Spec "Re-entry via tag + topic search" → Task 2 RESOLVE SCOPE DOC step + EXISTING-DOC MODE; Task 5 verifies ✓
- Spec "Status frontmatter (shaping | ready-for-decompose | archived)" → Task 2 step 4(f) sets status on exit signals; Task 6 verifies ✓
- Spec "Surface 'no existing match found' before writing on miss" → Task 2 RESOLVE SCOPE DOC step (0 matches branch) ✓
- Spec "Backlink merge (no duplicates) on update" → Task 1 update mode step 4 ✓
- Spec success criteria — verification across multiple invocations → Tasks 4, 5, 6 cover the three primary modes; success requires all three plus extended dogfood (out of plan scope, in spec validation criteria)

No gaps.

**Placeholder scan:** No "TBD," "TODO," "implement later," or "fill in details." All file contents are exact. All commands are exact. The only deliberate user-discretion point is "Pick a topic that does NOT have an existing scope doc" in Task 4 Step 2, which is intrinsic to the task being a manual validation.

**Type/identifier consistency:**
- `mode: create` and `mode: update` used consistently throughout
- `mcp__dossier-mcp__get_note`, `mcp__dossier-mcp__create_note`, `mcp__dossier-mcp__update_note`, `mcp__dossier-mcp__search_notes`, `mcp__dossier-mcp__list_notes`, `mcp__dossier-mcp__delete_note`, `mcp__dossier-mcp__get_vault_context` — all the actual MCP tool names used in this vault, consistent across tasks
- `## Unknowns` section name consistent across spec, plan, recipe text, and validation steps
- `status` values `shaping | ready-for-decompose | archived` consistent across spec and recipe
- Frontmatter field names (`title`, `date`, `updated`, `tags`, `related`, `status`) consistent
- File paths (`commands/scope.md`, `skills/capture-to-vault/SKILL.md`) consistent

---

## Execution notes

- Tasks 1, 2, 3 are deterministic and fast (~10 minutes total).
- Task 3 is just running the installer; no commit.
- Tasks 4, 5, 6 require fresh Claude Code sessions and are the gating validation. They depend on each other in sequence (Task 5 needs an existing doc, Task 6 continues from Task 5's session — though it can also run independently with any existing scope doc).
- Task 7 is optional housekeeping; can be deferred or done by hand later.
- The full implementation is two commits (Tasks 1 and 2). Tasks 3–7 do not touch the repo.
