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
