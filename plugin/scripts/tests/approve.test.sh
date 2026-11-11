#!/bin/bash
# Tests for approve.sh: the approval marker is written only from the user's own action (the typed
# /spec-flow:specs-go command, or the "Approve the brief" option) and only when brief.md has nothing
# unchecked left.
# Run: bash plugin/scripts/tests/approve.test.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/approve.sh"
failures=0

# A project with change "demo" (brief ready), "draft" (an item to confirm) and "old" (decisions.md only).
make_project() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/openspec/changes/demo" "$dir/openspec/changes/draft" "$dir/openspec/changes/old"
  printf '## Product\nGoal: x\n## To confirm\n' >"$dir/openspec/changes/demo/brief.md"
  printf '## To confirm\n- [ ] which limit?\n' >"$dir/openspec/changes/draft/brief.md"
  echo "- [x] decided" >"$dir/openspec/changes/old/decisions.md"
  echo "$dir"
}

# run_case <name> <mode: --prompt|--answer> <hook input as JSON> <change> <expected: approved|not>
run_case() {
  local name="$1" mode="$2" input="$3" change="$4" expected="$5"
  local dir actual=not
  dir=$(make_project)
  printf '%s' "$input" | CLAUDE_PROJECT_DIR="$dir" bash "$HOOK" "$mode" >/dev/null
  [ -f "$dir/openspec/changes/$change/.decisions-approved" ] && actual=approved
  if [ "$actual" = "$expected" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected '$expected', got '$actual'"
    failures=$((failures + 1))
  fi
  rm -rf "$dir"
}

answer() { # answer <question> <picked label>
  python3 -c 'import json,sys; q,a=sys.argv[1:3]; print(json.dumps({"tool_input":{"questions":[{"question":q}]},"tool_response":{"answers":{q:a}}}))' "$1" "$2"
}

run_case "typed command approves a ready brief" --prompt '{"prompt":"/spec-flow:specs-go demo"}' demo approved
run_case "typed command does not approve a brief with items to confirm" --prompt '{"prompt":"/spec-flow:specs-go draft"}' draft not
run_case "typed command approves a change of the older schema" --prompt '{"prompt":"/specs-go old"}' old approved
run_case "a prompt that only mentions the command approves nothing" --prompt '{"prompt":"please run /spec-flow:specs-go demo"}' demo not
run_case "picking Approve the brief approves the named change" --answer "$(answer 'Approve the brief of `demo`?' 'Approve the brief')" demo approved
run_case "the older label still approves" --answer "$(answer 'Approve the decisions of `demo`?' 'Approve decisions')" demo approved
run_case "picking Not yet approves nothing" --answer "$(answer 'Approve the brief of `demo`?' 'Not yet')" demo not
run_case "approval for a question that names no change is ignored" --answer "$(answer 'Approve the brief?' 'Approve the brief')" demo not
run_case "the option does not approve a brief with items to confirm" --answer "$(answer 'Approve the brief of `draft`?' 'Approve the brief')" draft not

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
