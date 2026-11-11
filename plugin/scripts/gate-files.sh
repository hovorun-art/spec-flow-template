#!/bin/bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit|Bash): guards the files the flow relies on.
# - specs/, tasks.md (and design.md, where a change has one) are blocked until the user has approved its
#   brief (openspec/changes/<name>/.decisions-approved, which only approve.sh creates). The marker holds
#   the sha256 of brief.md at approval, so any later edit of brief.md needs a new approval. A change of
#   the older schema has decisions.md in the brief's place.
# - The state files are never written by an agent, only by the hooks: .decisions-approved (approve.sh)
#   and .verdict (verifier-hooks.sh).
# - No agent writes an agent definition named change-verifier (.claude/agents/): the verdict hook would
#   record its PASS as the verifier's.
# - `openspec archive <name>` runs only after the verifier's PASS on the current commit: .verdict starts
#   with PASS, its `commit:` is HEAD, and nothing outside openspec/ is uncommitted.
# Bash commands are checked by their text: one that names a guarded path and writes (redirect, tee, cp,
# mv, touch, rm, sed -i, an interpreter...) is denied, also when a `cd` earlier in the command makes the
# path relative (`cd openspec/changes/<name> && echo x > tasks.md`). Reading those files stays allowed. Literal commit
# messages (-m '...', -m "..." without $ or a backtick, "$(cat <<'EOF' ... EOF)") are not part of that
# text: a message may name a guarded file and hold a ">" (the Co-Authored-By trailer).
input=$(cat)
INPUT="$input" python3 - <<'PY'
import hashlib, json, os, re, subprocess, sys

d = json.loads(os.environ.get('INPUT') or '{}')
tool = d.get('tool_name', '')
ti = d.get('tool_input') or {}
cwd = d.get('cwd') or os.environ.get('CLAUDE_PROJECT_DIR') or os.getcwd()

STATE = re.compile(r'(^|[/\s\'"])\.(decisions-approved|verdict)\b')
VERIFIER_AGENT = re.compile(r'\.claude/agents/[^/\s\'"]*change-verifier[^/\s\'"]*\.md\b')
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
    folder = os.path.join(root, 'openspec', 'changes', name)
    try:
        marker = open(os.path.join(folder, '.decisions-approved'), encoding='utf-8').read()
    except OSError:
        return False
    m = re.search(r'^sha256: ([0-9a-f]{64})$', marker, re.M)
    if not m:
        return True  # marker written before approvals recorded a hash
    for doc in ('brief.md', 'decisions.md'):
        try:
            return hashlib.sha256(open(os.path.join(folder, doc), 'rb').read()).hexdigest() == m.group(1)
        except OSError:
            continue
    return False


def gate_reason(name):
    return (
        f"Blocked: the brief of change '{name}' is not approved, or brief.md changed after the "
        "user approved it, so its specs and tasks may not be written. "
    ) + (
        "Instead: 1. Write or update openspec/changes/{0}/brief.md (Product and Technical hold only "
        "what the user said or confirmed; everything else is an item under \"To confirm\"). 2. Resolve "
        "those items with AskUserQuestion (see \"Asking\" in CLAUDE.md), write the answers into the brief "
        "and the reason into decisions.md. 3. Have the user approve: they run /spec-flow:specs-go {0}, or "
        "pick \"Approve the brief\" when you offer it. Never create .decisions-approved yourself."
    ).format(name)


STATE_REASON = ("Blocked: this is a state file owned by the spec-flow hooks (.decisions-approved, .verdict). "
                "Agents never write, move or delete it.")
AGENT_REASON = ("Blocked: the change-verifier agent comes from the spec-flow plugin. A project agent of that "
                "name would have its verdict recorded as the verifier's, so agents never write one.")
GATED_WORD = re.compile(r'[^\s\'"<>|;&()]*(?:specs/[^\s\'"<>|;&()]*|design\.md|tasks\.md)')


def after_cd(cmd):
    """The guarded paths this command names relative to a directory it changed into, made absolute."""
    base, found = cwd, []
    for m in re.finditer(r'(?:^|[;&|\n(])\s*cd\s+("[^"]*"|\'[^\']*\'|[^\s;&|)]+)', cmd):
        base = os.path.normpath(os.path.join(base, os.path.expanduser(m.group(1).strip('\'"'))))
        found.append(base + '/')  # inside specs/ every write counts
        for word in GATED_WORD.findall(cmd):
            if not os.path.isabs(word):
                found.append(os.path.normpath(os.path.join(base, word)) + ('/' if word.endswith('/') else ''))
    return found

