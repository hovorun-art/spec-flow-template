---
name: propose
description: Plan a change - write the one-page brief (a product cut and a technical cut) from the conversation, settle every open point with the user, and after the user approves the brief write the specs and the task list. Use when the user describes something to build, names a roadmap item, or says "propose".
argument-hint: <change-name>[: <summary of what was discussed>]
allowed-tools: Bash(openspec:*)
---

Plan change `$ARGUMENTS`: brief → the user's approval → specs → tasks. Planning only: no project
code is edited here, and implementation starts only when the user asks for `/spec-flow:apply`.

1. **Where.** Planning happens in the change's own worktree, on its branch. If
   `git branch --show-current` is the main branch (`MAIN_BRANCH` in `.claude/flow.conf`), write
   nothing and run the `spec-flow:start` skill instead: a hook denies every write there.

2. **Understand.** The name is kebab-case; the text after the colon is what was already discussed.
   If it is not clear what to build, ask. Before writing, look at what exists, read-only and in
   proportion to the change:
   - `openspec list --specs`, then `openspec show "<spec-id>" --type spec` for each related spec;
   - the code, tests and config the change will touch, and the `.claude/rules/` files that cover them.
   What you find goes into the brief's "Technical" section (what is reused, what is new); a conflict
   with an existing spec is a question for the user, not your call.

3. **Create the change.** `openspec new change "<name>"`. If it already exists, ask whether to
   continue it.

4. **Write the artifacts in order.** Repeat until every artifact is `done`:
   - `openspec status --change "<name>" --json` gives each artifact's status; take the next `ready` one.
   - `openspec instructions <artifact-id> --change "<name>" --json` gives its `instruction`,
     `template` and `resolvedOutputPath`. Follow the instruction: it is the rule for that artifact.
     `context` and `rules` there are constraints for you, never text for the file. Re-read the
     artifacts it depends on from disk, not from memory.
   - **brief**: write `brief.md`, and `decisions.md` next to it with one line per decision made so
     far and its reason.
   - **approval**: never write it. Settle every item under "To confirm" and offer approval the
     way the brief instruction says (the order of the questions, the exact "Approve the brief"
     label). A hook records the approval. If the user does not approve, stop and say what is
     still open.
   - **specs**, then **tasks**: only after the hook reported the approval. If something the brief
     does not settle comes up, stop, add it to "To confirm", ask, and get the brief approved again.

5. **Check.** `openspec validate "<name>" --strict`; fix what it reports.

6. **Commit** the planning on the change branch: `brief.md`, `decisions.md`, `.decisions-approved`,
   `specs/`, `tasks.md`. The marker must be in the commit: the hooks read it in every worktree of
   the change.

7. **Report.** The user reads only the brief, so do not retell the specs or the tasks: give the
   brief's path, one line with the number of scenarios and task groups, and the commit. Then offer
   the next step with AskUserQuestion: `/spec-flow:apply <name>`.
