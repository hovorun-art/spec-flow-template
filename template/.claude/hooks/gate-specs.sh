#!/bin/bash
# PreToolUse hook (Write|Edit|MultiEdit): blocks writing specs, design and tasks of an
# OpenSpec change until the user has approved the decisions with /specs-go
# (which creates openspec/changes/<name>/.decisions-approved).
file=$(python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
[ -n "$file" ] || exit 0

if [[ "$file" =~ openspec/changes/([^/]+)/(specs/|design\.md$|tasks\.md$) ]]; then
  name="${BASH_REMATCH[1]}"
  [ "$name" = "archive" ] && exit 0
  root="${file%%/openspec/changes/*}"
  dir="$root/openspec/changes/$name"
  if [ ! -f "$dir/.decisions-approved" ]; then
    {
      echo "Blocked: the decisions for change '$name' are not approved yet."
      echo "Do not write specs, design or tasks. Instead:"
      echo "1. Write or update openspec/changes/$name/decisions.md (Decided = only what the user said; Open questions = everything you would otherwise assume)."
      echo "2. Ask the user the open questions with the AskUserQuestion tool in batches of up to 4 (prepared options plus Other; single or multi select), recording the answers in decisions.md."
      echo "3. Wait for the user to run /specs-go $name. Never create .decisions-approved yourself."
    } >&2
    exit 2
  fi
fi
exit 0
