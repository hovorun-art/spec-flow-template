# Spec-driven flow for Claude Code + OpenSpec

A project template for spec-driven development with Claude Code and OpenSpec: decisions come from the
user, specs are gated until approved, and hooks plus a verifier subagent enforce the loop.
This README is not copied into the project.

## Installation

```bash
./install.sh <project-dir>          # leaves existing files untouched
./install.sh <project-dir> --force  # overwrite
```

Then fill in:

| File | What to fill in |
|---|---|
| `.claude/flow.conf` | branch, check commands, linter, dependency install (npm/eslint by default; an empty value disables the check) |
| `CLAUDE.md` | `TODO` blocks: project description, commands, architecture |
| `openspec/config.yaml` | `context`: what the product is and the stack |
| `docs/concept.md` | the overall idea |
| `.github/workflows/checks.yml` | the same checks as `CHECK_CMDS`, for CI |

Then start with the `roadmap` skill: it turns `docs/concept.md` into `docs/roadmap/`, one file per
milestone with the ordered changes to propose.

Requires: `git`, `python3`, `claude`, OpenSpec CLI (`npm i -g @fission-ai/openspec`).

## What's inside

- **Roadmap**: the `roadmap` skill plans milestones and changes at the start, one file per milestone in
  `docs/roadmap/` so collaborators rarely conflict. Statuses are not stored: they come from
  `openspec/changes/`, so archiving a change never touches the roadmap.
- **Gate before specs**: `gate-specs.sh` blocks `specs/`, `design.md`, `tasks.md` until `/specs-go`.
  First comes `decisions.md` (Decided / Open questions) and questions via AskUserQuestion.
- **Hooks**: lint on every edit, an "English only" check outside `locales/`, full checks on Stop,
  then a mandatory PASS from `change-verifier` (an Opus subagent that checks the code against the specs and `decisions.md`).
- **TDD**: every spec scenario gets a test that is written and seen failing first; the verifier
  treats a scenario without a real test as a gap. `TDD_STRICT=1` turns on `tdd-guard.sh`, which blocks
  source edits until a test has changed on the branch.
- **Small fixes**: bug fixes that add no behaviour skip OpenSpec but keep the branch and the test first.
- **Git**: `guard-git.sh` makes Claude Code ask before any commit, push, merge, rebase or reset;
  each change is built on its own branch, never on the main branch.
- **Commands**: `/opsx:*` (OpenSpec with additions for decisions), `/specs-go`, `/work-on`.
- **Skill** `ui-from-screenshots`: builds UI from screenshots or mockups, asks about states and sizes the
  picture does not show, and checks the result by screenshotting the running app.
- **Parallel work**: sequential by default. If `tasks.md` has independent groups, the user decides
  whether to run them in parallel; then Claude runs one subagent per group in its own worktree and
  brings the results into the change branch.
- **GitHub**: a CI workflow with the same checks and a PR template that links the change, the roadmap
  item and the verifier verdict.
