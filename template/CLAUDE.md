# Project

<!-- TODO: one paragraph: what this is, for whom, the core loop or main use case. -->
<What the product is and what it does.> Spec-driven with OpenSpec and the `spec-flow` plugin.
The full concept is in `docs/concept.md` (a source for decisions; each point is decided in a change).

## Language

English only: specs, design, tasks, code, comments, identifiers, UI strings in code, commit
messages and docs. Other languages only inside dedicated translation files (e.g. `locales/`);
text shown to users must come from those files, never be hardcoded in code.
Chat with the user and AskUserQuestion questions/options may be in the user's language; files stay
English. Deliberate exceptions (e.g. a test for Cyrillic input) carry `allow-non-english` on the line
or match `LANGUAGE_IGNORE` in `.claude/flow.conf`.

## Git

- Commits on a change or fix branch need no approval: the main agent and subagents commit their
  own work there (the hook allows `git commit` and `git cherry-pick` off the main branch) and report
  the commit (files and message) afterwards. Never commit on the main branch (`MAIN_BRANCH` in
  `.claude/flow.conf`): the hook denies it, the main branch only receives merges.
- Never push, merge, rebase, reset, amend or revert without the user's explicit approval; the hook
  makes Claude Code ask before each such git command. One approval covers one command, not later
  ones. Never route around the prompt (other tools, `--no-verify`, scripts).
- New features are built on their own branch, never on the main branch (`MAIN_BRANCH` in
  `.claude/flow.conf`): one branch per change, named after the change (`<change>`), created before
  the first planning artifact. Planning (`openspec/changes/<change>/`), code and the archive all go on
  that branch; the main branch only receives the merge, which brings the code and the updated main
  specs together.
- One commit per task group: when a group of `tasks.md` is done (its boxes checked, its test review
  acted on, the checks green), commit it (the files, including the checked boxes, with a
  Conventional Commits message for that group) and report the commit before starting the next
  group. Groups are never folded into one commit, and a group is not split across commits. With
  parallel groups, each subagent commits its group in its worktree and the main agent cherry-picks
  that commit onto the change branch.

## Testing (TDD)

- Tests come first. For each task: write the test, run it and see it fail for the expected reason,
  write the least code that makes it pass, then refactor with the tests green.
- Every spec scenario (WHEN/THEN) has at least one test that sets up its WHEN and asserts its THEN;
  name the test after the scenario so the verifier can trace it.
- Fix the code, not the test. Change a test only when it contradicts the spec, and then say so.
- Tests are deterministic: time, randomness and I/O come in through parameters or fakes.
  <!-- TODO: how dependencies are mocked (library, one-shot stubs), how time is faked. -->
- Test data never comes from the app's own code (its id or random generators): generated values
  come from the platform directly, held in a named constant when a test compares the same value
  twice; no hardcoded ids.
- One test file per source file, next to it; no grab-bag test files. Test behaviour, not language
  facts: no tests that a constant exists or has a given type.
- Levels: <!-- TODO: each test level, its file pattern and what it mocks, e.g. unit (`*.test.ts`
  next to the code), integration (`*.int.test.ts`, one adapter against its real dependency),
  e2e (`test/e2e/`, the app as a black box). -->
- After writing or changing tests, run the `spec-flow:test-case-reviewer` subagent in the
  foreground on that area. Give it only the area (app or package and test level, or the file), not
  your own reasoning, so it judges the cases independently. Add the missing corner cases it
  reports, or tell the user why a case does not belong to that area. This covers every area with
  test changes, not only the main one; `tasks.md` gives each group that writes tests a review task,
  and `/spec-flow:apply` runs the review even when that task is missing.
- Run only the tests related to what changed: every test that imports a changed file, directly or
  through other modules, plus changed test files, not the whole suite
  (<!-- TODO: the command, e.g. `npx vitest related --run <changed files>...` -->). Run a whole app
  or level only with a reason (a change to shared wiring, config or a module many files use, or the
  final check before a commit), and say what the reason is.
- E2e tests (<!-- TODO: which files and commands -->) run only in the main agent. Subagents
  (`spec-flow:work-on`, `spec-flow:test-case-reviewer`, `spec-flow:change-verifier` and any other)
  never run them: several stacks at once overload the machine. A subagent runs unit and integration
  tests of its area only, and lists the e2e files the main agent should run; the main agent runs
  them and acts on the result.