def without_messages(cmd):
    """The command without the literal text of commit messages, which runs nothing and writes nothing."""
    cmd = re.sub(r'"?\$\(\s*cat\s+<<-?\s*([\'"])(\w+)\1[ \t]*\n.*?\n[ \t]*\2[ \t]*\n?\s*\)"?', ' MESSAGE ', cmd, flags=re.S)
    cmd = re.sub(r"(?<=\s)(-[a-zA-Z]*m|--message)(=|\s+)'[^']*'", r'\1 MESSAGE', cmd)
    return re.sub(r'(?<=\s)(-[a-zA-Z]*m|--message)(=|\s+)"(?:[^"\\$`]|\\[^$`])*"', r'\1 MESSAGE', cmd)


def archive_block(cmd):
    """Why archiving a change in this command (`openspec archive <name>`, or the archive skill's
    `mv openspec/changes/<name> openspec/changes/archive/...`) may not run yet, or None."""
    name = root = None
    m = re.search(r'(?:^|[;&|\n(]|\s)openspec\s+archive\b([^;&|\n]*)', cmd)
    if m:
        words = [w.strip('\'"') for w in m.group(1).split() if not w.startswith('-')]
        if words:
            name = words[0]
            root = next((r for r in (cwd, os.environ.get('CLAUDE_PROJECT_DIR') or '')
                         if r and os.path.isdir(os.path.join(r, 'openspec', 'changes', name))), None)
    for m in re.finditer(r'(?:^|[;&|\n(]|\s)mv\b([^;&|\n]*)', cmd):
        words = [w.strip('\'"') for w in m.group(1).split() if not w.startswith('-')]
        if len(words) < 2 or not re.search(r'(^|/)openspec/changes/archive(/|$)', words[-1]):
            continue
        for w in words[:-1]:
            src = re.match(r'^((?:.*/)?)openspec/changes/([^/]+)/?$', w)
            if src and src.group(2) != 'archive':
                prefix, name = src.group(1), src.group(2)
                root = os.path.normpath(prefix if os.path.isabs(prefix) else os.path.join(cwd, prefix))
                if not os.path.isdir(os.path.join(root, 'openspec', 'changes', name)):
                    root = None
    if not name or not root:
        return None  # nothing is archived here, or no such change: the command reports it
    how = (f" Run step 3 of \"Checks\" in CLAUDE.md and the spec-flow:change-verifier subagent on '{name}' "
           "until it returns PASS on the current commit, then archive.")
    try:
        lines = open(os.path.join(root, 'openspec', 'changes', name, '.verdict'), encoding='utf-8').read().splitlines()
    except OSError:
        return f"Blocked: change '{name}' has no verifier verdict yet, so it may not be archived." + how
    if not lines or lines[0].strip() != 'PASS':
        return f"Blocked: the last verifier verdict for '{name}' is {lines[0].strip() if lines else 'empty'}, not PASS." + how

    def git(*args):
        try:
            out = subprocess.run(['git', '-C', root, *args], capture_output=True, text=True, timeout=5)
        except Exception:
            return None
        return out.stdout if out.returncode == 0 else None

    head = (git('rev-parse', 'HEAD') or '').strip()
    commit = next((l.split(':', 1)[1].strip() for l in lines[1:] if l.startswith('commit:')), '')
    if head and commit and head != commit:
        return (f"Blocked: the verifier's PASS for '{name}' was given on commit {commit[:10]}, but HEAD is "
                f"{head[:10]}: the code changed after it." + how)
    dirty = [l[3:] for l in (git('status', '--porcelain') or '').splitlines()
             if not l[3:].strip('"').startswith('openspec/')]
    if head and dirty:
        return (f"Blocked: uncommitted changes outside openspec/ ({', '.join(dirty[:5])}) were not part of the "
                f"verified commit." + how)
    return None


if tool == 'Bash':
    cmd = without_messages(ti.get('command', ''))
    reason = archive_block(cmd)
    if reason:
        deny(reason)
    # Redirects that write nothing (2>/dev/null, 2>&1) are not writes.
    if not WRITES.search(re.sub(r'\d*>>?\s*/dev/null\b|\d*>&\d*-?', ' ', cmd)):
        sys.exit(0)
    if STATE.search(cmd) and not re.match(r'\s*git\s+(add|status|diff|log|show)\b', cmd):
        deny(STATE_REASON)
    if VERIFIER_AGENT.search(cmd):
        deny(AGENT_REASON)
    for prefix, name, _ in GATED.findall(cmd) + [g for p in after_cd(cmd) for g in GATED.findall(p)]:
        if name != 'archive' and not approved(prefix, name):
            deny(gate_reason(name))
    sys.exit(0)

path = ti.get('file_path') or ti.get('notebook_path') or ''
if not path:
    sys.exit(0)
if STATE.search('/' + os.path.basename(path)):
    deny(STATE_REASON)
if VERIFIER_AGENT.search(path):
    deny(AGENT_REASON)
m = GATED.search(path)
if m and m.group(2) != 'archive' and not approved(m.group(1), m.group(2)):
    deny(gate_reason(m.group(2)))
PY
exit 0
