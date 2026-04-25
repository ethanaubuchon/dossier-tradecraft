---
name: capture-to-vault
description: Use during /research (or any recipe) to write a research finding, decision, or synthesis as a vault note via dossier-mcp. Agent drafts slug + frontmatter + body + citations, writes the note, and surfaces what was captured so the user can redirect afterward.
---

# Capture to Vault

Draft a note and write it. Surface the slug and any non-obvious placement decisions afterward so the user can redirect or revise. Do not wait for approval before writing. One note per call.

## Input

- `body` — the finding, decision, or synthesis. Markdown. Lead with the conclusion or key takeaway.
- `related` (optional) — vault slugs the note references. If absent, infer from body content and recent session context.
- `citations` (optional) — list of `{title, url, accessed}` entries from web-researcher findings. Include whenever the body draws on web sources.
- `parent_slug` (optional) — path prefix hint, e.g. `projects/relocation`. If absent, infer from content and vault structure.

## Process

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

## Style guidance (from `profile.md`)

- **Density over readability** — pack in conclusions and reasoning, not just facts.
- **Self-contained** — key context inline, not only via links.
- **Lead with the conclusion** if there is one.

## Future scope

- Stricter frontmatter validation
- Multi-note splitting for large captures
- Dedup against existing notes before writing
