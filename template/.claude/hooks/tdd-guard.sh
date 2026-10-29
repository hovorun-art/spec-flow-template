#!/bin/bash
# PreToolUse hook (Write|Edit|MultiEdit): strict test first. Blocks editing source files (SRC_PATTERN)
# until a test file (TEST_PATTERN) has changed on the current branch, committed or not, compared with
# MAIN_BRANCH. Off unless TDD_STRICT=1 in .claude/flow.conf.
file=$(python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
[ -n "$file" ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
source .claude/flow.conf 2>/dev/null || exit 0
[ "${TDD_STRICT:-0}" = "1" ] || exit 0

file=${file#"$PWD"/}
[[ "$file" =~ ${SRC_PATTERN} ]] || exit 0
[[ "$file" =~ ${TEST_PATTERN} ]] && exit 0

changed=$( { git diff --name-only "${MAIN_BRANCH:-main}...HEAD" 2>/dev/null; git status --porcelain -uall | cut -c4-; } )
echo "$changed" | grep -qE "${TEST_PATTERN}" && exit 0

{
  echo "Blocked: test first (TDD_STRICT=1 in .claude/flow.conf)."
  echo "No test file has changed on this branch yet, so $file may not be edited."
  echo "Write the test for the scenario first, run it and see it fail, then implement."
} >&2
exit 2
