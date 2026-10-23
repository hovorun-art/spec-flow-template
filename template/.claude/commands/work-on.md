---
description: Work on one task group of an OpenSpec change (for parallel chats in separate worktrees)
argument-hint: <change-name> <group-number>
---

Arguments: `$ARGUMENTS` = `<change-name> <group-number>`.

1. Read `openspec/changes/<change-name>/` (proposal, design, specs, tasks). If `tasks.md` has no numbered `## N.` groups, stop and tell the user to regroup it first (e.g. with /opsx:update).
2. Make sure this is a separate git worktree on its own branch, not the main checkout (`git rev-parse --git-common-dir` differs from `--git-dir`). If it is not, stop and tell the user to start one with `claude --worktree <change-name>-<group-number>` so parallel chats do not overwrite each other.
3. Write the group number to `openspec/changes/<change-name>/.scope` (file is gitignored, local to this worktree).
4. Implement only the tasks under group `<group-number>`, following the existing OpenSpec apply workflow. Do not touch other groups' tasks or checkboxes, and stay inside the files the group declares. If you need something owned by another group, stop and report it instead of building it.
5. When the group is done, the Stop hook will require the change-verifier subagent to return PASS for this group. After PASS, commit on this branch and tell the user it is ready to merge.
