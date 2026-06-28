---
name: agent-review
description: Use in /implement after committing, inside the draft PR, to review the committed diff. Dispatches a dependency-free review subagent fed the diff + review criteria and returns structured findings (severity / location / problem / fix). The recipe drives the address→re-review loop with a human exit gate; the pr-review-toolkit ceiling is an opt-in override of this skill.
---

# Agent Review

The review step of `/implement`'s repo path. Runs on **committed** work (never unstaged changes), inside the draft PR. Dispatches a review subagent — fed the diff plus review criteria — and returns **structured findings** for the recipe to act on.

Dependency-free by default: a fresh install gets working review with nothing beyond dossier-mcp. The richer `pr-review-toolkit` specialist panel is an opt-in **override** of this skill (see Project overrides), not a built-in — so `/implement` never *requires* the toolkit.

## Input

- **diff** — the committed change to review, as a ref range (default `origin/main...HEAD`) or a PR number.
- **criteria** (optional) — focus areas; defaults below.
- **context** (optional) — the `plan-file` path and the ticket / acceptance criteria, passed to the reviewer so it can check the change against intent.

## Default review criteria (the floor)

- **Correctness** — does the code do what it claims; do its own commands/claims hold up when checked; logic errors, edge cases, off-by-ones.
- **AC coverage** — does the change actually satisfy the ticket's acceptance criteria.
- **Silent failures / error handling** — swallowed errors, missing guards, fallback that hides real failures.
- **Internal consistency** — self-contradiction; drift from the change's own stated contract.
- **Convention consistency** — does it match sibling code/patterns in the repo.

A project override can replace or extend these. If the AC / plan context isn't provided, the reviewer flags its absence as a gap rather than silently skipping the AC-coverage and intent checks.

## Process

1. Resolve the diff — `git diff <range>` for a ref range, or `gh pr diff <number>` for a PR number — plus the list of changed files and the context (`plan-file` path + AC) if available.
2. **Dispatch a review subagent restricted to read-only tools** (no Edit/Write/NotebookEdit — e.g. a read-only agent type), so the no-side-effects contract is *structurally* enforced, not just instructed. Instruct it to:
   - read the diff and the changed files in full;
   - check against the criteria and the AC / plan context;
   - **be skeptical and concrete — verify claims, don't praise**; where a claim is checkable (a command, a path, an invariant), check it rather than trust it;
   - return findings in the structured format below, plus a one-line verdict.
3. **Return the findings to the recipe.** Do **not** loop or apply fixes here — the recipe owns the address→re-review loop and the human ready-to-publish gate (a primitive can't host an interactive gate).

## Output / contract

- **In:** a committed diff (+ optional criteria / context).
- **Out:** a list of findings, each `{ severity: blocker | major | minor | nit, location, problem (1 sentence), suggested fix (1 sentence) }`, plus a one-line verdict (mergeable as-is / mergeable with minor fixes / needs changes before merge). If a severity level has no findings, say so.
- **Side effects:** none — read-only review that dispatches a subagent. No commits, no file edits, no PR state changes.

## Project overrides (the ceiling)

The toolkit ceiling is an override, not a default (per the dependency posture):

- **User-level** override (`~/.claude/skills/agent-review/`) — dispatch `pr-review-toolkit`'s panel (`code-reviewer`, `silent-failure-hunter`, `type-design-analyzer`, `comment-analyzer`, `pr-test-analyzer`) and aggregate their output into the same structured-findings format. The user with the toolkit installed gets the rich review everywhere; a fresh user isn't forced into the dependency.
- **Project-level** override — swap a stack-specific reviewer (e.g. a TypeScript- or Ansible-aware agent) or tune the criteria for the repo.

Overrides must honor the contract — input a diff, output structured findings, and stay read-only / side-effect-free — so the recipe's review loop keeps working unchanged.

## Future scope

- **`workflow-reviewer`** — a thin bundled reviewer agent tuned to a terse, critical, why-not-what style, replacing the general-purpose subagent as the floor. This is the self-sufficiency direction: the floor becomes good enough that the toolkit ceiling is rarely needed.
