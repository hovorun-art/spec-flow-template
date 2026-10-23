#!/bin/bash
# Shared helpers for the agent scripts. Source this file; do not run it.

# The main checkout (the one that holds the .git directory), wherever the script is started from.
main_root() {
  local common
  common="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --path-format=absolute --git-common-dir)"
  dirname "$common"
}

# Project settings (MAIN_BRANCH, INSTALL_CMD, DEPS_DIR, MERGE_CHECK_CMD) from .claude/flow.conf.
# shellcheck disable=SC1091
source "$(main_root)/.claude/flow.conf"
MAIN_BRANCH="${MAIN_BRANCH:-master}"

# Sibling folder of a change's worktree: ../<repo>-<change>
worktree_dir() {
  local root="$1" change="$2"
  echo "$(dirname "$root")/$(basename "$root")-$change"
}

# Names of the changes to build in parallel, one per line, in merge order.
# A change qualifies when, on the main checkout, it is active (not archived), has a tasks.md and has
# been approved with /specs-go (.decisions-approved). A change may list the changes it must be merged
# after in an optional file openspec/changes/<name>/.merge-after (names separated by spaces or lines);
# the rest is ordered by name.
agent_changes() {
  python3 - "$(main_root)" <<'PY'
import os, sys
root = sys.argv[1]
base = os.path.join(root, 'openspec', 'changes')
names = sorted(
    n for n in os.listdir(base)
    if n != 'archive'
    and os.path.isfile(os.path.join(base, n, 'tasks.md'))
    and os.path.isfile(os.path.join(base, n, '.decisions-approved'))
)
after = {}
for n in names:
    path = os.path.join(base, n, '.merge-after')
    deps = open(path).read().split() if os.path.isfile(path) else []
    after[n] = [d for d in deps if d in names]
done, order = set(), []
while len(order) < len(names):
    ready = [n for n in names if n not in done and all(d in done for d in after[n])]
    if not ready:
        sys.exit('cycle in .merge-after files: ' + ', '.join(n for n in names if n not in done))
    order.append(ready[0])
    done.add(ready[0])
print('\n'.join(order))
PY
}
