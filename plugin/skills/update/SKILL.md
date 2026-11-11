---
name: update
description: Revise the plan of an existing change - the brief first, then the specs and tasks that follow from it. Use when the user wants to change what a planned or half-built change does or how, or to make its artifacts agree with each other. Never edits code.
argument-hint: <change-name>[: <what changes>]
allowed-tools: Bash(openspec:*)
---

Revise the plan of change `$ARGUMENTS`. With no name: use the only active change, or ask
(`openspec list --json`). Planning files only; code is changed by `/spec-flow:apply`.

1. **Read** `brief.md`, `decisions.md`, the delta specs and `tasks.md` of the change
   (`openspec status --change "<name>" --json` lists what exists).

2. **Find what has to change.** Either the revision the user asked for, or, when they only asked to
   tidy up, the places where the artifacts contradict each other, leave a gap, or repeat each other.
   If the request changes the change's intent rather than refining it, propose a new change instead
   (`spec-flow:start`).

3. **The brief first.** Any change of what is built or how is made in `brief.md`, and nowhere else
   first:
   - what the user has not said or confirmed becomes an item under "To confirm"; settle it with
     AskUserQuestion (see "Asking" in CLAUDE.md);
   - append the revision, its reason and what triggered it to `decisions.md`; never rewrite
     earlier lines;
   - editing the brief voids its approval: show the brief and offer "Approve the brief" again. Until
     the hook reports the approval, specs and tasks cannot be written.

4. **Then specs and tasks**, to match the approved brief and each other (for a rewrite, take the
   rules from `openspec instructions <artifact-id> --change "<name>" --json`). Keep finished tasks
   checked only if their work still matches the plan; add tasks for what is new.
   `openspec validate "<name>" --strict`.

5. **Commit** the revised planning with the new `.decisions-approved`, and report what changed in
   one short list. If tasks are already implemented and the plan moved under them, say which, and
   offer `/spec-flow:apply <name>`.
