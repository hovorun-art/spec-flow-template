#!/bin/bash
# Copy the project side of the spec-driven flow into a project. The hooks, skills and verifier agent
# come from the spec-flow Claude Code plugin (plugin/), which .claude/settings.json enables.
#   ./install.sh <project-dir> [--force]
# Existing files are kept (listed as "skip") unless --force is given. The .gitignore lines are appended,
# never duplicated. Do not run `openspec init --tools claude`: its stock skills and /opsx commands
# would sit next to the plugin's customised ones and contradict them.
set -euo pipefail
for cmd in git python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: '$cmd' is required (the hooks use it)" >&2; exit 1; }
done
repo="$(cd "$(dirname "$0")" && pwd)"
src="$repo/template"
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

# Files from the copy-everything version (v1) that the plugin now provides; left in place they run twice.
legacy=()
for f in .claude/hooks .claude/commands/opsx .claude/commands/specs-go.md .claude/commands/work-on.md \
         .claude/agents/change-verifier.md .claude/skills/openspec-propose .claude/skills/openspec-explore \
         .claude/skills/openspec-apply-change .claude/skills/openspec-archive-change \
         .claude/skills/openspec-sync-specs .claude/skills/openspec-update-change \
         .claude/skills/roadmap .claude/skills/ui-from-screenshots; do
  [ -e "$dest/$f" ] && legacy+=("$f")
done
if [ ${#legacy[@]} -gt 0 ]; then
  echo
  echo "note: these files from an older install or from 'openspec init' duplicate the plugin; remove them:"
  printf '  %s\n' "${legacy[@]}"
  echo "  and remove the \"hooks\" block from .claude/settings.json if it still points to .claude/hooks/."
fi

[ -d "$dest/.git" ] || echo "note: $dest is not a git repository yet (git init); the git rules and parallel worktrees need one."
command -v openspec >/dev/null 2>&1 || echo "note: install the OpenSpec CLI: npm i -g @fission-ai/openspec"
command -v claude >/dev/null 2>&1 || echo "note: install Claude Code: https://claude.com/claude-code"
echo
echo "Plugin: .claude/settings.json enables spec-flow@spec-flow from GitHub once you trust the folder."
echo "To install it yourself (or from this local checkout while developing it):"
echo "  claude plugin marketplace add hovorun-art/spec-flow-template   # or: $repo"
echo "  claude plugin install spec-flow@spec-flow"
echo
echo "Next: fill the TODOs in CLAUDE.md, openspec/config.yaml, docs/concept.md and .github/workflows/checks.yml,"
echo "set .claude/flow.conf, then ask Claude to run the spec-flow:roadmap skill."
