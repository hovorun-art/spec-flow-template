#!/bin/bash
# PreToolUse hook (Bash): decides git commands that write history, move branches or publish them,
# however they are spelled (git -C <dir> ..., `cd <dir> && git ...`, chained commands).
#   - commit / cherry-pick on the main branch (MAIN_BRANCH in flow.conf): denied, the main branch only
#     receives merges. On any other branch: allowed without asking, for the main agent and subagents.
#     `commit --amend` asks (it rewrites a commit that may already be reported or pushed).
#   - push of a change or fix branch: allowed. A push that targets the main branch, deletes, forces or
#     pushes everything (--all, --mirror, --tags): the user is asked.
#     "Allowed" covers the whole Bash command, so it is given only when every part of the command is a
#     plain `cd` or one of git add/commit/cherry-pick/push/status/diff/log/show/rev-parse/switch/checkout
#     of a branch, with no redirect into a file and no command substitution (a commit message from a
#     quoted heredoc, "$(cat <<'"'"'EOF'"'"' ... EOF)", is fine). Anything else chained to the commit
#     (`curl ... | sh && git commit`) leaves the decision to the normal permission rules.
#   - merge, pull, rebase, reset, revert, tag, update-ref, gh pr merge: the user is asked. Merging
#     always needs the user's explicit approval.
#   - Commands that throw work away (branch -D, worktree remove --force, clean, stash drop/clear): asked.
# The branch is the one the command will run on: a `cd` or `git switch -c` / `checkout -b` earlier in the
# same command counts. Asking too often is harmless; committing on the main branch or merging unasked is not.
MAIN_BRANCH=main
# shellcheck disable=SC1091
[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/flow.conf" ] && source "${CLAUDE_PROJECT_DIR:-.}/.claude/flow.conf"
export MAIN_BRANCH

python3 -c '
import json, os, re, shlex, subprocess, sys

data = json.load(sys.stdin)
cmd = data.get("tool_input", {}).get("command", "")
cwd = data.get("cwd") or os.getcwd()
main = os.environ.get("MAIN_BRANCH", "main")

def decide(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}))
    sys.exit(0)

def git(directory, *args):
    try:
        out = subprocess.run(["git", "-C", directory, *args], capture_output=True, text=True, timeout=5)
    except Exception:
        return None
    return out.stdout.strip() if out.returncode == 0 else None

if "git" not in cmd and "gh" not in cmd:
    sys.exit(0)

# Newlines outside quotes separate commands, like ";".
def split_lines(s):
    out, q, i = [], None, 0
    while i < len(s):
        c = s[i]
        if c == "\\" and q != "\x27" and i + 1 < len(s):
            out.append(s[i:i + 2]); i += 2; continue
        if q:
            if c == q: q = None
        elif c in "\x27\"":
            q = c
        elif c == "\n":
            c = " ; "
        out.append(c); i += 1
    return "".join(out)

# A message passed as "$(cat <<\x27EOF\x27 ... EOF)" is literal text: replace it with one word, so quotes
# inside the message cannot break the parsing and the substitution is not taken for a command.
HEREDOC = re.compile(r"\"?\$\(\s*cat\s+<<-?\s*([\x27\"])(\w+)\1[ \t]*\n.*?\n[ \t]*\2[ \t]*\n?\s*\)\"?", re.S)
cmd = HEREDOC.sub(" MESSAGE ", cmd)

