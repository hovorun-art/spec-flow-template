# Spec-driven flow for Claude Code + OpenSpec

A Claude Code plugin plus a project template for spec-driven development with OpenSpec: decisions come
from the user, specs are gated until the user approves them, and hooks plus an independent verifier
subagent enforce the loop. The template targets a TypeScript monorepo: backend services on Node
(DDD, onion layers `domain/infra/app`, interface-first classes; the framework and database are the
project's choice), a functional React web app, and shared `kernel`, `contracts` (Zod) and
`service-kit` packages, tested with Vitest and Playwright.
This README is not copied into the project.

The repo has two parts:

- `plugin/` is the `spec-flow` Claude Code plugin: the hooks, the `change-verifier` agent and the skills.
  `.claude-plugin/marketplace.json` makes this repo its marketplace, so projects get updates by
  version instead of copies.
- `template/` holds the project files: `CLAUDE.md` (the flow, kept short), `.claude/rules/` (code, test
  and tooling rules that load only when a matching file is read), `.claude/flow.conf`, `.claude/settings.json` (enables
  the plugin), the OpenSpec `spec-flow` schema and config, `docs/`, and the GitHub workflow and PR template.

## Installation

```bash
./install.sh <project-dir>          # leaves existing files untouched
./install.sh <project-dir> --force  # overwrite
```

The project's `.claude/settings.json` declares the marketplace and enables `spec-flow@spec-flow`;
Claude Code offers to install it once you trust the folder. By hand:

```bash
claude plugin marketplace add hovorun-art/spec-flow-template   # or a local path to this repo
claude plugin install spec-flow@spec-flow
```

Then fill in:

| File | What to fill in |
|---|---|
| `.claude/flow.conf` | main branch, worktree folder, dependency install, test-first and English-only settings |
| `CLAUDE.md` | `TODO` blocks: project description, services, commands |
| `.claude/rules/*.md` | `TODO` blocks: logger, test and UI libraries; adjust the rules and their `paths` to the project |
| `openspec/config.yaml` | `context`: what the product is and the stack |
| `docs/concept.md` | the overall idea |
| `.github/workflows/checks.yml` | the full checks, for CI; pin the plugin ref |

Then start with the `spec-flow:roadmap` skill: it turns `docs/concept.md` into `docs/roadmap/`, one file
per milestone with the ordered changes to propose.

Requires: `git`, `python3`, `claude`, OpenSpec CLI (`npm i -g @fission-ai/openspec`). Do not run
`openspec init --tools claude` in the project: its stock skills would contradict the plugin's.

Updating: the plugin updates through `claude plugin update`. The schema in
`openspec/schemas/spec-flow/` belongs to the project; refresh it with `./install.sh <dir> --force`
(which also overwrites the other template files) or copy it by hand.

## What's inside

- **Schema**: `openspec/schemas/spec-flow/` puts the brief and the user's approval into the
  OpenSpec artifact graph: brief → approval → specs → tasks (no proposal, no design document). `openspec status`
  itself shows specs as blocked until the user approves, so the skills and the CLI agree on the order.
- **Brief**: `brief.md` is the one page the user reads, about 40 lines, in two cuts. Product: goal,
  behaviour, what is not done. Technical: what is done as usual, what is reused, what is new and why.
  Anything the user has not confirmed sits under "To confirm". Specs (scenarios only) and tasks (one
  line per task, one commit per group) are written for the agents and never restate the brief; the
  scenario name links a brief line, its test and its task. The verifier traces every requirement to
  the brief and reports the result line by line against it.
- **Decision log**: `decisions.md` is appended to, never rewritten: each decision with its reason,
  the options turned down and who decided, plus later changes of the brief and deviations found
  while implementing. It is archived with the change, so a wrong outcome can be traced to its decision.
- **Approval only from the user**: the `approve.sh` hook writes `.decisions-approved` when the user types
  `/spec-flow:specs-go <change>` or picks "Approve the brief" in AskUserQuestion, and only when nothing
  in `brief.md` is unchecked. Editing the brief afterwards voids the approval.
- **Protected files**: `gate-files.sh` blocks specs and tasks before approval, and blocks any
  agent from writing the state files (`.decisions-approved`, `.verdict`, ...), through Write/Edit and
  through Bash.
- **Verifier**: `change-verifier` (Opus, read-only) checks the code against the specs and the brief. A
  SubagentStop hook records its verdict from its final message (or, for a background run, from the
  report it hands back through `SubagentHandback`), so the main agent cannot write a PASS. The hook also records the commit; a re-run checks only the
  listed gaps and the diff since that commit (a full check again if the planning changed). Archive
  needs a PASS on the current commit: `gate-files.sh` denies it otherwise. It also looks
  for duplicated logic.
- **Test review**: `test-case-reviewer` (read-only; Sonnet on the test files of a task group, Opus on
  each whole touched area for the final pass) looks for missing corner
  cases, weak assertions and cases that belong to a lower test level. Every task group that writes
  tests ends with this review, and `apply` runs it even when `tasks.md` has no review task.
- **Checks at three moments, no Stop hook**: while writing, only the related unit tests; before a
  task group's commit, `npm run check` (typecheck, lint, unit tests) plus a Sonnet test review; before
  archive, an Opus test review over the whole branch together with the verifier, fixes until PASS, and
  only then `npm run check:full` (adds integration tests) and e2e, once, on the final code. A fix
  branch gets a lighter set (check, Sonnet review, the e2e of the touched workspaces). Turborepo
  (`turbo.json`) caches each check by the hash of its inputs, per-app backend e2e included (Playwright
  suites always run, one workspace at a time),
  in the git common directory so every worktree shares it: unchanged workspaces are replayed, not rerun. Hooks only check the language of each edited file (English only
  outside `locales/`, with `LANGUAGE_IGNORE` and `allow-non-english` for exceptions).
- **TDD**: every spec scenario gets a test that is written and seen failing first. `TDD_STRICT=1` turns
  on `tdd-guard.sh`, which blocks source edits until a test has changed on the branch (in parallel
  worktrees too).
- **Branches and worktrees**: nothing is edited on the main branch; `guard-main.sh` denies Write/Edit
  there and Bash commands that visibly write into the checkout. The `start` skill puts every piece of
  work on its own branch first: a fix with no visible behaviour change, or an update of the
  instructions and docs, gets `fix/<name>` or `docs/<name>` in the current checkout and skips
  OpenSpec (a fix still starts with a failing test); a change gets its own worktree next to the
  project (`<WORKTREES_DIR>/<project>-<change>`) and its own Claude session there.
- **Git**: `guard-git.sh` allows `git commit` and `git cherry-pick` on any branch but the main one
  (only when the whole command is plain git: anything else chained to it goes through the normal
  permission rules) and denies them on it, also when a `cd` or `git switch -c` earlier in the same command decides the
  branch. Pushing a change branch is allowed; pushing to the main branch, forced or deleting pushes,
  merge, pull, rebase, reset, revert, tag, `commit --amend`, `branch -D`, `clean` and `gh pr merge`
  ask the user. Agents commit each step themselves (planning, each task group, verifier fixes,
  archive); the `finish` skill pushes, opens a PR, or merges only when the user picks it and approves
  the prompt.
- **Tests**: subagents run only the tests related to their changes and never e2e; they list the e2e
  files and the main agent runs them.
- **Skills** (`/spec-flow:<name>`), all written for this flow, none copied from OpenSpec: `start`,
  `finish` (branch or worktree at the start, push/PR/merge and cleanup at the end), `explore`,
  `propose`, `specs-go`, `apply`, `update`, `archive` (the archive itself is `openspec archive`,
  which merges the delta specs into the main specs), `roadmap`, `ui-from-screenshots` (builds UI
  from screenshots and checks the result by screenshotting the running app), `work-on` (one task
  group in a worktree).
- **Parallel work**: sequential by default. If `tasks.md` has independent groups, the user decides
  whether to run them in parallel; then Claude runs one subagent per group in its own worktree (a
  branch off the change branch), each commits its group there, and the main agent cherry-picks the
  commits onto the change branch. Separate changes run in parallel as separate worktrees and sessions.
- **GitHub**: a CI workflow with the same checks and a PR template that links the change, the roadmap
  item and the verifier verdict.

## Developing the plugin

```bash
claude plugin validate plugin --strict
claude --plugin-dir ./plugin          # try it in a session without installing
for t in plugin/scripts/tests/*.test.sh; do bash "$t"; done   # hook tests
```
