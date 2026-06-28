---
name: open-draft-pr
description: Use in /implement after committing, to push the feature branch and open a draft PR, returning the PR ref. Thin and GitHub-specific (gh) behind a host-neutral contract. Transitional — removed under the post-v1 flow simplification. Project-overridable for provisioning-heavy open steps.
---

# Open Draft PR

Opens the **draft** PR that `/implement`'s review step runs inside. Thin: push the branch, create a draft PR, return its ref. The PR is a *draft* (not ready) so review happens before it's "real" — and so `pr-review-toolkit`'s PR-framed agents (when used via the `agent-review` ceiling) have a PR object to attach to.

All GitHub/`gh` coupling lives here and in `publish-pr`; the recipe and the other primitives stay host-agnostic.

## Input

- **branch** — the feature branch (from `repo-setup`), already committed.
- **title**, **body** — composed by the recipe from the `plan-file` / ticket.

## Steps

1. Push the branch and set upstream if it isn't on the remote yet: `git push -u origin <branch>`.
2. **Idempotency** — if a PR already exists for this branch (`gh pr list --head <branch>` returns one), return its ref instead of creating a duplicate (`gh pr create` errors when one exists).
3. Open a draft PR: `gh pr create --draft --title "<title>" --body "<body>"` — base = the repo's default branch, head = the current branch (`gh` infers both; pass `--base`/`--head` explicitly if those defaults don't apply). Add per-repo flags (labels, reviewers) per the project's agent-instruction file.
4. Capture and return the PR ref (number + URL) from the `gh` output.

## Output / contract

- **In:** a committed branch + PR title/body.
- **Out:** the draft PR ref (number/URL), surfaced so `agent-review` and `publish-pr` can target it.
- **Side effects:** pushes the branch (network write); creates a draft PR. Nothing merged or marked ready.

## Project overrides

- **Provisioning-heavy open steps** — a repo with a scripted opener (e.g. domainator's `create-pr.sh`: templated body, labels, linked issues) overrides this, keeping the contract (`branch → PR ref`).

## Future scope

- **Transitional.** Under the post-v1 flow simplification (review the branch directly, no draft PR), this primitive is removed and `publish-pr` absorbs PR *creation*. Keep it thin so its removal is cheap.