try:
    lex = shlex.shlex(split_lines(cmd), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    tokens = list(lex)
except ValueError:
    tokens = None

if tokens is None:
    # Unparseable (unbalanced quotes, heredoc bodies): fall back to text matching.
    if re.search(r"\bgh\s+pr\s+merge\b", cmd) or re.search(
            r"\bgit\b[^|;&]*\b(commit|cherry-pick|push|merge|pull|rebase|reset|revert|tag|update-ref|clean)\b", cmd):
        decide("ask", "Project rule: this git command could not be parsed, so it needs the user'"'"'s approval.")
    sys.exit(0)

SEPARATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;", "|&"}
segments, cur = [], []
for t in tokens:
    if t in SEPARATORS:
        if cur: segments.append(cur)
        cur = []
    else:
        cur.append(t)
if cur: segments.append(cur)

asks, allowed = [], False
plain_git_only = True  # every segment is a cd or a harmless git command: the only case that is auto-allowed
SAFE_SUBS = {"add", "commit", "cherry-pick", "push", "status", "diff", "log", "show", "rev-parse"}

def writes_or_substitutes(seg):
    for j, t in enumerate(seg):
        if "$(" in t or "`" in t or "<(" in t:
            return True
        if set(t) <= set("<>&|") and ">" in t and t != ">&":
            if not (j + 1 < len(seg) and seg[j + 1] == "/dev/null"):
                return True
    return False
branch_override = {}  # repo top-level -> branch switched to earlier in this command

def resolve(base, d):
    d = os.path.expanduser(d)
    return os.path.normpath(d if os.path.isabs(d) else os.path.join(base, d))

def branch_at(directory):
    top = git(directory, "rev-parse", "--show-toplevel")
    if top is None:
        return None, None
    if top in branch_override:
        return top, branch_override[top]
    return top, git(directory, "symbolic-ref", "--short", "-q", "HEAD") or "HEAD"

GLOBAL_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}

for seg in segments:
    # Skip leading env assignments and wrappers.
    if writes_or_substitutes(seg):
        plain_git_only = False
    while seg and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[0]) or seg[0] in ("command", "env", "time", "exec")):
        plain_git_only = False
        seg = seg[1:]
    if not seg:
        continue
    if seg[0] == "cd":
        target = next((a for a in seg[1:] if not a.startswith("-")), os.path.expanduser("~"))
        cwd = resolve(cwd, target)
        continue
    if seg[0] == "gh":
        plain_git_only = False
        if len(seg) > 2 and seg[1] == "pr" and seg[2] == "merge":
            asks.append("gh pr merge")
        continue
    if seg[0] != "git":
        if os.path.basename(seg[0]) != "git":
            plain_git_only = False
            continue
        plain_git_only = False  # git by a path: still judged below, never auto-allowed
    # git [global options] <sub> [args]
    i, directory = 1, cwd
    while i < len(seg) and seg[i].startswith("-"):
        if seg[i] == "-C" and i + 1 < len(seg):
            directory = resolve(directory, seg[i + 1]); i += 2; continue
        plain_git_only = False  # -c, --git-dir, --exec-path...: can change what git runs
        if seg[i] in GLOBAL_WITH_ARG:
            i += 2; continue
        i += 1
    if i >= len(seg):
        continue
    sub, args = seg[i], seg[i + 1:]
    if any(re.match(r"--(exec|receive-pack|upload-pack)\b", a) for a in args):
        plain_git_only = False
    flags = [a for a in args if a.startswith("-")]
    plain = [a for a in args if not a.startswith("-")]

    if sub in ("switch", "checkout"):
        top = git(directory, "rev-parse", "--show-toplevel")
        if top is None or "--" in args:
            plain_git_only = False  # restoring files, or not a repository
            continue
        create = {"-c", "-C", "--create", "--force-create", "-b", "-B", "--orphan"}
        name = None
        for j, a in enumerate(args):
            if a in create and j + 1 < len(args):
                name = args[j + 1]; break
        if name is None and len(plain) == 1 and git(directory, "show-ref", "--verify", "-q", "refs/heads/" + plain[0]) is not None:
            name = plain[0]
        if name is None and "--detach" in args:
            name = "HEAD"
        if name:
            branch_override[top] = name
        if not name or set(args) & {"-f", "--force", "--discard-changes"}:
            plain_git_only = False  # restoring files or forcing: not a plain branch switch
        continue
    if sub not in SAFE_SUBS:
        plain_git_only = False

    if sub in ("commit", "cherry-pick"):
        top, branch = branch_at(directory)
        if branch == main:
            decide("deny", f"Project rule: never commit on the main branch ({main}); the main branch only receives merges. Commit on the change or fix branch.")
        if branch is None:
            asks.append(sub)
        elif sub == "commit" and "--amend" in flags:
            asks.append("commit --amend")
        else:
            allowed = True
    elif sub == "push":
        top, branch = branch_at(directory)
        risky = {"-f", "--force", "--force-with-lease", "--force-if-includes", "--mirror", "--all",
                 "--tags", "-d", "--delete", "--prune"}
        refspecs = plain[1:]
        to_main = any(re.search(r"(^|:|/)" + re.escape(main) + r"$", r.lstrip("+"))
                      or (r.lstrip("+").split(":")[0] == "HEAD" and ":" not in r and branch == main) for r in refspecs)
        deletes = any(r.startswith(":") for r in refspecs)
        forced = any(r.startswith("+") for r in refspecs)
        if (set(flags) & risky or any(f.startswith("--force") for f in flags) or to_main or deletes or forced
                or (not refspecs and branch in (main, None, "HEAD"))):
            asks.append("push to the main branch, forced or deleting")
        else:
            allowed = True
    elif sub in ("merge", "pull", "rebase", "reset", "revert", "tag", "update-ref"):
        if sub == "merge" and set(flags) & {"--abort", "--quit"}:
            continue
        if sub == "rebase" and set(flags) & {"--abort", "--quit"}:
            continue
        asks.append(sub)
    elif sub == "branch":
        if set(flags) & {"-D", "-f", "--force", "-M", "-C"} or ("--delete" in flags and "--force" in flags):
            asks.append("branch " + " ".join(sorted(set(flags) & {"-D", "-f", "--force", "-M", "-C", "--delete"})))
    elif sub == "worktree":
        if plain[:1] == ["remove"] and set(flags) & {"-f", "--force"}:
            asks.append("worktree remove --force")
    elif sub == "clean":
        if not set(flags) & {"-n", "--dry-run"}:
            asks.append("clean")
    elif sub == "stash":
        if plain[:1] in (["drop"], ["clear"]):
            asks.append("stash " + plain[0])

if asks:
    decide("ask", "Project rule: " + ", ".join(sorted(set(asks))) + " needs the user'"'"'s approval (merges and history rewrites are never done unasked).")
if allowed and plain_git_only:
    decide("allow", "Project rule: commits and pushes of a branch other than the main branch need no approval.")
' 2>/dev/null
exit 0
