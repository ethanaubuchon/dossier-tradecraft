#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

mkdir -p "$CLAUDE_DIR/commands" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents"

link() {
  local src="$1"
  local dst="$2"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    echo "ERROR: $dst exists and is not a symlink. Move or remove it first." >&2
    exit 1
  fi
  ln -s "$src" "$dst"
  echo "linked $dst -> $src"
}

shopt -s nullglob

for cmd in "$REPO_DIR"/commands/*.md; do
  link "$cmd" "$CLAUDE_DIR/commands/$(basename "$cmd")"
done

for skill in "$REPO_DIR"/skills/*/; do
  name=$(basename "$skill")
  link "$REPO_DIR/skills/$name" "$CLAUDE_DIR/skills/$name"
done

for agent in "$REPO_DIR"/agents/*.md; do
  link "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")"
done
