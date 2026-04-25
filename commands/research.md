---
description: Conversation-shaped research loop — vault grounding + web research + agent-judged capture (no pre-write sign-off)
---

You are starting a research session. The topic (if provided): $ARGUMENTS

This is the `/research` recipe (Phase 1 v2) of the personal workflows framework. See [[projects/workflows/design]] in the vault for the full design; v1 history in [[projects/workflows/research-v1-friction]].

## Principles

- **Vault = grounding**, not a research target. The vault sweep enriches context for the web step; it is not presented alongside web findings as a parallel source.
- **Web = primary research target**, always runs. Model priors can't be trusted for fast-moving or landscape topics.
- **Frame step is near-zero.** Topic-as-stated passes through. Clarifications are conditional, not mandatory.
- **Capture is agent-judged; write directly.** You pick the slug, draft the note with citations, and write it. Surface what was captured afterward — the user can redirect, revise, or ask you to move/edit the note post-hoc. Anchor is a capture-time output, not a frame-time input.
- **Loop iteration is context-accretive.** Each turn builds on previous turn's captures.

## Workflow

1. **Load context** — invoke the `load-context` skill (vault grounding pre-step).

2. **Intake.** If `$ARGUMENTS` is empty, ask what the user wants to research. Otherwise acknowledge the topic briefly and proceed. Do not interrogate scope, anchor, or biases up front.

3. **Pre-vault clarify (conditional).** Skip unless the topic is *genuinely ambiguous*. Fire only when:
   - A term has multiple common meanings and the right one isn't obvious from context
   - The user mentions known candidates without specifying skim-worthy vs. deep-dive
   - Scope is truly unclear (landscape scan vs. narrow comparison vs. how-to-build)

   Default: skip. When in doubt, don't ask.

4. **Vault grounding.** Invoke `dispatch-exploration` with 1–3 vault queries (`target: vault`) scoped to what's likely to enrich the web step — the user's rig, prior thinking, related projects. Present the compressed findings briefly; frame them as *context for the web search*, not the research output.

5. **Post-vault clarify (conditional).** Fire only when grounding reveals a fork that changes the research direction:
   - Vault surfaced strong prior art that may or may not be the starting point
   - Scope overlap with another active project
   - A direction the user couldn't see before the sweep

   If grounding was clean and convergent: skip.

6. **Loop:**

   a. **Web research.** Invoke `dispatch-exploration` with 1–3 web queries (`target: web`) informed by grounding and any discussion so far.

   b. **Present findings.** Summarize what came back, with citations inline.

   c. **Discuss.** Always interactive and conversational. Talk through what matters, what's surprising, what to dig into. No decision matrices.

   d. **Capture.** Invoke `capture-to-vault`. Draft the note — destination slug, frontmatter, body, citations — and write it directly. Surface the slug and any non-obvious placement decisions afterward; the user can redirect or revise post-hoc.

   e. **Loop check.** Ask the user: go deeper (refine topic, feed more context), pivot to a related thread that builds on what we've learned, or exit?
      - Deeper / pivot → back to (a). Optionally re-run step 4 (grounding) if the new thread pulls in vault areas we haven't touched.
      - Exit → proceed to step 7.

7. **Exit.** Brief close-out: list what was captured (slugs + one-line each). No further writes.

## Interaction style

- Steps 3 and 5 default to **skip**. Only ask when there's genuine ambiguity; don't manufacture questions to fill the slot.
- Step 6c (discuss) is always conversational. Don't present user-decision matrices.
- Step 6d (capture) writes directly — no pre-write sign-off. Surface the slug and placement decisions after the write so the user can redirect or revise post-hoc.
- Don't front-load frame decisions. Anchor, exact scope, and topic framing are emergent outputs of the loop.
