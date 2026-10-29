# Spec-driven flow for Claude Code + OpenSpec

A Claude Code plugin plus a project template for spec-driven development with OpenSpec: decisions come
from the user, specs are gated until the user approves them, and hooks plus an independent verifier
subagent enforce the loop. This README is not copied into the project.

The repo has two parts:

- `plugin/` is the `spec-flow` Claude Code plugin: the hooks, the `change-verifier` agent and the skills.
  `.claude-plugin/marketplace.json` makes this repo its marketplace, so projects get updates by
  version instead of copies.
- `template/` holds the project files: `CLAUDE.md`, `.claude/flow.conf`, `.claude/settings.json` (enables
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
| `.claude/flow.conf` | branch, check commands, linter, dependency install (npm/eslint by default; an empty value disables the check) |
| `CLAUDE.md` | `TODO` blocks: project description, commands, architecture |
| `openspec/config.yaml` | `context`: what the product is and the stack |
| `docs/concept.md` | the overall idea |
| `.github/workflows/checks.yml` | the same checks as `CHECK_CMDS`, for CI; pin the plugin ref |

Then start with the `spec-flow:roadmap` skill: it turns `docs/concept.md` into `docs/roadmap/`, one file
per milestone with the ordered changes to propose.

Requires: `git`, `python3`, `claude`, OpenSpec CLI (`npm i -g @fission-ai/openspec`). Do not run
`openspec init --tools claude` in the project: its stock skills would contradict the plugin's.

Updating: the plugin updates through `claude plugin update`. The schema in
`openspec/schemas/spec-flow/` belongs to the project; refresh it with `./install.sh <dir> --force`
(which also overwrites the other template files) or copy it by hand.

## What's inside

- **Schema**: `openspec/schemas/spec-flow/` puts `decisions.md` and the user's approval into the
  OpenSpec artifact graph: proposal → decisions → approval → specs, design → tasks. `openspec status`
  itself shows specs as blocked until the user approves, so the skills and the CLI agree on the order.
- **Decisions**: `decisions.md` has Decided (only what the user said), Assumed (minor defaults the agent
  proposes and the user confirms in one batch) and Open questions. The verifier traces every
  requirement to Decided.
- **Approval only from the user**: the `approve.sh` hook writes `.decisions-approved` when the user types
  `/spec-flow:specs-go <change>` or picks "Approve decisions" in AskUserQuestion, and only when nothing
  in `decisions.md` is unchecked.
- **Protected files**: `gate-files.sh` blocks specs, design and tasks before approval, and blocks any
  agent from writing the state files (`.decisions-approved`, `.verdict`, ...), through Write/Edit and
  through Bash.
- **Verifier**: `change-verifier` (Opus, read-only) checks the code against specs and decisions. A
  SubagentStop hook records its verdict from its final message, so the main agent cannot write a PASS.
  The Stop hook keeps the main agent working until a fresh PASS exists.
- **Hooks**: lint on every edit, an "English only" check outside `locales/` (with `LANGUAGE_IGNORE` and
  `allow-non-english` for exceptions), full checks on Stop.
- **TDD**: every spec scenario gets a test that is written and seen failing first. `TDD_STRICT=1` turns
  on `tdd-guard.sh`, which blocks source edits until a test has changed on the branch (in parallel
  worktrees too).
- **Small fixes**: bug fixes that add no behaviour skip OpenSpec but keep the branch and the test first.
- **Git**: `guard-git.sh` makes Claude Code ask before any commit, push, merge, rebase, reset or
  `gh pr merge`; each change is built on its own branch, never on the main branch.
- **Skills** (`/spec-flow:<name>`): `explore`, `propose`, `specs-go`, `apply`, `update`, `sync`,
  `archive` (OpenSpec workflows adapted to the flow), `roadmap`, `ui-from-screenshots` (builds UI from
  screenshots and checks the result by screenshotting the running app), `work-on` (one task group in a
  worktree).
- **Parallel work**: sequential by default. If `tasks.md` has independent groups, the user decides
  whether to run them in parallel; then Claude runs one subagent per group in its own worktree and
  brings the results into the change branch.
- **GitHub**: a CI workflow with the same checks and a PR template that links the change, the roadmap
  item and the verifier verdict.

## Developing the plugin

```bash
claude plugin validate plugin --strict
claude --plugin-dir ./plugin          # try it in a session without installing
```
