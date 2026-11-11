#!/bin/bash
# Tests for guard-main.sh: nothing in a checkout on the main branch is changed (Write/Edit and Bash
# writes are denied), while a change or fix branch, a worktree on another branch, git-ignored files and
# files outside the repo are left alone.
# Run: bash plugin/scripts/tests/guard-main.test.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/guard-main.sh"
failures=0

# A project on branch $1 with flow.conf, an ignored folder and a worktree "wt" on a change branch.
make_project() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.claude" "$dir/src"
  echo "MAIN_BRANCH=main" >"$dir/.claude/flow.conf"
  printf 'node_modules/\n.claude/settings.local.json\n' >"$dir/.gitignore"
  git -C "$dir" init -q -b "$1"
  git -C "$dir" add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m init
  git -C "$dir" worktree add -q -b change-x "$dir/wt" 2>/dev/null
  echo "$dir"
}

# run_case <name> <branch> <tool> <file path or command> <expected decision: deny|none>
run_case() {
  local name="$1" branch="$2" tool="$3" arg="$4" expected="$5"
  local dir actual
  dir=$(make_project "$branch")
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

run_case "edit on the main branch is denied" main Edit '__DIR__/src/app.ts' deny
run_case "writing a new file on the main branch is denied" main Write '__DIR__/src/new/deep.ts' deny
run_case "editing docs on the main branch is denied too" main Write '__DIR__/CLAUDE.md' deny
run_case "edit on a change branch is allowed" change-y Edit '__DIR__/src/app.ts' none
run_case "edit in a worktree on a change branch is allowed" main Edit '__DIR__/wt/src/app.ts' none
run_case "a git-ignored file on the main branch is allowed" main Write '__DIR__/.claude/settings.local.json' none
run_case "a file outside any repo is allowed" main Write '/nonexistent-dir-for-guard-main/x.txt' none
run_case "notebook edit on the main branch is denied" main NotebookEdit '__DIR__/src/a.ipynb' deny
run_case "redirect into the checkout on the main branch is denied" main Bash 'echo x > src/a.ts' deny
run_case "append redirect on the main branch is denied" main Bash 'echo x >>CLAUDE.md' deny
run_case "redirect to /dev/null is allowed" main Bash 'ls src 2>/dev/null' none
run_case "redirect outside the repo is allowed" main Bash 'echo x > /tmp/guard-main-test.txt' none
run_case "tee into the checkout is denied" main Bash 'echo x | tee src/a.ts' deny
run_case "sed -i on the main branch is denied" main Bash "sed -i '' 's/a/b/' src/a.ts" deny
run_case "rm in the checkout is denied" main Bash 'rm -f src/a.ts' deny
run_case "mkdir in the checkout is denied" main Bash 'mkdir -p src/feature' deny
run_case "cp into the checkout is denied" main Bash 'cp /tmp/x src/x.ts' deny
run_case "openspec new change on the main branch is denied" main Bash 'openspec new change add-auth' deny
run_case "git rm on the main branch is denied" main Bash 'git rm src/a.ts' deny
run_case "npm install of a package on the main branch is denied" main Bash 'npm install zod' deny
run_case "plain npm install is allowed" main Bash 'npm install' none
run_case "eslint --fix on the main branch is denied" main Bash 'npx eslint --fix src' deny
run_case "writes in a change worktree after cd are allowed" main Bash 'cd wt && echo x > src/a.ts' none
run_case "writes into a change worktree by path are allowed" main Bash 'echo x > wt/src/a.ts' none
run_case "writes on a change branch are allowed" change-y Bash 'echo x > src/a.ts && rm src/b.ts' none
run_case "read-only commands are allowed" main Bash 'git status && cat src/a.ts | grep x' none
run_case "creating a branch is allowed" main Bash 'git switch -c fix/thing' none
run_case "creating a worktree is allowed" main Bash 'git worktree add -b feat ../feat main' none
run_case "running tests is allowed" main Bash 'npx vitest related --run src/a.ts' none

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
