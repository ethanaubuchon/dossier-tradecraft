---
name: dispatch-exploration
description: Use during /research (or any recipe) to send 1-3 research queries in parallel — vault or web targets — and aggregate compressed findings. Routes each query to vault-researcher or web-researcher based on target. Hosts the cross-verify consent gate so any inline-research caller (/research, /design, /decompose) inherits source-bias mitigation without duplicating logic.
---

# Dispatch Exploration

Send a small batch of research queries to specialist agents in parallel, apply the cross-verify consent gate when a returned finding triggers it, and return a compressed findings list.

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

The input shape is **stable** — callers do not need to opt into the cross-verify gate; it is always on for `target: "web"` results.

## Process

1. **Dispatch** one agent per query, **all in parallel** (single message, multiple Agent tool calls):
   - `target: "vault"` → `vault-researcher`
   - `target: "web"` → `web-researcher`
2. **Wait** for all results.
3. **Cross-verify intercept** for each `web` result. See [Cross-verify orchestration](#cross-verify-orchestration) below. This is the only step where this skill may pause for user interaction; vault results are pass-through.
4. **Build a compressed findings list**, one line (or short block) per query:

   **Vault result:**
   ```
   <query> → <slug> — <relevance> — <excerpt>
   ```
   or `<query> → no match` if the agent returned `none`.

   **Web result (default):**
   ```
   <query> → <summary> — <top 1-2 citations> — cohort: <cohort_spread> — flags: <flag list>
   ```
   Pass through `cohort_spread` and `flags` when present. Omit the `cohort:` / `flags:` segments when the agent returned no flags and a single-cohort spread (e.g. an evergreen-fact lookup with a clean sample).

   **Web result (pricing mode, single tier):**
   ```
   <query> → new: median $Y, range $A–$B (N reputable sources) — flags: <flags>
   ```

   **Web result (pricing mode, tiered after consent):**
   ```
   <query>
     new:  median $Y, range $A–$B (N sources, manufacturer-direct + major-retailer)
     used: median $Z, range $C–$D (M sources, marketplace-used / refurbished / etc.)
     flags: <flags>
   ```

   **Web result (no useful data):** `<query> → no useful results`.

## Web-researcher findings shape

`web-researcher` returns a YAML-shaped finding. Default fields:

```
query: <original query>
summary: <2–5 sentences>
cohort_spread: "<count>× <cohort>, <count>× <cohort>, ... — <gap notes if any>"
flags: [<flag>, <flag>, ...]
citations:
  - {title: "...", url: "...", accessed: YYYY-MM-DD, type_tags: [<cohort>, <pricing-subtype-if-any>]}
```

In pricing mode, `summary` may be replaced by tiered `new:` and `used:` blocks (see Process step 4).

The `cohort_spread` string is human-readable, not structured — pass it through verbatim. `flags` is a list of short tokens (see [Flag vocabulary](#flag-vocabulary)). Each citation carries `type_tags` — preserve them when surfacing citations to the user.

If the agent returns `summary: none` (no useful sources), no flags or cohort information will be present; render as `no useful results`.

## Flag vocabulary

The `flags` field uses a fixed vocabulary. Recipes treat these as machine-readable signals and surface them in finding presentation.

- `single-source` — only one usable source for the central claim or price; the finding is uncorroborated. For pricing this is framed as `single-source — could not corroborate`.
- `cohort-gap: <slot>` — one entry per unfilled cohort (e.g. `cohort-gap: critical-adversarial`). Means the agent ran a targeted query for that slot and still came up empty. Visible gap is the deliverable; do not interpret as agent failure.
- `pricing-mode` — pricing mode is active. Always present for pricing queries; downstream rendering keys off this.
- `marketplace-listings-detected` — the candidate set contained `marketplace-used` / `auction` / `refurbished` / `private-listing` sources while the reputable sample (`manufacturer-direct` + `major-retailer`) was thin (<3). Triggers the consent gate (see below) unless intent was explicit.
- `cohort-homogeneity: <pattern>` — multiple sources within a cohort share suspicious traits (near-identical phrasing, citation cycles to the same primary, all on `recent-domain`s). Surface with the finding so the user can discount accordingly; no consent gate.

## Cross-verify orchestration

The cross-verify consent gate lives in this skill so any caller doing inline research — `/research`, `/design`'s research step, future `/decompose` info-gap fills — inherits the gate without duplicating logic. Recipes call `dispatch-exploration` and never see the consent prompt machinery directly.

Apply this orchestration once per `web` result, between the agent return and the build-findings step.

### Used / marketplace consent gate

**Trigger conditions** (both must be true):

1. `marketplace-listings-detected` flag is present in the finding, OR the finding's citations include any `type_tags` from `{marketplace-used, auction, refurbished, private-listing}`.
2. The reputable sample size is thin: count of citations whose `type_tags` include `manufacturer-direct` or `major-retailer` is `< 3`.

**Intent-recognition bypass:** before surfacing the consent prompt, check the **original question text** for any of these keywords (case-insensitive, simple substring match — no NLU):

- `used`
- `refurbished`
- `secondhand` / `second-hand` / `second hand`
- `marketplace`
- `eBay` / `Craigslist` / `Facebook Marketplace`
- `auction`
- `open box` / `open-box`

If any keyword is present, **skip the consent prompt** — the user has already declared intent. Re-dispatch `web-researcher` with the original question (the agent's own intent recognition will trigger pricing-with-used mode and return the tiered output) **only if** the current finding does not already contain a tiered output. If the finding is already tiered, pass it through.

**Consent prompt** (when intent bypass does not apply):

> I see used / refurbished / marketplace listings for **<topic>** in the search results, and the reputable-retailer sample is thin (only **N** sources). Include used / marketplace pricing in the sample, or stick to new-from-reputable-retailer? Current new-retail sample: **median $Y across N sources**.

Where `<topic>`, `N`, and `$Y` are filled from the finding. If the new-retail sample is empty, omit the "Current new-retail sample" sentence.

**On user response:**

- **"Stick to new" / decline / silence** → pass the existing single-tier finding through. Append a `consent-declined-marketplace` flag so downstream presentation can note the gate fired and was declined.
- **"Include used" / "yes" / explicit consent** → re-dispatch `web-researcher` with a refined question: original question + ` — include marketplace and used listings in the sample`. Use the tiered output from the re-dispatch in the build-findings step.

**Never silently widen.** If the trigger fires and consent is neither given nor declined (e.g. the user redirects entirely), do not include marketplace listings in the sample.

### Low retail sample escalation

Distinct from the marketplace gate. Fires when there is no `marketplace-listings-detected` flag (the candidate set was already retail-only) but the reputable sample is still thin.

**Trigger:**

- `pricing-mode` flag is present
- Count of `manufacturer-direct` + `major-retailer` citations is `< 3`
- `marketplace-listings-detected` is absent

**When N == 1:** do not offer widening. Surface as:

> Only one usable retail source found for **<topic>** — `single-source — could not corroborate`. Treat the price as uncorroborated.

Pass through the finding with the existing `single-source` flag; no user action required (pure surfacing).

**When N == 2:** offer widening explicitly:

> Only **2** reputable-retailer sources found for **<topic>**. Widen the search to include marketplace-new sources (third-party sellers on Amazon / eBay / Newegg), or report as-is with a `low-sample` flag?

- **Widen** → re-dispatch `web-researcher` with `<original> — widen to marketplace-new sources`. Use the new finding.
- **Report as-is** → pass through with an added `low-sample` flag.

This escalation never silently widens either — symmetry with the marketplace gate is intentional.

### Calling-convention semantics

Input shape is unchanged: `{question, target, hint?}`. Callers don't pass a consent flag.

Return semantics now allow a mid-call user interaction window during the cross-verify intercept step. Callers should treat `dispatch-exploration` as potentially blocking on user input for `web` queries in pricing mode. In practice this only fires when one of the trigger conditions above is met; non-pricing web queries and pricing queries with healthy reputable samples return without any user-facing prompt.

## Output

The compressed findings list, ready for the recipe to present to the user. The list reflects any consent decisions made during the cross-verify intercept step.

## Constraints

- 1–3 queries per call. If the user wants more breadth, the recipe loops with new batches.
- Always parallel for the initial dispatch. Never sequential.
- Mix vault and web targets in a single batch when it's useful.
- Cross-verify orchestration applies to `web` results only. `vault` results are pass-through (single-author, injection risk negligible — no cohort discipline meaningful).
- Pass `cohort_spread`, `flags`, and citation `type_tags` through verbatim. Don't summarize them away — they're the visible deliverable of the cross-verify work.

## Future scope

- Codebase exploration via `general-purpose` (`target: "codebase"`) when `/plan` and `/implement` need it.
- Non-US major-retailer allowlist for international callers (currently a project-skill override of `agents/web-researcher.md`).
