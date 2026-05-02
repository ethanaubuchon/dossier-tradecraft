# `/dossier` Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a thin `/dossier [task]` slash command that forces `load-context` to run before processing the user's request, eliminating the failure mode where multi-part prompts cause Claude to skip profile-load.

**Architecture:** A single new file at `commands/dossier.md`. The recipe body invokes the existing `load-context` skill, then branches on `$ARGUMENTS` (empty → wait for instruction; non-empty → process task). No new skills or agents. The existing `install.sh` symlinks `commands/*.md` already, so install picks up the new command on next run.

**Tech Stack:** Markdown (slash command file) + the existing claude-workflows symlink installer + the existing `load-context` skill + `mcp__dossier-mcp__*` MCP tools. No code beyond the recipe markdown itself.

**Note on testing:** This is a markdown recipe file with no programmatic surface — there is no automated test framework that exercises slash command bodies. Validation is manual: invoke the command in a fresh Claude Code session and observe tool-call ordering. The plan reflects this honestly rather than fabricating a test harness.

---

## File Structure

**New:**
- `commands/dossier.md` — the slash command recipe. Frontmatter has `description:` only. Body explains the workflow and branches on `$ARGUMENTS`.

**Unchanged:**
- `install.sh` — already loops over `commands/*.md` and symlinks each into `~/.claude/commands/`. No edits needed.
- `skills/load-context/SKILL.md` — invoked by the recipe; left alone.

---

### Task 1: Create the `/dossier` command file

**Files:**
- Create: `commands/dossier.md`

- [ ] **Step 1: Write `commands/dossier.md`**

Create the file with the following exact contents:

````markdown
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
````

- [ ] **Step 2: Verify the file is well-formed**

Run:
```bash
head -1 commands/dossier.md
```
Expected: `---` (frontmatter delimiter)

Run:
```bash
grep -c '^description:' commands/dossier.md
```
Expected: `1`

- [ ] **Step 3: Commit the new file**

