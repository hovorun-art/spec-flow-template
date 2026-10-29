#!/bin/bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit|Bash): guards the files the flow relies on.
# - specs/, design.md and tasks.md of a change are blocked until the user has approved its decisions
#   (openspec/changes/<name>/.decisions-approved, which only approve.sh creates).
# - The state files are never written by an agent, only by the hooks: .decisions-approved (approve.sh),
#   .verdict and .verify-running (verifier-hooks.sh), .verify-attempts (verify-change.sh).
# Bash commands are checked by their text: one that names a guarded path and writes (redirect, tee, cp,
# mv, touch, rm, sed -i, an interpreter...) is denied. Reading those files stays allowed.
input=$(cat)
INPUT="$input" python3 - <<'PY'
import json, os, re, sys

d = json.loads(os.environ.get('INPUT') or '{}')
tool = d.get('tool_name', '')
ti = d.get('tool_input') or {}
cwd = d.get('cwd') or os.environ.get('CLAUDE_PROJECT_DIR') or os.getcwd()

STATE = re.compile(r'(^|[/\s\'"])\.(decisions-approved|verdict|verify-attempts|verify-running)\b')
GATED = re.compile(r'((?:[^\s\'"]*/)?)openspec/changes/([^/\s\'"]+)/(specs/|design\.md|tasks\.md)')
WRITES = re.compile(r'>|\b(tee|cp|mv|touch|rm|ln|truncate|dd|install|perl|python3?|node|ruby)\b|\bsed\s+(-[a-zA-Z]*i|--in-place)')


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))
    sys.exit(0)


def approved(prefix, name):
    root = prefix if os.path.isabs(prefix) else os.path.join(cwd, prefix)
    return os.path.isfile(os.path.join(root, 'openspec', 'changes', name, '.decisions-approved'))


def gate_reason(name):
    return (
        f"Blocked: the decisions for change '{name}' are not approved yet, so its specs, design and tasks "
        "may not be written. Instead: 1. Write or update openspec/changes/{0}/decisions.md (Decided = only "
        "what the user said; Assumed = minor defaults you propose, each with a reason; Open questions = "
        "everything else). 2. Ask the open questions with AskUserQuestion (see \"Asking\" in CLAUDE.md) and "
        "record the answers. 3. Have the user approve: they run /spec-flow:specs-go {0}, or pick \"Approve "
        "decisions\" when you offer it. Never create .decisions-approved yourself."
    ).format(name)


STATE_REASON = ("Blocked: this is a state file owned by the spec-flow hooks (.decisions-approved, .verdict, "
                ".verify-attempts, .verify-running). Agents never write, move or delete it.")

if tool == 'Bash':
    cmd = ti.get('command', '')
    if not WRITES.search(cmd):
        sys.exit(0)
    if STATE.search(cmd) and not re.match(r'\s*git\s+(add|status|diff|log|show)\b', cmd):
        deny(STATE_REASON)
    for prefix, name, _ in GATED.findall(cmd):
        if name != 'archive' and not approved(prefix, name):
            deny(gate_reason(name))
    sys.exit(0)

path = ti.get('file_path') or ti.get('notebook_path') or ''
if not path:
    sys.exit(0)
if STATE.search('/' + os.path.basename(path)):
    deny(STATE_REASON)
m = GATED.search(path)
if m and m.group(2) != 'archive' and not approved(m.group(1), m.group(2)):
    deny(gate_reason(m.group(2)))
PY
exit 0
