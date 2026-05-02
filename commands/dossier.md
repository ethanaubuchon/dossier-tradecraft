---
description: Force load of Dossier vault profile (and inbox check) before processing the rest of the user's request
---

You are starting a session that needs Dossier vault context. The user's task (if any): $ARGUMENTS

This is the `/dossier` recipe — a thin enforcement command. Its only job is to ensure the profile-load step runs before any other action. See `projects/workflows/design` in the vault for the broader workflow architecture.

## Workflow

1. **Load context.** Invoke the `load-context` skill. This loads `profile.md` via `mcp__dossier-mcp__get_vault_context` and runs the profile's session-start conventions (e.g., inbox nudge if non-empty).

2. **Branch on `$ARGUMENTS`:**
   - **Empty:** Briefly acknowledge that vault context is loaded. Wait for the user's next instruction.
   - **Non-empty:** Process the task with profile context now in scope. Honor any session-start conventions surfaced by `load-context` (e.g., if the inbox nudge fires, mention it inline as you proceed).

## Why this exists

Multi-part prompts like "connect to dossier and do X" routinely cause the profile-load step to be skipped — the agent jumps to the task and never calls `get_vault_context`. This recipe forces the order: load first, act second.