```bash
git add commands/dossier.md
git commit -m "$(cat <<'EOF'
Add /dossier slash command

Thin recipe that forces invocation of the load-context skill before
processing the user's request. Solves the recurring failure mode where
multi-part prompts ("connect to dossier and do X") cause Claude to skip
the profile-load step. No new skills or agents — uses existing
load-context.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Install the command via the existing installer

**Files:**
- No file changes; runs `install.sh`.

- [ ] **Step 1: Run the installer**

Run from the repo root:
```bash
./install.sh
```
Expected output includes a line like:
```
linked /home/ethan/.claude/commands/dossier.md -> /home/ethan/workspace/claude-workflows/commands/dossier.md
```

If the line does not appear, inspect `install.sh` and check the loop at lines 24–26 — it globs `commands/*.md`. The new file should match.

- [ ] **Step 2: Verify the symlink exists**

Run:
```bash
ls -la ~/.claude/commands/dossier.md
```
Expected: a symlink pointing to `/home/ethan/workspace/claude-workflows/commands/dossier.md`.

Run:
```bash
readlink ~/.claude/commands/dossier.md
```
Expected: `/home/ethan/workspace/claude-workflows/commands/dossier.md`

- [ ] **Step 3: Confirm Claude Code can resolve the slash command**

In a fresh terminal Claude Code session, type `/` and verify `/dossier` appears in the slash command list with the description "Force load of Dossier vault profile...". This is a sanity check that the file is discovered.

(No commit step here — `install.sh` only writes outside the repo.)

---

### Task 3: Manual validation — bare invocation

**Files:** none.

This task verifies the no-arguments path: `/dossier` alone should load profile, surface inbox state, and stop.

- [ ] **Step 1: Open a fresh Claude Code session**

A fresh session ensures `profile.md` has not already been loaded by prior conversation context.

- [ ] **Step 2: Invoke `/dossier` with no arguments**

Type:
```
/dossier
```

Expected behavior:
- The first tool call is `mcp__dossier-mcp__get_vault_context`.
- The second tool call is `mcp__dossier-mcp__list_notes` with `path: "inbox"`.
- If the inbox is empty, the agent's text response acknowledges context is loaded (e.g., "Dossier vault loaded, inbox empty. What would you like to do?") and stops.
- If the inbox is non-empty, the agent surfaces the one-line nudge per `profile.md`'s convention.

- [ ] **Step 3: Record outcome**

If the expected ordering happens, mark this task complete. If `get_vault_context` is NOT the first tool call, the recipe is being skimmed — see "Risks" in the spec; escalation path is hooks-based enforcement, but document the failure first.

---

### Task 4: Manual validation — invocation with arguments

**Files:** none.

This task verifies the with-arguments path: `/dossier <task>` should load profile *first*, then process the task.

- [ ] **Step 1: Open a fresh Claude Code session**

Again, fresh session to ensure no prior context.

- [ ] **Step 2: Invoke `/dossier` with a vault-touching task**

Type:
```
/dossier list my active projects
```

Expected behavior:
- The first tool call is `mcp__dossier-mcp__get_vault_context`.
- The second tool call is `mcp__dossier-mcp__list_notes` with `path: "inbox"`.
- Only after those, the agent searches/lists for active projects (e.g., `list_notes` on `projects/`, or `search_notes` for active project tags).
- If the inbox is non-empty, the agent surfaces the nudge inline as it proceeds with the task — does not block on it unless the user confirms processing first.

- [ ] **Step 3: Record outcome**

If `get_vault_context` and the inbox check happen before the task-specific searches, mark complete. If they don't, see Task 3 Step 3.

---

### Task 5: Update vault project status (optional, non-blocking)

**Files:**
- Modify: vault note `projects/workflows/overview` (via `mcp__dossier-mcp__update_note`).

This task notes the new command in the workflows project overview. Optional — skip if the operator prefers to batch vault note updates separately.

- [ ] **Step 1: Read the current overview note**

Run (in Claude Code, not the shell):
```
mcp__dossier-mcp__get_note(slug: "projects/workflows/overview")
```

- [ ] **Step 2: Add a `/dossier` line under "Phase 1 v1 — what shipped" (or a new "Auxiliary commands" section)**

Add a bullet noting that `/dossier` ships as a thin enforcement command for profile-load ordering. Keep it one line. Do not edit unrelated sections.

- [ ] **Step 3: Save via `update_note`**

Use `mcp__dossier-mcp__update_note` with the modified body. Confirm the diff is minimal (only the new line).

(No git commit step — vault changes are tracked by dossier-mcp, not this repo.)

---

## Self-Review

**Spec coverage check:**
- Spec "Problem" → addressed by the recipe's existence (Task 1) ✓
- Spec "Solution" → Task 1 creates the recipe ✓
- Spec "Behavior — no args" → Task 3 validates ✓
- Spec "Behavior — with args" → Task 4 validates ✓
- Spec "Architecture" (Layer 3 recipe using existing Layer 2 primitive) → Task 1 recipe body invokes `load-context` ✓
- Spec "Files — Unchanged install.sh" → Task 2 confirms via existing install ✓
- Spec "Files — Unchanged load-context" → no task touches it ✓
- Spec "Scope deferred items" → no task introduces them ✓
- Spec "Success criteria — load triggers first" → Tasks 3 & 4 verify ✓
- Spec "Risks — slash body could be skimmed" → Tasks 3 & 4 Step 3 documents the failure path ✓

No gaps.

**Placeholder scan:** No "TBD," "TODO," or "implement later" in the plan. All code blocks contain real content. Commands are exact.

**Type consistency:** No types defined; the only identifiers used are real MCP tool names (`mcp__dossier-mcp__get_vault_context`, `mcp__dossier-mcp__list_notes`) and existing skill/file references (`load-context`, `install.sh`, `commands/dossier.md`), all consistent across tasks.

---

## Execution notes

- Tasks 1, 2 are deterministic and fast (~5 minutes total).
- Tasks 3, 4 require fresh Claude Code sessions and are the gating validation. They can be run side-by-side in two terminals if desired.
- Task 5 is optional housekeeping; skip if you prefer to batch vault updates.
- The full implementation has one commit (Task 1 Step 3). Tasks 2–5 do not touch the repo.
