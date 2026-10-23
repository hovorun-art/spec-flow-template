#!/bin/bash
# English-only check. Flags Cyrillic, CJK, Arabic, Hebrew, Hangul, Thai and Devanagari
# in any text file outside TRANSLATIONS_DIR, IGNORED_DIRS, .git and lockfiles (see .claude/flow.conf).
#   no args : scan every tracked/untracked non-ignored file in the project
#   <file>  : scan that file only
#   --post  : PostToolUse mode, read the edited file path from the hook JSON on stdin
# Exit 2 with offending lines on stderr (PostToolUse feeds this back to Claude).
# Does not catch accented Latin text (e.g. French); that stays a rule for the agents.
if [ "$1" = "--post" ]; then
  file=$(python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
  [ -n "$file" ] || exit 0
  set -- "$file"
fi
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
source .claude/flow.conf 2>/dev/null
[ "${ENGLISH_ONLY:-1}" = "1" ] || exit 0
export TRANSLATIONS_DIR="${TRANSLATIONS_DIR:-locales}" IGNORED_DIRS="${IGNORED_DIRS:-}"

python3 - "$@" <<'PY'
import os, re, subprocess, sys
BAD = re.compile(r'[\u0400-\u052f\u0590-\u06ff\u0900-\u097f\u0e00-\u0e7f\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af]')
tr = os.environ['TRANSLATIONS_DIR']
dirs = [tr, r'\.git'] + os.environ['IGNORED_DIRS'].split()
SKIP = re.compile(r'(^|/)(' + '|'.join(dirs) + r')/|(^|/)[^/]*-lock\.(json|yaml)$|(^|/)[^/]*\.lock$')
if len(sys.argv) > 1:
    files = [sys.argv[1]]
else:
    files = subprocess.run(['git', 'ls-files', '-co', '--exclude-standard'],
                           capture_output=True, text=True).stdout.splitlines()
hits = []
for f in files:
    f = f.removeprefix(os.getcwd() + '/')
    if SKIP.search(f):
        continue
    try:
        text = open(f, encoding='utf-8').read()
    except (OSError, UnicodeDecodeError):
        continue
    for n, line in enumerate(text.splitlines(), 1):
        if BAD.search(line):
            hits.append(f'{f}:{n}: {line.strip()[:100]}')
if hits:
    print('Non-English text found outside translation files (project rule: English only; '
          f'other languages only in {tr}/). Translate or move these:', file=sys.stderr)
    print('\n'.join(hits[:30]), file=sys.stderr)
    sys.exit(2)
PY
