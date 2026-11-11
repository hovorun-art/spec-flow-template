---
name: finish
description: Finish a branch whose work is done (a change after archive, a fix or docs branch after green checks) - push it, open a PR, or merge it into the main branch only with the user's explicit approval, then remove its worktree and branch. Use when the user wants to wrap up, ship, merge, push or clean up a change, fix or docs branch.
argument-hint: "[branch]"
---

Merging into the main branch (`MAIN_BRANCH` in `.claude/flow.conf`) happens only when the user asks for it
now: they pick "Merge" below, and then approve the `git merge` prompt the `guard-git` hook raises. An
earlier approval, a "go ahead" for other work, or a plan that says "then merge" is not that approval.
Never merge any other way (`git pull`, `git push origin <branch>:<main>`, `gh pr merge`, a script).

1. **Ready?** On the branch to finish (the argument, else the current branch, never the main branch):
   - A branch that is already merged (`git branch --merged <MAIN_BRANCH>` lists it): only the cleanup
     is left, go to step 4.
   - `git status --porcelain` is empty: everything is committed. If not, commit the rest on this branch
     first (no approval needed) and report the commit.
   - A change (`openspec/changes/archive/` holds it, or `openspec/changes/<branch>/` still exists): it was
     archived after `spec-flow:change-verifier` returned PASS. If not, say what is missing
     (`/spec-flow:apply`, the verifier, `/spec-flow:archive`) and stop.
   - The checks are done for the branch's last commit ("Checks" in `CLAUDE.md`). A change: step 3 ran
     before the archive; rerun `npm run check:full` rather than guess (it replays from the Turborepo
     cache when nothing changed). A fix or docs branch: the lighter set for small work described there.
     Fix what fails before offering anything.
   - Show the commits the branch adds: `git log --oneline <MAIN_BRANCH>..<branch>`.

2. **Ask what to do** with AskUserQuestion (single choice, these options):
   - "Push the branch" (recommended when a remote exists): `git push -u origin <branch>`. Allowed without
     a prompt.
   - "Push and open a PR": push, then `gh pr create --base <MAIN_BRANCH> --head <branch>`, filling
     `.github/pull_request_template.md`. Merging the PR stays with the user.
   - "Merge into <MAIN_BRANCH> now": see step 3.
   - "Leave it": stop.

3. **Merge** (only after the user picked it in step 2):
   - Find the main checkout: the first `worktree` entry of `git worktree list --porcelain`. Its
     `git status --porcelain` must be clean; if not, stop and tell the user.
   - The main checkout must be on the main branch. A change's worktree leaves it there. A `fix/` or
     `docs/` branch lives in the main checkout itself: when it is on the branch being finished, run
     `git -C <main checkout> switch <MAIN_BRANCH>` first. On any other branch, stop and tell the user.
   - `git -C <main checkout> merge --no-ff <branch>`. The hook asks the user once more; if they decline,
     stop. On a conflict, stop and show the conflicting files; abort (`git -C <main checkout> merge
     --abort`) only if the user asks.
   - Do not push the main branch unless the user asks for it (the hook asks for that too).

4. **Clean up** (after a merge, or when the user asks): offer it with AskUserQuestion.
   - A worktree: it is removed from the main checkout, not from inside it. If this session runs in the
     main checkout (`/spec-flow:finish <branch>` there), run
     `git worktree remove <path> && git branch -d <branch>` yourself. If it runs inside the worktree, it
     cannot remove its own folder: tell the user to close this session and either run that command from
     the main checkout or send `/spec-flow:finish <branch>` to a session there, which does the cleanup.
   - A branch in the main checkout: `git switch <MAIN_BRANCH>` (unless the merge already did) and
     `git branch -d <branch>`.
   - `git branch -d` refuses an unmerged branch; never force it (`-D`) without the user asking.
