#!/bin/bash
# Tests for gate-files.sh: specs and tasks are blocked until the brief is approved (and again
# after brief.md changes), state files are never written by an agent, a commit message may name them,
# and `openspec archive` needs the verifier's PASS on the current commit.
# Run: bash plugin/scripts/tests/gate-files.test.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/gate-files.sh"
failures=0

# A project on a change branch with change "demo" (brief approved), "draft" (not approved) and "old"
# (older schema: decisions.md approved).
make_project() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/openspec/changes/demo" "$dir/openspec/changes/draft" "$dir/openspec/changes/old" "$dir/src"
  echo "Goal: x" >"$dir/openspec/changes/demo/brief.md"
  echo "- [ ] open" >"$dir/openspec/changes/draft/brief.md"
  echo "- [x] decided" >"$dir/openspec/changes/old/decisions.md"
  local c
  for c in demo/brief.md old/decisions.md; do
    printf 'approved: now\nsha256: %s\n' "$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$dir/openspec/changes/$c")" \
      >"$dir/openspec/changes/${c%%/*}/.decisions-approved"
  done
  printf 'openspec/changes/**/.verdict\n' >"$dir/.gitignore"
  echo "x" >"$dir/src/a.ts"
  git -C "$dir" init -q -b demo
  git -C "$dir" add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m init
  echo "$dir"
}

# verdict <dir> <word> [commit]: what the verifier hook would have recorded (HEAD by default).
verdict() {
  printf '%s\ncommit: %s\n' "$2" "${3:-$(git -C "$1" rev-parse HEAD)}" >"$1/openspec/changes/demo/.verdict"
}

