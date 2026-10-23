#!/bin/bash
# Merge the finished agent branches into the main branch, in order, then run the checks.
#   scripts/agents/merge-all.sh [--dry-run]
# Refuses to start if the main branch has uncommitted changes or if a branch is dirty, unfinished or not archived.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

dry=""
[ "${1:-}" = "--dry-run" ] && dry=1
root="$(main_root)"
cd "$root"
changes="$(agent_changes)"   # read once, before any merge moves the change folders
[ -n "$changes" ] || { echo "Nothing to merge." >&2; exit 1; }

[ "$(git branch --show-current)" = "$MAIN_BRANCH" ] || { echo "run this on $MAIN_BRANCH" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "$MAIN_BRANCH has uncommitted changes" >&2; exit 1; }

for change in $changes; do
  dir="$(worktree_dir "$root" "$change")"
  [ -d "$dir" ] || { echo "missing worktree for $change" >&2; exit 1; }
  [ -z "$(git -C "$dir" status --porcelain)" ] || { echo "$change has uncommitted changes" >&2; exit 1; }
  ls "$dir"/openspec/changes/archive/*-"$change" >/dev/null 2>&1 || { echo "$change is not archived yet" >&2; exit 1; }
  [ "$(git rev-list --count "$MAIN_BRANCH".."$change")" != "0" ] || { echo "$change has no commits to merge" >&2; exit 1; }
done

for change in $changes; do
  echo "== merging $change"
  if [ -n "$dry" ]; then echo "[dry-run] git merge --no-ff $change"; continue; fi
  git merge --no-ff -m "merge $change" "$change" || { echo "Conflict while merging $change. Resolve it, commit, then run this script again." >&2; exit 1; }
done

[ -n "$dry" ] && exit 0
echo "== checks"
[ -z "${INSTALL_CMD:-}" ] || bash -c "$INSTALL_CMD"
[ -z "${MERGE_CHECK_CMD:-}" ] || bash -c "$MERGE_CHECK_CMD"
echo "All merged and green. Worktrees can be removed with: git worktree remove ../$(basename "$root")-<change>"
