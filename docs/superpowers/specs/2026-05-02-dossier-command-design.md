# `/dossier` Command — Design

**Date:** 2026-05-02
**Status:** Approved, ready for implementation plan
**Project:** Personal Claude Workflows — vault note `projects/workflows/overview`

## Problem

When the user issues a single message like "connect to dossier and do X," Claude routinely skips calling `mcp__dossier-mcp__get_vault_context` and proceeds directly to the downstream task. Profile-defined session-start conventions (inbox check, vault structure orientation) don't fire. Current workaround: split into two messages — first "load dossier," then the task. This is friction the user encounters across multiple machines.

## Solution

A thin slash command, `/dossier [task]`, that explicitly orchestrates the profile-load step before processing the user's task. No new behavior introduced — the command's only job is to enforce the ordering Claude is currently skipping.

## Behavior

**`/dossier`** (no arguments):
1. Invoke the existing `load-context` skill.
2. Brief acknowledgment that vault context is loaded; wait for the next user instruction.

**`/dossier <task>`**:
1. Invoke the existing `load-context` skill.
2. Process `$ARGUMENTS` with profile context now in conversation.

In both cases, the inbox nudge from `load-context`'s step 2 fires per `profile.md`'s session-start convention. The command does not add new logic on top of `load-context` — whatever profile.md instructs at session start, the agent follows.

## Architecture

`/dossier` is a Layer 3 recipe in the workflows architecture (per `projects/workflows/design`). It uses the existing Layer 2 primitive `load-context`. No new primitives or agents are introduced.

```
commands/dossier.md  →  invokes  →  skills/load-context/SKILL.md  →  calls  →  mcp__dossier-mcp__*
```

## Files

**New:** `commands/dossier.md` — recipe file with `description:` frontmatter and a short body that calls `load-context` and branches on `$ARGUMENTS`.

**Unchanged:** `install.sh` already symlinks every `commands/*.md`; the new command picks up automatically on next install.

**Unchanged:** `skills/load-context/SKILL.md`, all other skills and agents.

## Scope

**In:** the single new command file. Nothing else.

**Explicitly deferred:**
- A `process-inbox` skill or any auto-processing of inbox notes. If `/dossier` doesn't fully solve the reliability gap (e.g., the agent loads profile but still ignores inbox items), revisit then.
- Any change to existing primitives.
- Hooks-based enforcement. Only consider if the slash-command-level enforcement also fails.

## Success criteria

- `/dossier <task>` reliably triggers `get_vault_context` before any other tool call.
- The user stops needing to split "connect to dossier and do X" into two messages.
- Validate over a week across both machines.

## Risks

- **Slash command body could still be skimmed.** If the agent ignores the recipe's "invoke load-context" instruction the way it currently ignores free-form requests, we'd need a hook. Likelihood low — slash command bodies tend to be honored more rigidly than free-form prompts, but worth confirming during validation.

## Related

- `projects/workflows/design` — parent architecture
- `projects/workflows/overview` — project status
- `meta/inbox-design` — inbox conventions (referenced indirectly via `load-context`)
