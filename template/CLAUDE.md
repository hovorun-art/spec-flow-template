# Project

<!-- TODO: one paragraph: what this is, for whom, the core loop or main use case. -->
<What the product is and what it does.> Spec-driven with OpenSpec.
The full concept is in `docs/concept.md` (a source for decisions; each point is decided in a change).

## Language

English only: specs, design, tasks, code, comments, identifiers, UI strings in code, commit
messages and docs. Other languages only inside dedicated translation files (e.g. `locales/`);
text shown to users must come from those files, never be hardcoded in code.
Chat with the user and AskUserQuestion questions/options in Ukrainian; files stay English.

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

1. `/opsx:explore` to clarify, then `/opsx:propose "idea"`. Questions come first: the agent writes
   `decisions.md` ("Decided" = only what the user said, "Open questions" = everything else) and asks
   them all. Specs, design and tasks are written only after the user runs `/specs-go <change>`;
   a PreToolUse hook (`gate-specs.sh`) blocks those files until then. Never invent behaviour.

   Research first: before asking how something with a real-world counterpart should look or behave,
   or when the user shares a reference photo, run the `reference-research` skill: find and look at
   reference photos and facts, save the notes in the change's `research.md`, and build the answer
   options from them. Research only shapes the options; only the user's answers become decisions.

   No numbers in specs: tunable values (speeds, timings, limits, sizes) live in config; they may be
   recorded in `decisions.md`, `design.md`, `tasks.md` and `research.md`, while specs say "the
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
2. Commit the specs, then implement with `/opsx:apply`. For parallel work use one git worktree per
   task group: `claude --worktree <change>-<N>`, then `/work-on <change> <N>`.
3. Hooks enforce the loop (see `.claude/hooks/`, settings in `.claude/flow.conf`): lint on each edit,
   full checks at the end, then the `change-verifier` subagent must return PASS before the work is
   considered done. Run it in the foreground (not `run_in_background`) and wait for it; while it works
   it holds `.verify-running`, and the Stop hook waits instead of counting rounds.
4. `/opsx:archive` after PASS.

Tasks in `tasks.md` are grouped as `## N. Title`; check off only your own group's boxes.

## Models

- Main agent: Opus by default (`"model": "opus"` in `.claude/settings.json`), since most tasks
  are non-trivial (new features, architecture, multi-file).
- For purely routine work (small fixes, renames, boilerplate, docs) switch with `/model sonnet`
  at medium effort.
- `change-verifier`: Opus (set in its frontmatter). A false PASS costs more than the extra tokens.
- Choose by measured cost per task, not by price per token.

## Parallel agents

Plan changes in the main chat (decisions, `/specs-go`, specs, design, tasks), commit them on the main
branch (`MAIN_BRANCH` in `.claude/flow.conf`), then build them in parallel in git worktrees, one agent
per change. The scripts in `scripts/agents/` work for any set of changes: a change takes part when it is
active on the main branch, has `tasks.md` and was approved with `/specs-go` (`.decisions-approved`).

- `scripts/agents/start-agent.sh <change>`: creates or fast-forwards `../<repo>-<change>`, installs
  dependencies and starts `claude "/opsx:apply <change>"` (`CLAUDE_FLAGS` adds flags; one agent per
  worktree, with a confirmation when the worktree already has uncommitted changes).
- `scripts/agents/status.sh`: progress, verdict, position against the main branch, running agents.
- `scripts/agents/merge-all.sh`: merges the finished branches in order, then runs all checks.
- `scripts/agents/gen-tasks.sh`: regenerates `.vscode/tasks.json` (one task per change, "Agents: start all",
  status, merge). Run it after planning new changes.
- Merge order: a change lists the changes it must be merged after in `openspec/changes/<name>/.merge-after`
  (for example a change that edits the entry point lists the others); the rest is ordered by name.
- Rule for parallel changes: each owns its folders (see "Owns" in its `tasks.md`), adds new capabilities
  and does not edit shared files.
