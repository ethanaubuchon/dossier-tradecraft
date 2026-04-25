---
name: dispatch-exploration
description: Use during /research (or any recipe) to send 1-3 research queries in parallel — vault or web targets — and aggregate compressed findings. Routes each query to vault-researcher or web-researcher based on target.
---

# Dispatch Exploration

Send a small batch of research queries to specialist agents in parallel and return a compressed findings list.

## Input

A list of query objects:

```json
[
  {"question": "what does Ethan want re: relocation healthcare costs?", "target": "vault", "hint": "projects/relocation"},
  {"question": "current state of Spain non-lucrative visa for US remote workers", "target": "web"}
]
```

- `target` — `"vault"` or `"web"`. Required.
- `hint` (vault only) — optional slug-prefix scope to focus the search.

## Process

1. Dispatch one agent per query, **all in parallel** (single message, multiple Agent tool calls):
   - `target: "vault"` → `vault-researcher`
   - `target: "web"` → `web-researcher`
2. Wait for all results.
3. Build a compressed findings list, one line per query:

   **Vault result:**
   ```
   <query> → <slug> — <relevance> — <excerpt>
   ```
   or `<query> → no match` if the agent returned `none`.

   **Web result:**
   ```
   <query> → <summary> — <top 1-2 citations>
   ```
   or `<query> → no useful results` if nothing found.

## Output

The compressed findings list, ready for the recipe to present to the user.

## Constraints

- 1–3 queries per call. If the user wants more breadth, the recipe loops with new batches.
- Always parallel. Never sequential.
- Mix vault and web targets in a single batch when it's useful.

## Future scope

- Codebase exploration via `general-purpose` (`target: "codebase"`) when `/plan` and `/implement` need it.
