#!/bin/bash
# Prepare the git worktree of one change and start a Claude agent in it.
#   scripts/agents/start-agent.sh <change> [--dry-run]
# Environment:
#   CLAUDE_FLAGS  extra flags for `claude`, for example "--permission-mode acceptEdits" (empty by default)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

change="${1:-}"
dry=""
[ "${2:-}" = "--dry-run" ] && dry=1
[ -n "$change" ] || { echo "usage: $0 <change> [--dry-run]" >&2; exit 2; }

root="$(main_root)"
dir="$(worktree_dir "$root" "$change")"
[ -d "$root/openspec/changes/$change" ] || { echo "No such change on $MAIN_BRANCH: openspec/changes/$change" >&2; exit 1; }

run() { if [ -n "$dry" ]; then echo "[dry-run] $*"; else "$@"; fi; }

echo "== $change"
echo "worktree: $dir"

# 1. Create the worktree (and branch) if needed, otherwise bring it up to date with the main branch.
if [ ! -d "$dir" ]; then
  if git -C "$root" show-ref --verify --quiet "refs/heads/$change"; then
    run git -C "$root" worktree add "$dir" "$change"
  else
    run git -C "$root" worktree add -b "$change" "$dir"
  fi
else
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "worktree has uncommitted changes: not touching it"
  elif [ "$(git -C "$dir" rev-list --count HEAD.."$MAIN_BRANCH")" != "0" ]; then
    run git -C "$dir" merge --ff-only "$MAIN_BRANCH" || echo "could not fast-forward to $MAIN_BRANCH (the branch has its own commits): leaving it"
  else
    echo "already up to date with $MAIN_BRANCH"
  fi
fi

# 2. Dependencies (a fresh worktree has none).
if [ -n "${INSTALL_CMD:-}" ] && { [ -z "${DEPS_DIR:-}" ] || [ ! -d "$dir/$DEPS_DIR" ]; }; then
  echo "installing dependencies"
  if [ -n "$dry" ]; then echo "[dry-run] (cd $dir && $INSTALL_CMD)"; else (cd "$dir" && bash -c "$INSTALL_CMD"); fi
fi

# 3. Start the agent on its own change.
prompt="/opsx:apply $change"
if ! command -v claude >/dev/null 2>&1; then
  echo "The 'claude' command is not in PATH."
  echo "Open $dir in VS Code, start Claude Code there and run: $prompt"
  exit 1
fi
# One agent per worktree: a lock file holds the pid of the running session.
lock="$dir/.agent.lock"
if [ -f "$lock" ] && kill -0 "$(cat "$lock")" 2>/dev/null; then
  echo "An agent is already running in $dir (pid $(cat "$lock")). Not starting a second one." >&2
  exit 1
fi

# Uncommitted changes usually mean an agent (maybe started by hand) is already working here.
dirty=0
[ -d "$dir" ] && dirty="$(git -C "$dir" status --porcelain | grep -v '\.agent\.lock' | wc -l | tr -d ' ')"
if [ "$dirty" != "0" ] && [ -z "$dry" ]; then
  echo "$dir has $dirty uncommitted file(s): an agent may already be working there."
  if [ -t 0 ]; then
    read -r -p "Start another session anyway? [y/N] " answer
    [ "$answer" = "y" ] || [ "$answer" = "Y" ] || { echo "not started"; exit 1; }
  else
    echo "Not starting (no terminal to ask)." >&2
    exit 1
  fi
fi

echo "starting: claude ${CLAUDE_FLAGS:-} \"$prompt\""
[ -n "$dry" ] && exit 0
cd "$dir"
echo $$ > "$lock"
trap 'rm -f "$lock"' EXIT
# shellcheck disable=SC2086
claude ${CLAUDE_FLAGS:-} "$prompt"
