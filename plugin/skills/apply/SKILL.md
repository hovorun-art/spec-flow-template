---
name: apply
description: Implement the tasks of a planned change, one task group at a time, test first. Use when the user wants to start or continue implementing a change, or says "apply".
argument-hint: <change-name>
allowed-tools: Bash(openspec:*)
---

Implement change `$ARGUMENTS`. With no name: use the only active change, or ask
(`openspec list --json`).

1. **Where.** In the change's own worktree, on its branch. If `git branch --show-current` is the
   main branch (`MAIN_BRANCH` in `.claude/flow.conf`), stop and run the `spec-flow:start` skill
   instead of switching branches here.

2. **Load.** `openspec instructions apply --change "<name>" --json` returns the state, the progress,
   the task list (each task with its file and line) and `contextFiles`. Read every context file
   (`brief.md`, the delta specs, `tasks.md`), and the `.claude/rules/` files for the code the tasks
   touch.
   - `blocked`: planning is not finished; say what is missing (`/spec-flow:propose <name>`) and stop.
   - `all_done`: go to step 5.
   Say in one line where the change stands: "N/M tasks, next: group K".

3. **Parallel or sequential.** If `tasks.md` has groups that do not depend on each other
   ("Depends on"), ask with AskUserQuestion: sequential (recommended unless the groups are large
   and clearly independent) or parallel, and which groups. Without an explicit "parallel" answer,
   work sequentially. For parallel, see the end of this skill.

4. **One task group at a time**, following "Testing", "Checks" (steps 1 and 2) and "Git" in
   CLAUDE.md:
   - for each task: the test first, see it fail for the expected reason, the least code that
     passes; then check its box (`- [ ]` → `- [x]`). Check a box only when the task is fully done.
     Stay inside the files the group lists under "Owns";
   - when the group's tasks are done: `npm run check`, then the `spec-flow:test-case-reviewer`
     subagent (Sonnet) on the test files the group wrote or changed; act on its report;
   - commit the group (one commit, `tasks.md` with its checked boxes included) and report the
     commit (hash, files, message) before the next group starts.
   E2e tests run only here, in the main agent.

   **Stop and ask** instead of deciding in code when:
   - a behaviour is unclear or the brief does not settle it: add it to "To confirm" in `brief.md`;
   - the work has to differ from the brief's "Technical" section (another library, a module that
     could not be reused, a task that needs more than the specs describe).
   Either way the brief changes, so the user approves it again, and the decision, its reason and
   what triggered it are appended to `decisions.md`.

5. **Done means verified.** When every task is checked and committed, run step 3 of "Checks" in
   CLAUDE.md, in its order: the Opus test review and `spec-flow:change-verifier` together, fixes
   (their own commit) until PASS, then `npm run check:full` and `npm run test:e2e` once. No hook
   runs this for you, and a hook denies the archive without a PASS on the current commit. Show the
   user the verifier's "Against the brief" list, then offer `/spec-flow:archive <name>`.

Merging is never part of apply: that is `spec-flow:finish`.

## Parallel groups (only when the user chose parallel)

- Run in waves. A group's worktree starts from the change branch's last commit, so the groups a
  wave depends on are built first, in the change's worktree, and committed.
- Start one subagent per group of the wave, all in one message, with the Agent tool and
  `isolation: "worktree"`; each follows the `spec-flow:work-on` skill (`<change> <group-number>`).
- Each subagent commits its group on a branch of its own (`<change>-g<N>`) and reports the hash.
  Bring each commit onto the change branch with `git cherry-pick <hash>`, one group at a time,
  then remove the group's worktree and branch (`git worktree remove <path> && git branch -D
  <change>-g<N>`; the hook asks for `-D`, since a cherry-picked branch is not merged). On a
  conflict, stop and tell the user: two groups touching one file means the plan was wrong.
- After each cherry-pick run the group's test review on the test files its report lists; what the
  review asks for is one follow-up commit for that group (`test(<scope>): ...`).
- After the last wave: the group that wires the others together, if there is one, then step 5.
