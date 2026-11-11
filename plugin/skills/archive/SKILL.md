---
name: archive
description: Archive a change that is implemented and verified - merge its delta specs into the main specs and move it to the archive, on the change's own branch. Use when the user wants to finalize or archive a change.
argument-hint: <change-name>
allowed-tools: Bash(openspec:*)
---

Archive change `$ARGUMENTS`. With no name: use the only active change, or ask
(`openspec list --json`).

1. **Where.** On the change's own branch, in its worktree, before it is merged: the merge then
   brings the code and the updated main specs (`openspec/specs/`) together.

2. **Ready?** Stop and say what is missing unless all of these hold:
   - every task is done: in `openspec list --json` the change has `completedTasks` equal to
     `totalTasks`;
   - step 3 of "Checks" in CLAUDE.md is done on the current commit: the first line of
     `openspec/changes/<name>/.verdict` is `PASS`, its `commit:` line is `git rev-parse HEAD`, and
     `git status --porcelain` shows nothing outside `openspec/`. If not, run step 3 now and fix
     what fails.

3. **Archive.** `openspec archive "<name>" -y`. The CLI merges the delta specs into
   `openspec/specs/` and moves the change to `openspec/changes/archive/<date>-<name>/`, with its
   brief and decision log. If it reports an error, show it and stop: nothing was moved.

4. **Check the result.** `openspec validate --specs`; fix what it reports in the main specs. A
   new main spec takes its Purpose from the delta; one left with `TBD` (the delta had none) gets
   a real one now.

5. **Commit** the archive on the change branch (the main specs and the moved change) and report
   the commit.

6. **Next.** Offer the `spec-flow:finish` skill with AskUserQuestion (push, PR or merge, then
   cleanup). Never merge as part of archive.