# run_case <name> <tool> <file path or command> <expected: deny|none> [setup function]
run_case() {
  local name="$1" tool="$2" arg="$3" expected="$4" setup="${5:-}"
  local dir actual
  dir=$(make_project)
  [ -n "$setup" ] && "$setup" "$dir"
  arg="${arg//__DIR__/$dir}"
  actual=$(python3 -c '
import json, sys
tool, arg, cwd = sys.argv[1:4]
ti = {"command": arg} if tool == "Bash" else {"file_path": arg}
print(json.dumps({"tool_name": tool, "tool_input": ti, "cwd": cwd}))' "$tool" "$arg" "$dir" \
    | CLAUDE_PROJECT_DIR="$dir" bash "$HOOK" \
    | python3 -c 'import json,sys; s=sys.stdin.read(); print(json.loads(s)["hookSpecificOutput"]["permissionDecision"] if s.strip() else "none")')
  if [ "$actual" = "$expected" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected '$expected', got '$actual'"
    failures=$((failures + 1))
  fi
  rm -rf "$dir"
}

pass_here() { verdict "$1" PASS; }
partial_here() { verdict "$1" PARTIAL; }
pass_on_older_commit() { verdict "$1" PASS 0000000000000000000000000000000000000000; }
pass_then_dirty_code() { verdict "$1" PASS; echo "y" >"$1/src/a.ts"; }
pass_then_synced_specs() { verdict "$1" PASS; mkdir -p "$1/openspec/specs/x"; echo "s" >"$1/openspec/specs/x/spec.md"; }
brief_edited() { echo "- one more thing" >>"$1/openspec/changes/demo/brief.md"; }
log_appended() { echo "- 2026-01-01 x - why: y; by: user" >>"$1/openspec/changes/demo/decisions.md"; }

run_case "tasks of an approved change may be written" Edit '__DIR__/openspec/changes/demo/tasks.md' none
run_case "tasks of an unapproved change are blocked" Write '__DIR__/openspec/changes/draft/tasks.md' deny
run_case "specs are blocked again after brief.md changed" Write '__DIR__/openspec/changes/demo/specs/a/spec.md' deny brief_edited
run_case "appending to the decision log keeps the approval" Write '__DIR__/openspec/changes/demo/specs/a/spec.md' none log_appended
run_case "the brief itself may be written" Edit '__DIR__/openspec/changes/draft/brief.md' none
run_case "the decision log may be written before approval" Edit '__DIR__/openspec/changes/draft/decisions.md' none
run_case "a change of the older schema is approved by its decisions.md" Edit '__DIR__/openspec/changes/old/tasks.md' none
run_case "the approval marker is never written by an agent" Write '__DIR__/openspec/changes/draft/.decisions-approved' deny
run_case "the verdict is never written through Bash" Bash 'echo PASS > openspec/changes/demo/.verdict' deny
run_case "reading the verdict is allowed" Bash 'cat openspec/changes/demo/.verdict' none
run_case "a redirect into unapproved specs is blocked" Bash 'echo x > openspec/changes/draft/specs/a.md' deny
run_case "a relative write after cd into an unapproved change is blocked" Bash 'cd openspec/changes/draft && echo x > tasks.md' deny
run_case "a relative write after cd into the changes folder is blocked" Bash 'cd openspec/changes; echo x > draft/specs/a.md' deny
run_case "a write after cd into unapproved specs is blocked" Bash 'cd openspec/changes/draft/specs && echo x > a.md' deny
run_case "a relative write after cd into an approved change is allowed" Bash 'cd openspec/changes/demo && echo x > tasks.md' none
run_case "a write elsewhere after cd is left alone" Bash 'cd src && echo x > specs/a.ts' none
run_case "a project agent named change-verifier is never written" Write '__DIR__/.claude/agents/change-verifier.md' deny
run_case "a project agent named change-verifier is never written through Bash" Bash 'cp x.md .claude/agents/change-verifier.md' deny
run_case "another project agent may be written" Write '__DIR__/.claude/agents/helper.md' none

run_case "a commit message naming a state file is allowed" Bash "git commit -m 'chore: ignore .verdict

Co-Authored-By: A <a@b.c>'" none
run_case "a heredoc commit message naming gated files is allowed" Bash $'git add -A && git commit -m "$(cat <<\'EOF\'\ndocs: openspec/changes/draft/tasks.md and .verdict\n\nCo-Authored-By: A <a@b.c>\nEOF\n)"' none
run_case "a double-quoted message naming a state file is allowed" Bash 'git commit -m "chore: the .verdict file -> ignored"' none
run_case "a message that runs a command is still checked" Bash 'git commit -m "$(echo PASS > openspec/changes/demo/.verdict)"' deny
run_case "a write after the commit message is still checked" Bash "git commit -m 'x' && echo PASS > openspec/changes/demo/.verdict" deny

run_case "archive without a verdict is blocked" Bash 'openspec archive demo' deny
run_case "archive after PARTIAL is blocked" Bash 'openspec archive demo -y' deny partial_here
run_case "archive after PASS on the current commit is allowed" Bash 'openspec archive "demo" -y' none pass_here
run_case "archive after PASS on an older commit is blocked" Bash 'openspec archive demo' deny pass_on_older_commit
run_case "archive with uncommitted code after PASS is blocked" Bash 'openspec archive demo' deny pass_then_dirty_code
run_case "archive with synced main specs uncommitted is allowed" Bash 'openspec archive demo' none pass_then_synced_specs
run_case "moving a change into the archive without a verdict is blocked" Bash 'mkdir -p openspec/changes/archive && mv "openspec/changes/demo" "openspec/changes/archive/2026-01-01-demo"' deny
run_case "moving a change into the archive by absolute path is blocked" Bash 'mv __DIR__/openspec/changes/demo __DIR__/openspec/changes/archive/2026-01-01-demo' deny partial_here
run_case "moving a change into the archive after PASS is allowed" Bash 'mv "openspec/changes/demo" "openspec/changes/archive/2026-01-01-demo"' none pass_here
run_case "moving a source file is left alone" Bash 'mv src/a.ts src/b.ts' none
run_case "archive of an unknown change is left to the CLI" Bash 'openspec archive nope' none
run_case "openspec status is left alone" Bash 'openspec status --change demo --json' none

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
