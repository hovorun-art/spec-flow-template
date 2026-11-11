---
name: explore
description: Think a problem through with the user before or during a change - investigate the code and the specs, compare options, clarify requirements - without writing code. Use when the user wants to explore an idea, is not sure what to build, or asks to think something over.
argument-hint: <topic or change-name>
allowed-tools: Bash(openspec:*)
---

Explore `$ARGUMENTS` with the user. This is thinking, not building: read, search and run read-only
commands freely, but write no code and no files. When the user asks to implement, say that the work
starts with `spec-flow:start`.

**How to be useful**
- Look before you ask. Read the relevant code, tests, config, `docs/` and specs
  (`openspec list --specs`, then `openspec show "<spec-id>" --type spec`), and do not ask the user
  for facts you can check. Say what you found in a few lines.
- Follow the conversation. No fixed interview and no required output: the user may pause, change
  direction or leave a question open.
- Resolve the blocking question first: the outcome and the scope before an API or a data model.
  When an early answer changes, revisit what depended on it.
- When the evidence supports one option, recommend it and say why, with the alternative and its
  cost. Do not invent the user's priorities: ask.
- Ask through AskUserQuestion (see "Asking" in CLAUDE.md). Silence is not agreement, and accepting
  a recommendation is not permission to write files.
- Keep it short: options as a small table or a few lines each, a diagram only when the structure
  is the question.

**Keeping what was decided**
- Before a change exists, the decisions live in the conversation. Nothing is written on the main
  branch (a hook denies it).
- In a change's session, offer to record what was settled: in `brief.md` (Product, Technical, or
  "To confirm" for what is still open) with the reason appended to `decisions.md`. Write only
  after the user says yes; an edit of an approved brief needs a new approval.

**Ending**
When the user has enough clarity, summarise in a few lines: what was decided, what is still open.
Then offer the next step with AskUserQuestion:
- no change yet: the `spec-flow:start` skill, which creates the branch or the worktree and prepares
  the `/spec-flow:propose <name>: <summary>` message with what was discussed here;
- inside a change: `/spec-flow:update <name>` to fold the outcome into the plan.
