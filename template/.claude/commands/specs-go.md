---
description: Approve the decisions of a change so specs, design and tasks may be written
argument-hint: <change-name>
---

The user is explicitly saying that the questions are settled and it is time to write the specs
for change `$ARGUMENTS`. This command is the only way the gate is opened.

1. Read `openspec/changes/$ARGUMENTS/decisions.md`. If it does not exist, stop and say so.
2. If any item under "Open questions" is still unchecked (`- [ ]`), do not open the gate. If the user shared
   screenshots for this change, run the `ui-from-screenshots` skill first. Ask them
   with the AskUserQuestion tool in batches of up to 4 (prepared options plus Other, single or multi
   select; offer "Drop this question" as an option), record the answers in `decisions.md`, and open
   the gate only when none is left unchecked.
3. Show the user the list of decisions in one compact block and ask nothing else.
4. Create the marker: `touch openspec/changes/$ARGUMENTS/.decisions-approved`.
5. Continue the propose workflow: write specs, then design, then tasks. Every requirement in the
   specs must trace to a line in "Decided". If while writing you hit something that is not
   decided, stop, add it to "Open questions" and ask; never fill the gap with an assumption.
