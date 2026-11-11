#!/bin/bash
# Tests for approve.sh: the approval marker is written only from the user's own action (the typed
# /spec-flow:specs-go command, or the "Approve the brief" option) and only when brief.md has nothing
# unchecked left.
# Run: bash plugin/scripts/tests/approve.test.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/approve.sh"
failures=0

# A project with change "demo" (brief ready), "draft" (an item to confirm) and "logonly" (a decision log
# and no brief).
make_project() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/openspec/changes/demo" "$dir/openspec/changes/draft" "$dir/openspec/changes/logonly"
  printf '## Product\nGoal: x\n## To confirm\n' >"$dir/openspec/changes/demo/brief.md"
  printf '## To confirm\n- [ ] which limit?\n' >"$dir/openspec/changes/draft/brief.md"
  echo "- 2026-01-01 x - why: y; by: user" >"$dir/openspec/changes/logonly/decisions.md"
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
run_case "a decision log without a brief is never approved" --prompt '{"prompt":"/spec-flow:specs-go logonly"}' logonly not
run_case "a prompt that only mentions the command approves nothing" --prompt '{"prompt":"please run /spec-flow:specs-go demo"}' demo not
run_case "picking Approve the brief approves the named change" --answer "$(answer 'Approve the brief of `demo`?' 'Approve the brief')" demo approved
run_case "another approve label approves nothing" --answer "$(answer 'Approve the decisions of `demo`?' 'Approve decisions')" demo not
run_case "picking Not yet approves nothing" --answer "$(answer 'Approve the brief of `demo`?' 'Not yet')" demo not
run_case "approval for a question that names no change is ignored" --answer "$(answer 'Approve the brief?' 'Approve the brief')" demo not
run_case "the option does not approve a brief with items to confirm" --answer "$(answer 'Approve the brief of `draft`?' 'Approve the brief')" draft not

run_case "a translated label approves nothing" --answer "$(answer 'Затвердити бриф demo?' 'Затвердити бриф')" demo not # allow-non-english

# edited_case <name> <file the tool wrote> <setup: keep|change> <expected: approved|not>: an approved brief
# that is edited loses its marker.
edited_case() {
  local name="$1" file="$2" setup="$3" expected="$4" dir actual=not
  dir=$(make_project)
  printf '%s' '{"prompt":"/spec-flow:specs-go demo"}' | CLAUDE_PROJECT_DIR="$dir" bash "$HOOK" --prompt >/dev/null
  [ "$setup" = change ] && echo "- one more thing" >>"$dir/openspec/changes/demo/brief.md"
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1]},"cwd":sys.argv[2]}))' \
    "$dir/$file" "$dir" | CLAUDE_PROJECT_DIR="$dir" bash "$HOOK" --edited >/dev/null
  [ -f "$dir/openspec/changes/demo/.decisions-approved" ] && actual=approved
  if [ "$actual" = "$expected" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected '$expected', got '$actual'"
    failures=$((failures + 1))
  fi
  rm -rf "$dir"
}
edited_case "an edit that changes the approved brief removes the approval" openspec/changes/demo/brief.md change not
edited_case "a write that leaves the brief as approved keeps the approval" openspec/changes/demo/brief.md keep approved
edited_case "an edit of another file keeps the approval" openspec/changes/demo/decisions.md change approved

# note_case <name> <question> <picked label> <expected: note|silent>: whether the agent is told to ask again.
note_case() {
  local name="$1" expected="$4" dir actual=silent
  dir=$(make_project)
  answer "$2" "$3" | CLAUDE_PROJECT_DIR="$dir" bash "$HOOK" --answer | grep -q 'ask it again' && actual=note
  if [ "$actual" = "$expected" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected '$expected', got '$actual'"
    failures=$((failures + 1))
  fi
  rm -rf "$dir"
}
note_case "a translated label on a ready brief tells the agent to ask again" 'Затвердити бриф demo?' 'Затвердити бриф' note # allow-non-english
note_case "a question about a brief with items to confirm stays silent" 'Which limit for draft?' '10' silent

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
