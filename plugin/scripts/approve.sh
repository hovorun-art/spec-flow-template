#!/bin/bash
# Records the user's approval of a change's brief by creating openspec/changes/<name>/.decisions-approved.
# Only this hook creates the marker (gate-files.sh denies it to agents), so approval always comes from the user:
#   --prompt : UserPromptSubmit, the user typed /spec-flow:specs-go <name> (or /specs-go <name>)
#   --answer : PostToolUse on AskUserQuestion, the user picked an option whose label starts with
#              "Approve the brief" in a question that names the change
# and removes it again when the approved brief is edited:
#   --edited : PostToolUse on Write|Edit|MultiEdit of openspec/changes/<name>/brief.md whose content no
#              longer matches the marker's hash. `openspec status` then shows the approval as missing
#              instead of done. (An edit through Bash leaves the marker; gate-files.sh compares the hash
#              anyway.)
# The marker is created only when brief.md has no unchecked item ("- [ ]") left under "To confirm";
# otherwise the agent is told what is still unresolved. It records the sha256 of brief.md, so
# gate-files.sh treats a later edit of brief.md as unapproved.
# The label is matched in English only. When a question names a change whose brief is ready and offers
# no such option (a translated label), the agent is told to ask again instead of nothing happening.
# decisions.md is the change's log and is never what gets approved.
mode="$1"
input=$(cat)
MODE="$mode" INPUT="$input" python3 - <<'PY'
import datetime, hashlib, json, os, re, sys

mode = os.environ['MODE']
d = json.loads(os.environ.get('INPUT') or '{}')
root = os.environ.get('CLAUDE_PROJECT_DIR') or d.get('cwd') or os.getcwd()
changes = os.path.join(root, 'openspec', 'changes')
event = 'UserPromptSubmit' if mode == '--prompt' else 'PostToolUse'


def say(text):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": text}}))


def approve(name, source):
    folder = os.path.join(changes, name)
    brief = os.path.join(folder, 'brief.md')
    if not os.path.isfile(brief):
        return f"spec-flow: change '{name}' has no brief.md, so nothing was approved."
    open_items = [l.strip() for l in open(brief, encoding='utf-8') if re.match(r'\s*- \[ \]', l)]
    if open_items:
        listing = '\n'.join(open_items[:20])
        return (f"spec-flow: the brief of '{name}' was NOT approved: {len(open_items)} item(s) in "
                f"brief.md are still unchecked (To confirm):\n{listing}\n"
                "Resolve them with the user (AskUserQuestion), write the answers into the brief and the "
                "decision log, then offer approval again.")
    stamp = datetime.datetime.now().astimezone().isoformat(timespec='seconds')
    digest = hashlib.sha256(open(brief, 'rb').read()).hexdigest()
    with open(os.path.join(folder, '.decisions-approved'), 'w', encoding='utf-8') as f:
        f.write(f"approved: {stamp}\nsource: {source}\nsha256: {digest}\n")
    return (f"spec-flow: the user approved the brief of '{name}'. Specs and tasks may now be "
            "written (continue with the spec-flow:specs-go workflow).")


def active():
    if not os.path.isdir(changes):
        return []
    return [n for n in os.listdir(changes) if n != 'archive' and os.path.isdir(os.path.join(changes, n))]


if mode == '--edited':
    path = (d.get('tool_input') or {}).get('file_path') or ''
    if os.path.basename(path) != 'brief.md' or os.path.basename(os.path.dirname(os.path.dirname(path))) != 'changes':
        sys.exit(0)
    folder = os.path.dirname(path if os.path.isabs(path) else os.path.join(d.get('cwd') or root, path))
    marker = os.path.join(folder, '.decisions-approved')
    try:
        recorded = open(marker, encoding='utf-8').read()
        current = hashlib.sha256(open(os.path.join(folder, 'brief.md'), 'rb').read()).hexdigest()
    except OSError:
        sys.exit(0)
    if current not in recorded:
        os.remove(marker)
        say(f"spec-flow: brief.md of '{os.path.basename(folder)}' changed after the user approved it, so the "
            "approval was removed. Specs, tasks and the archive are blocked until the user approves the brief "
            "again: show the brief as it is now and offer \"Approve the brief\".")
    sys.exit(0)

if mode == '--prompt':
    m = re.match(r'\s*/(?:spec-flow:)?specs-go\s+([A-Za-z0-9._-]+)', d.get('prompt', ''))
    if m and m.group(1) in active():
        say(approve(m.group(1), 'user ran /specs-go'))
    sys.exit(0)

# --answer: find the questions the user answered with "Approve the brief..."
ti = d.get('tool_input') or {}
resp = d.get('tool_response')
questions = [q.get('question', '') for q in ti.get('questions', []) if isinstance(q, dict)]
answers = {}
for src in (ti.get('answers'), resp if isinstance(resp, dict) else None,
            resp.get('answers') if isinstance(resp, dict) else None):
    if isinstance(src, dict):
        answers.update({k: v for k, v in src.items() if isinstance(v, str)})
APPROVE = r'Approve the brief'
picked = [q for q, a in answers.items() if re.match(APPROVE, a.strip(), re.I)]
if not picked:
    text = resp if isinstance(resp, str) else json.dumps(resp or '', ensure_ascii=False)
    picked = [q for q in questions if re.search(re.escape(f'"{q}"="') + APPROVE, text, re.I)]

notes = []
names = sorted(active(), key=len, reverse=True)
for q in picked:
    hit = next((n for n in names if re.search(r'(?<![\w-])' + re.escape(n) + r'(?![\w-])', q)), None)
    if hit:
        notes.append(approve(hit, 'user picked "Approve the brief"'))
    else:
        notes.append('spec-flow: "Approve the brief" was picked, but the question did not name an active '
                     'change, so nothing was approved. Ask again with the change name in the question.')


def ready_unapproved(name):
    """brief.md has nothing left to confirm, and no marker holds its current hash."""
    folder = os.path.join(changes, name)
    try:
        data = open(os.path.join(folder, 'brief.md'), 'rb').read()
    except OSError:
        return False
    if re.search(rb'^\s*- \[ \]', data, re.M):
        return False
    try:
        marker = open(os.path.join(folder, '.decisions-approved'), encoding='utf-8').read()
    except OSError:
        return True
    return hashlib.sha256(data).hexdigest() not in marker


# A question about a change whose brief is ready, with no "Approve the brief" option at all: most
# likely the approval question with a translated label, which would otherwise fail silently.
for q in ti.get('questions', []):
    if not isinstance(q, dict) or q.get('question', '') in picked:
        continue
    labels = [o.get('label', '') for o in q.get('options') or [] if isinstance(o, dict)]
    if any(re.match(APPROVE, l.strip(), re.I) for l in labels):
        continue
    text = q.get('question', '')
    hit = next((n for n in names if re.search(r'(?<![\w-])' + re.escape(n) + r'(?![\w-])', text)), None)
    if hit and ready_unapproved(hit):
        notes.append(f"spec-flow: the brief of '{hit}' is ready but not approved, and this question had no "
                     'option labelled "Approve the brief". If it was the approval question, ask it again '
                     'with that label exactly, in English (the question itself may be in the user\'s '
                     'language). Nothing was approved.')
if notes:
    say('\n'.join(notes))
PY
exit 0