- With `TDD_STRICT=1` in `.claude/flow.conf`, a hook blocks edits to source files until a test file
  has changed on the branch.

## Commands

<!-- TODO: keep in sync with CHECK_CMDS in .claude/flow.conf -->
- `npm run dev` / `npm run build`
- `npm run typecheck`, `npm run lint`, `npm test` (all three run by the Stop hook, only when a file
  matching `CHECK_TRIGGER` changed since the last green run)

## Purpose and decisions

<!-- TODO: why this stack, what the project is for (prototype? product?), key libraries and why. -->
Specs must describe user-visible behaviour, not implementation details, so they stay reusable if
the stack changes.

## Architecture

<!-- TODO: module map, what is pure/testable, where randomness and time come from, shared contracts. -->
```
src/...
```

## Asking

- Ask through the AskUserQuestion tool, never as a plain-text list in chat. Batch related questions:
  up to 4 per call (each one is a tab), more calls if there are more, blocking questions first.
- Each question has prepared answer options (2-4, recommended one first) plus the built-in "Other";
  single choice by default, multiSelect when several answers can apply together.
- Record the answers in the change's `decisions.md` after each call.
- Libraries: when a library could do something (retries, parsing, scheduling...), do not hand-write
  it and do not pick one yourself. Collect the candidates with their usage and fit (weekly
  downloads, latest version and its date, types, module format, the features the task needs) and
  let the user choose through AskUserQuestion. Record the choice, with the numbers and the reason,
  in the change's `decisions.md`.
- Next steps: when a step ends and the next one is a command (`/spec-flow:apply <change>`,
  `/spec-flow:archive <change>`, a commit...), offer the likely next steps as options instead of
  telling the user to type them, and run the one they pick yourself (skills through the Skill tool).

## Workflow

0. Roadmap first: at the start of the project (while `docs/roadmap/` still has its TODO), run the
   `spec-flow:roadmap` skill to turn `docs/concept.md` into milestones and an ordered list of changes.
   Take each new change from it, and update it when the concept changes.
1. `/spec-flow:explore` to clarify, then `/spec-flow:propose "idea"`. The `spec-flow` schema
   (`openspec/schemas/spec-flow/`) orders the artifacts: proposal → `decisions.md` → the user's
   approval → specs, design → tasks.
   - `decisions.md` has "Decided" (only what the user said or confirmed), "Assumed" (minor defaults
     you propose, confirmed by the user in one batch) and "Open questions" (everything else).
     Never invent behaviour: anything bigger than a minor default is a question.
   - Approval comes only from the user: they type `/spec-flow:specs-go <change>` or pick
     "Approve decisions" when you offer it. A hook then writes `.decisions-approved`, and only when
     nothing in `decisions.md` is unchecked. Until then hooks block specs, design and tasks, and no
     agent may write the marker.
   - UI from screenshots: when the user shares a screenshot or mockup, run the
     `spec-flow:ui-from-screenshots` skill.
   - No numbers in specs: tunable values (speeds, timings, limits, sizes) live in config and may be
     recorded in `decisions.md`, `design.md`, `tasks.md` and `ui.md`; specs say "the configured ...".
2. Commit the planning artifacts on the change's own branch, then implement there with
   `/spec-flow:apply`, test first. Sequential by default; parallel groups
   only if the user chooses it (the apply skill describes how).
3. Hooks enforce the loop (settings in `.claude/flow.conf`): lint on each edit, full checks at the
   end, then the `spec-flow:change-verifier` subagent must return PASS before the work is done. Run it
   in the foreground and wait for it. Its verdict is recorded by a hook from its final message; no
   agent writes `.verdict`.
4. `/spec-flow:archive` after PASS, on the change branch.

Small fixes: a bug fix or change that adds no new behaviour may skip OpenSpec. It still gets its own
branch (`fix/<name>`), a test that reproduces the bug and fails first, then the fix and green checks.
If it turns out to change what the user sees, stop and start a change instead. When it is unclear
which path fits, ask the user.

## Models

- Main agent: Opus by default (`"model": "opus"` in `.claude/settings.json`), since most tasks
  are non-trivial (new features, architecture, multi-file).
- For purely routine work (small fixes, renames, boilerplate, docs) switch with `/model sonnet`
  at medium effort.
- `change-verifier`: Opus (set in its frontmatter). A false PASS costs more than the extra tokens.
- Choose by measured cost per task, not by price per token.
