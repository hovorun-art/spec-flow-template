#!/bin/bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit|Bash): no file of the project is changed while its
# checkout is on the main branch (MAIN_BRANCH in flow.conf). Every change, fix or instruction update starts
# on its own branch (or worktree); the main branch only receives merges.
# - Write/Edit/MultiEdit/NotebookEdit: denied when the file's git checkout is on the main branch, unless the
#   file is git-ignored (local settings, build output). Files outside any git repo are not checked.
# - Bash: denied on the main branch when the command visibly writes into the checkout: a redirect or tee into
#   it, sed -i / perl -i, cp/mv/rm/touch/mkdir/ln/truncate on its paths, `openspec new|archive|init`,
#   `git mv|rm|apply|am|stash pop|stash apply`, npm/pnpm/yarn add or remove of a package, and --fix/--write
#   runs (eslint, prettier). Scripts that write files on their own cannot be seen; CLAUDE.md covers them.
MAIN_BRANCH=main
# shellcheck disable=SC1091
[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/flow.conf" ] && source "${CLAUDE_PROJECT_DIR:-.}/.claude/flow.conf"
export MAIN_BRANCH
# Fails closed: if the check itself breaks (python3 missing, an unexpected input), the call is denied
# instead of passing unchecked.
failed() {
  printf '%s\n' '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "Blocked: the spec-flow guard-main hook could not run its check (see the hook error output), so the call is denied instead of passing unchecked. Tell the user."}}'
}
input=$(cat)
INPUT="$input" python3 - <<'PY' || failed
import json, os, re, shlex, subprocess, sys

d = json.loads(os.environ.get('INPUT') or '{}')
tool = d.get('tool_name', '')
ti = d.get('tool_input') or {}
cwd = d.get('cwd') or os.environ.get('CLAUDE_PROJECT_DIR') or os.getcwd()
main = os.environ.get('MAIN_BRANCH', 'main')


def git(directory, *args):
    try:
        out = subprocess.run(['git', '-C', directory, *args], capture_output=True, text=True, timeout=5)
    except Exception:
        return None, 1
    return out.stdout.strip(), out.returncode


def existing_dir(path):
    p = path if os.path.isdir(path) else os.path.dirname(path)
    while p and not os.path.isdir(p):
        parent = os.path.dirname(p)
        if parent == p:
            return None
        p = parent
    return p or None


def on_main(path):
    """The checkout holding `path` is on the main branch and `path` is tracked or trackable there."""
    directory = existing_dir(path)
    if not directory:
        return False
    top, rc = git(directory, 'rev-parse', '--show-toplevel')
    if rc != 0 or not top:
        return False
    real = os.path.realpath(path)
    if real == os.path.join(os.path.realpath(top), '.git') or real.startswith(os.path.join(os.path.realpath(top), '.git') + os.sep):
        return False
    branch, rc = git(top, 'symbolic-ref', '--short', '-q', 'HEAD')
    if rc != 0 or branch != main:
        return False
    _, ignored = git(top, 'check-ignore', '-q', '--', real)
    return ignored != 0


def deny(what):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": (
            f"Blocked: {what} is on the main branch ({main}). Nothing is changed on the main branch, not even "
            "docs or instructions; it only receives merges. Start the work on its own branch first (the "
            "spec-flow:start skill): a fix or an instruction update gets `git switch -c fix/<name>`, a change "
            "with new behaviour gets its own worktree and branch."),
    }}))
    sys.exit(0)


if tool != 'Bash':
    path = ti.get('file_path') or ti.get('notebook_path') or ''
    if path:
        if not os.path.isabs(path):
            path = os.path.join(cwd, path)
        if on_main(path):
            deny(os.path.relpath(path, cwd) if path.startswith(cwd) else path)
    sys.exit(0)

cmd = ti.get('command', '')


def split_lines(s):
    out, q, i = [], None, 0
    while i < len(s):
        c = s[i]
        if c == '\\' and q != "'" and i + 1 < len(s):
            out.append(s[i:i + 2]); i += 2; continue
        if q:
            if c == q: q = None
        elif c in '\'"':
            q = c
        elif c == '\n':
            c = ' ; '
        out.append(c); i += 1
    return ''.join(out)


