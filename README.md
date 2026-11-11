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

Each rule lives in one file; this is the map, not a second copy.

| Part | What it does | Where |
|---|---|---|
| Schema | brief → the user's approval → specs → tasks, in the OpenSpec artifact graph, so `openspec status` shows specs as blocked until the user approves | `template/openspec/schemas/spec-flow/schema.yaml` |
| Brief and decision log | `brief.md` is the one page the user reads and approves (a product cut and a technical cut); `decisions.md` is the append-only log of why. Specs and tasks are for the agents | the schema's `brief` instruction |
| Approval | Only the user approves: by typing `/spec-flow:specs-go <change>` or picking "Approve the brief". Editing the brief afterwards voids it | `plugin/scripts/approve.sh` |
| Protected files | Specs and tasks are blocked before approval; no agent writes `.decisions-approved` or `.verdict`; archive needs the verifier's PASS on the current commit | `plugin/scripts/gate-files.sh` |
| Verifier | A read-only Opus subagent checks the code against the specs and the brief; a hook records its verdict and the commit, so the main agent cannot write a PASS | `plugin/agents/change-verifier.md`, `plugin/scripts/verifier-hooks.sh` |
| Test review | A read-only subagent looks for missing corner cases, weak assertions and tests at the wrong level: per task group, and over each touched area before archive | `plugin/agents/test-case-reviewer.md` |
| Checks | Run by the agent at three moments (while writing, per task group, before archive), cached by Turborepo across worktrees. No hook runs them | "Checks" in `template/CLAUDE.md`, `template/.claude/rules/tooling.md` |
| Test first | Every scenario gets a test that is seen failing first; `TDD_STRICT=1` blocks source edits until a test has changed on the branch | "Testing" in `template/CLAUDE.md`, `plugin/scripts/tdd-guard.sh` |
| Main branch | Nothing is edited or committed on it; small work gets `fix/<name>` or `docs/<name>`, a change gets its own worktree and session | `plugin/scripts/guard-main.sh`, `plugin/skills/start` |
| Git | Commits and pushes of a work branch need no approval; merges, history rewrites and pushes to the main branch ask the user | `plugin/scripts/guard-git.sh`, `plugin/skills/finish` |
| Language | English only outside the translation files, checked on every edit and in CI | `plugin/scripts/check-language.sh` |
| Parallel groups | Only when the user chooses it: one subagent per task group in its own worktree, cherry-picked onto the change branch | `plugin/skills/apply`, `plugin/skills/work-on` |
| GitHub | A CI workflow with the same checks, and a PR template that links the change and the verdict | `template/.github/` |

Skills (`/spec-flow:<name>`), all written for this flow: `roadmap`, `start`, `explore`, `propose`,
`specs-go`, `update`, `apply`, `work-on`, `archive`, `finish`, `ui-from-screenshots`.

## Developing the plugin

```bash
claude plugin validate plugin --strict
claude --plugin-dir ./plugin          # try it in a session without installing
for t in plugin/scripts/tests/*.test.sh; do bash "$t"; done   # hook tests
```
