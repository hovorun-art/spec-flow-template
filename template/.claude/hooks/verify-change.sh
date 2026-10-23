#!/bin/bash
# Stop hook: keeps the main agent working until the change-verifier subagent has
# returned PASS for an OpenSpec change whose tasks are all checked off.
#
# Parallel work: if openspec/changes/<name>/.scope exists (gitignored, written by
# /work-on in a worktree), only tasks under the "## <scope>." heading of tasks.md count.
#
# Verdict lives in openspec/changes/<name>/.verdict (written by the verifier).
# It counts only if it is newer than tasks.md and every project file outside
# openspec/, .claude/, .git/ and IGNORED_DIRS (and .gitignore), so any later edit forces a re-check.
MAX_ROUNDS=3

cat >/dev/null  # stdin is not needed
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
source .claude/flow.conf 2>/dev/null
prune="-path ./openspec -o -path ./.claude -o -path ./.git"
for d in ${IGNORED_DIRS:-}; do prune="$prune -o -path ./$d"; done

for dir in openspec/changes/*/; do
  dir=${dir%/}
  name=$(basename "$dir")
  [ "$name" = "archive" ] && continue
  tasks="$dir/tasks.md"
  verdict="$dir/.verdict"
  attempts="$dir/.verify-attempts"
  [ -f "$tasks" ] || continue
  scope=$(cat "$dir/.scope" 2>/dev/null)
  if [ -n "$scope" ]; then
    body=$(awk -v s="$scope" '/^## /{on=($0 ~ "^## " s "[. ]")} on' "$tasks")
  else
    body=$(cat "$tasks")
  fi
  echo "$body" | grep -q '^[[:space:]]*- \[ \]' && continue    # tasks unfinished
  echo "$body" | grep -qi '^[[:space:]]*- \[x\]' || continue   # nothing done
  [ -n "$scope" ] && scope_note=" (scope: group $scope only)" || scope_note=""

  if [ -f "$verdict" ] && [ "$(head -n1 "$verdict")" = "PASS" ] && [ ! "$tasks" -nt "$verdict" ]; then
    # shellcheck disable=SC2086
    stale=$(find . \( $prune \) -prune -o -type f ! -name .gitignore -newer "$verdict" -print -quit)
    if [ -z "$stale" ]; then
      rm -f "$attempts"
      continue                                            # verified and up to date
    fi
  fi

  # A verifier is running right now (it touches this lock first and removes it last): do not
  # block and do not burn a round. A lock older than 15 minutes is treated as a crashed run.
  lock="$dir/.verify-running"
  if [ -f "$lock" ] && [ -z "$(find "$lock" -mmin +15 2>/dev/null)" ]; then
    printf '{"systemMessage":"change-verifier is still running for %s; waiting for its verdict."}\n' "$name"
    exit 0
  fi

  n=$(cat "$attempts" 2>/dev/null || echo 0)
  if [ "$n" -ge "$MAX_ROUNDS" ]; then
    rm -f "$attempts"
    printf '{"systemMessage":"OpenSpec change %s still not verified after %s rounds; stopping so you can review it."}\n' "$name" "$MAX_ROUNDS"
    exit 0
  fi
  echo $((n + 1)) > "$attempts"

  last=""
  [ -f "$verdict" ] && last=" Previous verdict: $(tr '\n' ' ' < "$verdict")"
  printf '{"decision":"block","reason":"OpenSpec change \\"%s\\" has all tasks checked%s but has no up-to-date PASS verdict (round %s of %s).%s Run the change-verifier subagent on this change%s, in the FOREGROUND (run_in_background false) and wait for its result before you answer. If it does not return PASS, fix every gap it lists in the code, then run change-verifier again. Do not finish until it returns PASS, or explain to the user why a gap cannot be closed."}\n' \
    "$name" "$scope_note" "$((n + 1))" "$MAX_ROUNDS" "$last" "$scope_note"
  exit 0
done
exit 0
