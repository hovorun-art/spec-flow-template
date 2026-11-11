---
name: start
description: Start any piece of work on its own branch before anything is written. A fix that changes no behaviour, or an update of the instructions and docs themselves, gets a branch in the current checkout; anything that adds or changes behaviour gets an OpenSpec change in its own git worktree, continued in a new Claude session there. Use before the first edit of any task, when the user describes something to build or fix, names a roadmap item, or a hook blocked an edit on the main branch.
argument-hint: <what to do, or a roadmap item>
---

Nothing is ever changed on the main branch (`MAIN_BRANCH` in `.claude/flow.conf`): the `guard-main`
hook denies every edit there, docs and instructions included. This skill puts the work on its own
branch first.

1. **Check where you are.** Run `git status --porcelain` and `git branch --show-current`.
   - Already on a branch other than the main one that belongs to this work: nothing to start, continue
     there.
   - Uncommitted changes in the checkout that belong to other work: stop and ask the user what to do
     with them (commit them on their branch, or leave the start for later). Never stash or discard them.

2. **Classify the work.** Decide from what the user asked, and ask with AskUserQuestion when unclear:
   - **Small**: a bug fix that changes no behaviour a user can see (the spec already describes the right
     behaviour, the code does not follow it), or an update of the instructions and docs themselves
     (`CLAUDE.md`, `docs/`, `.claude/flow.conf`, CI, README, comments). Small work skips OpenSpec.
   - **Change**: everything else: a new behaviour, a change of behaviour, anything a spec scenario would
     describe. It goes through OpenSpec (`/spec-flow:propose`).
   - If small work turns out to change what the user sees, stop and start a change instead.

3. **Small: a branch in this checkout.**
   - Name: `fix/<kebab-name>` for a fix, `docs/<kebab-name>` for an instruction or docs update.
   - `git switch -c <branch> <MAIN_BRANCH>` (from the main branch's tip; never reuse a branch of other work).
   - Then do the work there: a fix starts with a test that reproduces the bug and fails, then the fix,
     then the lighter checks for small work (the end of "Checks" in `CLAUDE.md`). Commit as you go (no
     approval needed off the main branch). When it is done, run the `spec-flow:finish` skill.

4. **Change: its own worktree and session.**
   - Name: kebab-case, the roadmap item's name if it comes from `docs/roadmap/`. It is the change name and
     the branch name. Check that neither the branch nor `openspec/changes/<name>/` exists yet; if one
     does, ask whether to continue that work instead.
   - Path: `<WORKTREES_DIR>/<project>-<name>`, where `WORKTREES_DIR` comes from `.claude/flow.conf`
     (default `..`, so the worktree sits next to the project, not inside it, and a session there does not
     also load this checkout's `CLAUDE.md`) and `<project>` is the name of the main checkout's folder.
   - Create it from the main branch's tip: `git worktree add -b <name> <path> <MAIN_BRANCH>`.
   - Install the dependencies there: `cd <path> && <INSTALL_CMD>` (skip it when `DEPS_DIR` exists).
     Local files that git ignores (`.claude/settings.local.json`, `.env*`) are not in the worktree; tell
     the user if the project needs them.
   - Do not write anything for the change in this session. The planning needs many questions to the user,
     so the change gets its own session. Tell the user, in one short block:
     - the worktree path and branch;
     - one command, ready to paste into a terminal, that opens the session there and sends the first
       message: `cd <path> && claude "/spec-flow:propose <name>: <summary>"`. The summary holds what
       was already discussed here (the goal, what the user decided, the open questions), so nothing is
       lost between sessions; keep it on one line and free of `"`, `$` and backticks so the shell
       passes it as written;
     - for VS Code instead: open the folder, start Claude there and send that
       `/spec-flow:propose <name>: <summary>` message.
   - Several changes may be started this way, one worktree and one session each. Changes that touch the
     same files or depend on each other are better done one after another: start the next one when the
     previous one is merged.
