# Project

<!-- TODO: one paragraph: what this is, for whom, the core loop or main use case. -->
<What the product is and what it does.> A TypeScript monorepo: backend services on Node and a React
web app. Spec-driven with OpenSpec and the `spec-flow` plugin.
The full concept is in `docs/concept.md` (a source for decisions; each point is decided in a change).

Stack: TypeScript (`strict`, `noUncheckedIndexedAccess`; no `any`, use `unknown` and narrow), npm
workspaces, Turborepo, Zod contracts, React (Vite), Vitest, Playwright, ESLint + Prettier.
<!-- TODO: what the project is for (prototype? product?), the server framework, the database and
other infrastructure, key libraries and why. -->

## Layout and rules

```
apps/<service>/      a backend service, one bounded context:
                     src/{domain,infra,app}/ + main.ts; test/e2e/ (per-app e2e)
apps/web/            React + Vite web app, src/features/<feature>/
packages/kernel      framework-free: ports (Clock, Random, Sleeper, ...), DomainError + ERROR_CODES
packages/contracts   Zod schemas and inferred types shared by the services and the web app
packages/service-kit shared backend pieces bound to the server framework (bootstrap, config,
                     logging, health, error mapping)
tests/support        test-only helpers for integration and e2e tests
tests/system-e2e     Playwright suite against the whole system running together
tooling/             shared tsconfig, ESLint (layer and class rules) and Vitest presets
```
<!-- TODO: each service: what it owns, its routes, its storage. Data ownership between services. -->

OOP with DDD and onion layers for the backends, functional React for the web app. The detailed
rules live in `.claude/rules/` and load by themselves when you read a file they cover. Read the one
you need yourself before you write a brief's "Technical" section or `tasks.md`, and before you
create the first file of a kind:

- `backend.md`: layers, interfaces and classes, request objects, contracts, errors.
- `web.md`: the web app.
- `testing.md`: how a test is written, the test levels and what each one mocks.
- `tooling.md`: the root scripts, the workspace tasks and the Turborepo cache.

## Code

Concise, never cryptic: the least code that does the job and still reads at a glance.

- Do not inflate. No abstraction, option, layer or config for a need that does not exist yet; no
  comments that repeat the code; no defensive code for cases that cannot happen.
- Do not shrink it into a puzzle either: no clever one-liners, dense chains or abbreviated names.
  When shorter and clearer disagree, clearer wins.
- Reuse first. Before writing anything, look for what the project already has (a module, port,
  component, helper, test helper) and use or extend it. The same logic is never written twice.
- Do not reinvent what a solid library already solves well (retries, parsing, dates, scheduling),
  and do not add a dependency for what a few plain lines do (the `is-odd` kind).
- Tests are how the result is checked, so they are the easiest code to read.

## Language

English only: briefs, specs, tasks, code, comments, identifiers, UI strings in code, commit
messages and docs. Other languages only inside dedicated translation files (e.g. `locales/`);
text shown to users must come from those files, never be hardcoded in code.
Chat with the user and AskUserQuestion questions/options may be in the user's language; files stay
English. Deliberate exceptions (e.g. a test for Cyrillic input) carry `allow-non-english` on the line
or match `LANGUAGE_IGNORE` in `.claude/flow.conf`.

## Workflow

Each step is a skill of the `spec-flow` plugin; the skill holds the details.

0. `spec-flow:roadmap`, once, while `docs/roadmap/` still has its TODO: turns `docs/concept.md` into
   milestones and an ordered list of changes. Take each new change from it.
1. `spec-flow:start` before the first edit of any work (`/spec-flow:explore` may come first to
   clarify). Nothing is changed on the main branch (`MAIN_BRANCH` in `.claude/flow.conf`): not
   code, not docs, not these instructions; a hook denies it.
   - Small work: a fix that changes no behaviour a user can see, or an update of the instructions
     and docs. It gets `fix/<name>` or `docs/<name>` in this checkout and skips OpenSpec. A fix
     starts with a test that reproduces the bug and fails. If it turns out to change what the user
     sees, stop and start a change. When it is unclear which path fits, ask the user.
   - A change (new or changed behaviour): its own worktree and branch `<change>`, and its own Claude
     session there. Planning, code and the archive all happen in that worktree.
2. `/spec-flow:propose`: brief → the user's approval → specs → tasks.
   - `brief.md` is the one page the user reads and approves: what was agreed in the conversation,
     in a product cut and a technical cut. It holds only what the user said or confirmed; anything
     else is an item under "To confirm". Never invent behaviour.
   - `decisions.md` is the change's log: every decision with its reason is appended to it, also
     later changes of the brief and deviations found while implementing.
   - Specs and tasks are for the agents; they never restate the brief or each other.
   - Approval comes only from the user; a hook records it. Until then, and again after any edit of
     the brief, hooks block specs and tasks.
