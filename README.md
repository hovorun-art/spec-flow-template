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

Requires: `git`, `python3`, `claude`, OpenSpec CLI (`npm i -g @fission-ai/openspec`).

## What's inside

- **Gate before specs**: `gate-specs.sh` blocks `specs/`, `design.md`, `tasks.md` until `/specs-go`.
  First comes `decisions.md` (Decided / Open questions) and questions via AskUserQuestion.
- **Hooks**: lint on every edit, an "English only" check outside `locales/`, full checks on Stop,
  then a mandatory PASS from `change-verifier` (an Opus subagent that checks the code against the specs and `decisions.md`).
- **TDD**: every spec scenario gets a test that is written and seen failing first; the verifier
  treats a scenario without a real test as a gap.
- **Git**: `guard-git.sh` makes Claude Code ask before any commit, push, merge, rebase or reset;
  each change is built on its own branch, never on the main branch.
- **Commands**: `/opsx:*` (OpenSpec with additions for decisions), `/specs-go`, `/work-on`.
- **Skill** `reference-research`: looks for references before asking how something should look.
- **Parallel work**: sequential by default. If `tasks.md` has independent groups, the user decides
  whether to run them in parallel; then Claude runs one subagent per group in its own worktree and
  brings the results into the change branch.
