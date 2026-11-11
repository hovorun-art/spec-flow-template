---
name: work-on
description: Build one task group of an OpenSpec change in an isolated git worktree. Followed by the parallel subagents that spec-flow:apply starts when the user chose parallel groups; not for the main agent.
argument-hint: <change-name> <group-number>
---

Arguments: `$ARGUMENTS` = `<change-name> <group-number>`.

1. Read `openspec/changes/<change-name>/` (brief, specs, tasks). If `tasks.md` has no numbered `## N.` groups, stop and report it.
2. Make sure this is a separate git worktree of its own, not the change's worktree or the main checkout (`git rev-parse --git-common-dir` differs from `--git-dir`, and `git worktree list` shows this path for this group only). If it is not, stop and report it: parallel groups must never share a checkout. Then make sure it starts from the change branch: if `git merge-base --is-ancestor <change-name> HEAD` fails, run `git switch -c <change-name>-g<group-number> <change-name>` (the worktree is fresh, nothing is lost). Never work on the change branch itself or on the main branch.
3. If the worktree has no dependencies yet, run `INSTALL_CMD` from `.claude/flow.conf` (skip it when `DEPS_DIR` already exists).
4. Implement only the tasks under group `<group-number>`, test first (see "Testing" in `CLAUDE.md`, and the rules in `.claude/rules/` for the code and tests you write). Do not touch other groups' tasks or checkboxes, and stay inside the files the group lists under "Owns". If you need something owned by another group, or a behaviour that is not in `brief.md`, stop and report it instead of building it.
5. Run `npm run check` (typecheck, lint and unit tests; Turborepo reruns only the workspaces you changed and their dependents) until it passes. No integration tests: they run at the end of the change. Never run e2e tests (the levels `CLAUDE.md` reserves for the main agent): list the e2e files that need running in your report, and the main agent runs them. Do not run change-verifier: the main agent brings the groups together and verifies the whole change.
6. Commit the group in the worktree: one commit with every file you changed (including `tasks.md` with your group's boxes checked) and a Conventional Commits message for the group (`type(scope): summary`). The worktree is never on the main branch, so the hook allows it; never commit elsewhere, never push or merge.
7. Report: the worktree path, the commit hash and message, the files you changed, the tasks you checked off, the check results, the test files you wrote or changed (the main agent runs the `spec-flow:test-case-reviewer` on them after the cherry-pick and commits what it asks for as a follow-up commit of the group), and anything left open.