3. `/spec-flow:apply`: test first, one task group at a time. Sequential by default; parallel groups
   only if the user chooses it.
4. Step 3 of "Checks" when the last group is committed. Show the user the verifier's "Against the
   brief" list, then `/spec-flow:archive`.
5. `spec-flow:finish`: push or open a PR; merge only when the user picks it and approves the prompt.

## Git

- Off the main branch commits and pushes of the branch need no approval: the main agent and
  subagents commit each step as it is done (the planning artifacts with the approval marker, each
  task group, the verifier's fixes, the archive) and report the commit (hash, files, message).
  Conventional Commits: `type(scope): summary`, e.g. `feat(<service>): ...`, `fix(web): ...`.
- One commit per task group, made when step 2 of "Checks" is done for it. Groups are never folded
  into one commit or split across commits. Only a parallel group differs: its subagent commits
  before the review, and what the review asks for is one follow-up commit (see the apply skill).
- Merging into the main branch only with the user's explicit approval, through `spec-flow:finish`:
  the user picks "Merge", then approves the git prompt. An approval covers that one command; "go
  ahead" for other work is not an approval to merge.
- Never merge, pull, rebase, reset, amend, revert, force-push or delete unmerged work without the
  user's explicit approval; a hook makes Claude Code ask. Never route around the prompt
  (`gh pr merge`, `git push origin <branch>:main`, other tools, `--no-verify`, scripts).

## Testing

- Tests come first. For each task: write the test, run it and see it fail for the expected reason,
  write the least code that makes it pass, then refactor with the tests green.
- Every spec scenario (WHEN/THEN) has at least one test that sets up its WHEN and asserts its THEN,
  named after the scenario so the verifier can trace it.
- Fix the code, not the test. Change a test only when it contradicts the spec, and then say so.
- E2e tests (per-app `*.e2e.test.ts`, Playwright in `apps/web` and `tests/system-e2e`,
  `npm run test:e2e`) run only in the main agent: several running stacks at once overload the
  machine. Subagents never run them; they list the e2e files and the main agent runs those.
- The `spec-flow:test-case-reviewer` subagent gets only test file paths or an area (app or package
  and test level), never your reasoning. Add the missing cases it reports, or tell the user why a
  case does not belong there.
- With `TDD_STRICT=1` in `.claude/flow.conf`, a hook blocks edits to source files until a test file
  has changed on the branch.

## Checks

No hook runs the checks: they are part of the work, at three moments. Turborepo replays the result
of a check whose inputs did not change, so rerunning one is cheap.

1. While writing: the test you just wrote and `npx vitest related --run --exclude
   '**/*.int.test.ts' --exclude '**/*.e2e.test.ts' <the files you changed>`. Nothing else, never
   the whole suite.
2. End of a task group, before its commit:
   - `npm run check` (typecheck, lint, unit tests);
   - the `spec-flow:test-case-reviewer` subagent (Sonnet, its default) in the foreground on the test
     files the group wrote or changed.
3. End of a change, before `/spec-flow:archive`. The reviews come first and the slow checks last, so
   the slow checks run once, on the final code:
   - in one message (both only read): the `spec-flow:test-case-reviewer` subagent on Opus
     (`model: "opus"` on the Agent call), one call per test area the branch touched
     (`git diff --name-only <MAIN_BRANCH>...HEAD`), each over its whole area, and the
     `spec-flow:change-verifier` subagent on the change;
   - act on every report and commit the fixes (their own commit), then call the verifier again until
     it returns PASS. A hook records its verdict and the commit; no agent writes `.verdict`. A re-run
     checks only the listed gaps and the diff since that commit, so it is short;
   - then `npm run check:full` (adds integration tests) and `npm run test:e2e`. If one fails: fix
     it, commit, rerun what failed, and call the verifier once more.

   A hook denies the archive without a PASS on the current commit, or with uncommitted changes
   outside `openspec/`.

Small work, before `spec-flow:finish`, is lighter. A fix: `npm run check`, the Sonnet test review of
the test files it changed, and the e2e of the workspaces it touched
(`npm run test:e2e -- --filter=<workspace>`). A docs-only branch: nothing.

## Asking

- Ask through the AskUserQuestion tool, never as a plain-text list in chat. Batch related questions:
  up to 4 per call, blocking questions first. Each has 2-4 prepared options (recommended first);
  single choice by default, multiSelect when several answers can apply together.
- After each call write the answers into the change's `brief.md` and append each decision with
  its reason to `decisions.md`.
- A new library is the user's choice. Collect the candidates with their usage and fit (weekly
  downloads, latest version and its date, types, module format, the features the task needs), let
  the user choose, name it under "New" in the brief, and log the numbers and the reason.
- Next steps: when a step ends and the next one is a command (`/spec-flow:apply <change>`,
  `/spec-flow:archive <change>`, a commit...), offer the likely next steps as options and run the
  one the user picks yourself (skills through the Skill tool).
