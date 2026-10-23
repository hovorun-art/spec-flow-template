#!/bin/bash
# One-screen status of the parallel agents: branch position, task progress, verdict, uncommitted files.
#   scripts/agents/status.sh
set -uo pipefail
source "$(dirname "$0")/lib.sh"

root="$(main_root)"
printf "%-14s %-8s %-9s %-9s %-10s %-6s %s\n" CHANGE WORKTREE TASKS VERDICT BRANCH DIRTY AGENT
changes="$(agent_changes)"
[ -n "$changes" ] || { echo "No active, approved changes on $MAIN_BRANCH (everything is merged or nothing is planned)."; exit 0; }
for change in $changes; do
  dir="$(worktree_dir "$root" "$change")"
  if [ ! -d "$dir" ]; then
    printf "%-14s %-8s\n" "$change" "missing"
    continue
  fi
  tasks="$dir/openspec/changes/$change/tasks.md"
  where="active"
  if [ ! -f "$tasks" ]; then
    tasks="$(ls "$dir"/openspec/changes/archive/*-"$change"/tasks.md 2>/dev/null | head -1)"
    where="archived"
  fi
  if [ -n "${tasks:-}" ] && [ -f "$tasks" ]; then
    done_n="$(grep -ciE '^[[:space:]]*- \[x\]' "$tasks")"
    open_n="$(grep -cE '^[[:space:]]*- \[ \]' "$tasks")"
    progress="$done_n/$((done_n + open_n))"
  else
    progress="-"
  fi
  verdict="-"
  vf="$dir/openspec/changes/$change/.verdict"
  [ -f "$vf" ] && verdict="$(head -n1 "$vf")"
  [ "$where" = "archived" ] && verdict="archived"
  ahead="$(git -C "$dir" rev-list --count "$MAIN_BRANCH"..HEAD)"
  behind="$(git -C "$dir" rev-list --count HEAD.."$MAIN_BRANCH")"
  dirty="$(git -C "$dir" status --porcelain | grep -v '\.agent\.lock' | wc -l | tr -d ' ')"
  agent="-"
  lock="$dir/.agent.lock"
  [ -f "$lock" ] && kill -0 "$(cat "$lock")" 2>/dev/null && agent="running"
  printf "%-14s %-8s %-9s %-9s %-10s %-6s %s\n" "$change" "ok" "$progress" "$verdict" "+$ahead/-$behind" "$dirty" "$agent"
done
echo
echo "BRANCH is commits ahead (+) and behind (-) $MAIN_BRANCH. Ready to merge when TASKS is full, VERDICT is archived and DIRTY is 0."