try:
    lex = shlex.shlex(split_lines(cmd), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    tokens = list(lex)
except ValueError:
    # Unparseable (heredoc bodies, unbalanced quotes): judge by text against the cwd's checkout.
    if re.search(r'(^|[^0-9&>])>>?\s*[^&\s/]|\bsed\s+-[a-zA-Z]*i|\btee\b|\bopenspec\s+(new|archive|init)\b', cmd) \
            and on_main(os.path.join(cwd, '.')):
        deny('this command writes into a checkout that')
    sys.exit(0)

SEPARATORS = {'&&', '||', ';', '|', '&', '(', ')', ';;', '|&'}
REDIRECTS = {'>', '>>', '>|', '&>', '&>>'}
segments, cur = [], []
for t in tokens:
    if t in SEPARATORS:
        if cur: segments.append(cur)
        cur = []
    else:
        cur.append(t)
if cur: segments.append(cur)


def resolve(base, p):
    p = os.path.expanduser(p)
    return os.path.normpath(p if os.path.isabs(p) else os.path.join(base, p))


def check(base, p, what=None):
    if not p or p.startswith('$') or p.startswith('/dev/'):
        return
    full = resolve(base, p)
    if on_main(full):
        deny(what or (p + ' (written by this command)'))


for seg in segments:
    # Redirect targets anywhere in the segment.
    args = []
    i = 0
    while i < len(seg):
        t = seg[i]
        if t in REDIRECTS | {'>&', '<', '<<', '<<<', '<&'} and args and args[-1].isdigit():
            args.pop()  # the fd number of 2>file
        if t in REDIRECTS and i + 1 < len(seg):
            check(cwd, seg[i + 1]); i += 2; continue
        if t in ('>&', '<', '<<', '<<<', '<&') and i + 1 < len(seg):
            i += 2; continue
        args.append(t); i += 1
    # Skip leading env assignments and wrappers.
    while args and (re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', args[0]) or args[0] in ('command', 'env', 'time', 'sudo')):
        args = args[1:]
    if not args:
        continue
    prog, rest = os.path.basename(args[0]), args[1:]
    plain = [a for a in rest if not a.startswith('-')]
    flags = [a for a in rest if a.startswith('-')]
    if prog == 'cd':
        cwd = resolve(cwd, plain[0] if plain else os.path.expanduser('~'))
        continue
    here = os.path.join(cwd, '.')
    if prog == 'tee':
        for p in plain: check(cwd, p)
    elif prog in ('cp', 'ln', 'install'):
        if plain: check(cwd, plain[-1])
    elif prog in ('mv', 'rm', 'touch', 'mkdir', 'rmdir', 'truncate', 'unlink'):
        for p in plain: check(cwd, p)
    elif prog in ('sed', 'perl') and any(re.match(r'^-[a-zA-Z]*i', f) or f.startswith('--in-place') for f in flags):
        for p in plain[1:] if prog == 'sed' else plain: check(cwd, p)
    elif prog == 'openspec' and plain[:1] in (['new'], ['archive'], ['init']):
        if on_main(here): deny('`openspec ' + plain[0] + '` writes into a checkout that')
    elif prog == 'git':
        j, gdir = 0, cwd
        while j < len(rest) and rest[j].startswith('-'):
            if rest[j] == '-C' and j + 1 < len(rest):
                gdir = resolve(gdir, rest[j + 1]); j += 2; continue
            j += 2 if rest[j] in ('-c', '--git-dir', '--work-tree') else 1
        sub = rest[j:j + 2]
        if sub[:1] in (['mv'], ['rm'], ['apply'], ['am']) or sub in (['stash', 'pop'], ['stash', 'apply']):
            if on_main(os.path.join(gdir, '.')): deny('`git ' + ' '.join(sub) + '` changes files in a checkout that')
    elif prog in ('npm', 'pnpm', 'yarn', 'bun') and plain[:1] and plain[0] in ('add', 'remove', 'rm', 'uninstall', 'un', 'i', 'install', 'update', 'up', 'upgrade') \
            and (plain[0] not in ('i', 'install') or len(plain) > 1):
        if on_main(here): deny('`' + prog + ' ' + plain[0] + '` changes package files in a checkout that')
    if '--fix' in flags or '--write' in flags:
        if on_main(here): deny('a --fix/--write run changes files in a checkout that')
PY
exit 0
