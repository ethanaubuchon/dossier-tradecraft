---
name: load-context
description: Use at the start of /research and other workflow recipes to establish vault grounding. Loads vault bootstrap (profile.md), checks inbox, and pre-warms project context if a topic anchor is implied. Repo/git detection lands with /plan and /implement.
---

# Load Context

Call this once at the start of a workflow recipe to establish working context. In `/research`, this is the vault grounding pre-step — it loads the context that informs downstream web queries.

## Steps

1. Call `mcp__dossier-mcp__get_vault_context`. This loads `profile.md` silently — do not summarize or recite it.

2. Call `mcp__dossier-mcp__list_notes(path: "inbox")`. If the inbox is non-empty, surface a one-line nudge to the user: `Inbox has N notes — worth processing before we start?`

3. If the user has supplied a research topic with a clear project anchor (e.g. "relocation healthcare costs" → `projects/relocation`), call `mcp__dossier-mcp__list_notes(path: "projects/<slug>")` to pre-warm topic context. Skip if no anchor is obvious — `vault-researcher` will find what it needs.

## Output

No structured return value. Context loads into the conversation. The recipe continues to its next step.

## Future scope (not in Phase 1)

- Repo / vault / mixed environment detection
- `git status` snapshot for the working dir
