# Project

<!-- TODO: one paragraph: what this is, for whom, the core loop or main use case. -->
<What the product is and what it does.> Spec-driven with OpenSpec.
The full concept is in `docs/concept.md` (a source for decisions; each point is decided in a change).

## Language

English only: specs, design, tasks, code, comments, identifiers, UI strings in code, commit
messages and docs. Other languages only inside dedicated translation files (e.g. `locales/`);
text shown to users must come from those files, never be hardcoded in code.
Chat with the user and AskUserQuestion questions/options may be in the user's language; files stay English.

## Git

- Never commit, amend, push, merge, rebase or reset without the user's explicit approval. When work
  is ready to commit, show what will go in and the message; the `guard-git.sh` hook makes Claude Code
  ask before each such git command. One approval covers one command, not later ones. Never route
  around the prompt (other tools, `--no-verify`, scripts).
- New features are built on their own branch, never on the main branch (`MAIN_BRANCH` in
  `.claude/flow.conf`): one branch per change, named after the change (`<change>`). Before
  implementing, check the current branch and create or switch to it if needed. Only planning
  artifacts (`openspec/changes/<change>/`) go on the main branch.

## Testing (TDD)

- Tests come first. For each task: write the test, run it and see it fail for the expected reason,
  write the least code that makes it pass, then refactor with the tests green.
- Every spec scenario (WHEN/THEN) has at least one test that sets up its WHEN and asserts its THEN;
  name the test after the scenario so the verifier can trace it.
- Fix the code, not the test. Change a test only when it contradicts the spec, and then say so.
- Tests are deterministic: time, randomness and I/O come in through parameters or fakes.
- With `TDD_STRICT=1` in `.claude/flow.conf`, the `tdd-guard.sh` hook blocks edits to source files until
  a test file has changed on the branch.

## Commands

<!-- TODO: keep in sync with CHECK_CMDS in .claude/flow.conf -->
- `npm run dev` / `npm run build`
- `npm run typecheck`, `npm run lint`, `npm test` (all three run by the Stop hook)

## Purpose and decisions

<!-- TODO: why this stack, what the project is for (prototype? product?), key libraries and why. -->
Specs must describe user-visible behaviour, not implementation details, so they stay reusable if
the stack changes.

## Architecture

<!-- TODO: module map, what is pure/testable, where randomness and time come from, shared contracts. -->
```
src/...
```

## Workflow

0. Roadmap first: at the start of the project (while `docs/roadmap/` still has its TODO), run the
   `roadmap` skill to turn `docs/concept.md` into milestones (one file each in `docs/roadmap/`) and an
   ordered list of changes. Take each new change from it, and update it when the concept changes.
   Statuses are not stored there: they come from `openspec/changes/`, so archiving needs no roadmap edit.
1. `/opsx:explore` to clarify, then `/opsx:propose "idea"`. Questions come first: the agent writes
   `decisions.md` ("Decided" = only what the user said, "Open questions" = everything else) and asks
   them all. Specs, design and tasks are written only after the user runs `/specs-go <change>`;
   a PreToolUse hook (`gate-specs.sh`) blocks those files until then. Never invent behaviour.

   UI from screenshots: when the user shares a screenshot or mockup, run the `ui-from-screenshots`
   skill: save it in the change's `ui/`, inventory it in `ui.md`, ask about everything the picture does
   not show, and compare the built screen with it by screenshot.

   No numbers in specs: tunable values (speeds, timings, limits, sizes) live in config; they may be
   recorded in `decisions.md`, `design.md`, `tasks.md` and `ui.md`, while specs say "the
   configured ...". Fixed facts that are not tuned may stay.

   How to ask: through the AskUserQuestion tool, never as a plain-text list in chat. Batch the questions:
   up to 4 per call (each one is a tab), more calls if there are more. Each question has prepared
   answer options (2-4, recommended one first) plus the built-in "Other"; single choice (radio) by
   default, multiSelect (checkboxes) when several answers can apply together. Record the answers in
   `decisions.md` after each call.

   Next steps: when a step ends and the next one is a command (`/specs-go <change>`, `/opsx:apply
   <change>`, `/opsx:archive <change>`, a commit...), offer the likely next steps as options in
   AskUserQuestion instead of telling the user to type them. When the user picks one, run it yourself
   (slash commands through the Skill tool); the user's pick counts as running the command, including
   `/specs-go`.
2. Commit the specs on the main branch (with the user's approval), then switch to the change's own
   branch and implement with `/opsx:apply`, test first. Sequential by default; parallel only if the
   user chooses it (see "Parallel work").
3. Hooks enforce the loop (see `.claude/hooks/`, settings in `.claude/flow.conf`): lint on each edit,
   full checks at the end, then the `change-verifier` subagent must return PASS before the work is
   considered done. Run it in the foreground (not `run_in_background`) and wait for it; while it works
   it holds `.verify-running`, and the Stop hook waits instead of counting rounds.
4. `/opsx:archive` after PASS.

Small fixes: a bug fix or change that adds no new behaviour may skip OpenSpec. It still gets its own
branch (`fix/<name>`), a test that reproduces the bug and fails first, then the fix and green checks.
If it turns out to change what the user sees, stop and start a change instead. When it is unclear
which path fits, ask the user.

Tasks in `tasks.md` are grouped as `## N. Title`; check off only your own group's boxes.

## Models

- Main agent: Opus by default (`"model": "opus"` in `.claude/settings.json`), since most tasks
  are non-trivial (new features, architecture, multi-file).
- For purely routine work (small fixes, renames, boilerplate, docs) switch with `/model sonnet`
  at medium effort.
- `change-verifier`: Opus (set in its frontmatter). A false PASS costs more than the extra tokens.
- Choose by measured cost per task, not by price per token.

## Parallel work

Sequential is the default: one agent builds the groups of a change in order, on the change branch.
Whether to run groups in parallel is the user's decision, never Claude's.

- When the "Plan" in `tasks.md` shows groups that could run at the same time, ask with AskUserQuestion
  before implementing: sequential (recommended unless the groups are large and clearly independent)
  or parallel, and which groups. Without an explicit "parallel" answer, work sequentially.
- Parallel runs in waves. Worktrees start from the last commit, so the groups a wave depends on are
  built first in the main checkout and committed (with approval). Then start one subagent per group of
  the wave, all in one message, with the Agent tool and `isolation: "worktree"`; each follows
  `.claude/commands/work-on.md` for its group.
- Subagents do not commit. When they finish, bring each worktree's changes into the change branch
  (`git -C <worktree> add -A && git -C <worktree> diff --cached --binary | git apply --index`) and
  remove the worktree. On a conflict, stop and tell the user: two groups touching one file means the
  plan was wrong.
- After the last wave: the integration group, the full checks, then `change-verifier` on the whole change.
- Groups own disjoint files ("Owns" in `tasks.md`). Shared files (entry point, config, locale files)
  belong to group 1 or to the integration group.
