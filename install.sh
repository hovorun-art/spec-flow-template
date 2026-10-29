#!/bin/bash
# Copy the spec-driven flow into a project.
#   ./install.sh <project-dir> [--force]
# Existing files are kept (listed as "skip") unless --force is given. The .gitignore lines are appended,
# never duplicated. Run `openspec init` yourself only if you want to refresh the stock OpenSpec skills:
# the copies here carry the decisions/AskUserQuestion customisations.
set -euo pipefail
for cmd in git python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: '$cmd' is required (the hooks use it)" >&2; exit 1; }
done
src="$(cd "$(dirname "$0")/template" && pwd)"
dest="${1:-}"
force=""
[ "${2:-}" = "--force" ] && force=1
[ -n "$dest" ] || { echo "usage: $0 <project-dir> [--force]" >&2; exit 2; }
mkdir -p "$dest"
dest="$(cd "$dest" && pwd)"

cd "$src"
find . -type f ! -name gitignore.flow | sort | while read -r f; do
  f="${f#./}"
  if [ -e "$dest/$f" ] && [ -z "$force" ]; then
    echo "skip  $f"
    continue
  fi
  mkdir -p "$dest/$(dirname "$f")"
  cp -p "$f" "$dest/$f"
  echo "copy  $f"
done

touch "$dest/.gitignore"
while IFS= read -r line; do
  grep -qxF "$line" "$dest/.gitignore" || echo "$line" >> "$dest/.gitignore"
done < gitignore.flow
echo "updated .gitignore"

[ -d "$dest/.git" ] || echo "note: $dest is not a git repository yet (git init); the git rules and parallel worktrees need one."
command -v openspec >/dev/null 2>&1 || echo "note: install the OpenSpec CLI: npm i -g @fission-ai/openspec"
command -v claude >/dev/null 2>&1 || echo "note: install Claude Code: https://claude.com/claude-code"
echo
echo "Next: fill the TODOs in CLAUDE.md, openspec/config.yaml, docs/concept.md and .github/workflows/checks.yml,"
echo "set .claude/flow.conf, then ask Claude to run the roadmap skill."
