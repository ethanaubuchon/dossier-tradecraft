# dossier-tradecraft

Slash commands and skills for [Claude Code](https://claude.ai/code) that extend [dossier-mcp](https://github.com/ethanaubuchon/dossier-mcp) with opinionated workflows for research, design, project scoping, and vault context loading.

These workflows are an explicit add-on to dossier-mcp — they assume a Dossier-style vault and call dossier-mcp's tools throughout. Without that setup, nothing here works as a standalone tool.

## Prerequisites

- [Claude Code](https://claude.ai/code)
- [`dossier-mcp`](https://github.com/ethanaubuchon/dossier-mcp), installed and registered as an MCP server
- A vault following Dossier conventions:
  - `profile.md` at the vault root (the bootstrap document — see [dossier-mcp's README](https://github.com/ethanaubuchon/dossier-mcp#profilemd) for what goes in it)
  - An `inbox/` directory
  - Project areas under `projects/<project-slug>/`

## Install

```bash
git clone git@github.com:ethanaubuchon/dossier-tradecraft.git ~/workspace/dossier-tradecraft
cd ~/workspace/dossier-tradecraft
./install.sh
```

The installer symlinks `commands/`, `skills/`, and `agents/` into `~/.claude/`. Edits to the clone propagate immediately — no rebuild step. Set `CLAUDE_DIR` to override the default `~/.claude`.

## Commands shipped

| Command | What it does |
|---|---|
| `/research [topic]` | Conversation-shaped research loop. Vault grounding → web research → agent-judged capture into the vault with citations. |
| `/design [topic]` | Early-stage design exploration. Conversation-shaped dialog over a single living design note; required `## Approach` section; re-entrant for refinement. Sits between `/research` and `/scope`. |
| `/scope [topic]` | Project-level scoping. Refines a single living scope doc per project; re-entrant; required `## Unknowns` section. Loads upstream design doc (if any exists) for context. |
| `/decompose [topic]` | Feature/story breakdown. Consumes a `ready-for-decompose` scope doc and produces a task graph in the project's issue tracker (GitHub via `gh`, with vault fallback). Tracker is canonical; scope doc gets a `## Tracked at` breadcrumb. |
| `/dossier [task]` | Thin auxiliary command that forces vault profile loading before any other action. Solves the failure mode where multi-part prompts cause Claude to skip profile-load. |

Each command's full behavior is documented in the corresponding file under `commands/`.

The phase recipes (`/design`, `/scope`, `/decompose`, and the planned `/implement`) share a cross-recipe **kickback** convention: downstream work that surfaces an upstream concern (or an information gap) prompts the agent to ask whether to context-switch back. Phases aren't strictly one-way. `/decompose` further refines this — research is handled inline rather than as a kickback, since research produces information rather than owned decisions.

## Roadmap

Planned but not shipped — see the [Issues tab](https://github.com/ethanaubuchon/dossier-tradecraft/issues) for state and discussion:

- **`/implement`** — feature implementation in a repo or vault. Wraps repo lifecycle (branch, worktree, PR) and review automation.
- **Plugin packaging** — repackage as a proper Claude Code plugin once the workflows have weeks of real use.

## License

[MIT](LICENSE).
