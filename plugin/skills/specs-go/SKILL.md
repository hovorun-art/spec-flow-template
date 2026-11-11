---
name: specs-go
description: Approve the brief of an OpenSpec change and write its specs and tasks. Typed by the user as /spec-flow:specs-go <change>; also run after the user picks "Approve the brief" to continue the change. Resolves anything still open in brief.md first.
argument-hint: <change-name>
---

The user wants the open points of change `$ARGUMENTS` settled and the specs written. Approval itself
is recorded by a hook, never by you: when the user typed this command, or picked "Approve the brief"
in AskUserQuestion, the hook creates `openspec/changes/$ARGUMENTS/.decisions-approved` if `brief.md`
has no unchecked item left, and tells you the result.

1. Read `openspec/changes/$ARGUMENTS/brief.md`. If it does not exist, stop and say so.
2. If the hook reported the approval, go to step 5.
3. Otherwise resolve every item under "To confirm" with AskUserQuestion (see "Asking" in CLAUDE.md).
   If the user shared screenshots for this change, run the `spec-flow:ui-from-screenshots` skill first.
   - Questions first, in batches of up to 4, with "Drop this question" as one option.
   - Then all assumptions in one multiSelect question: the user keeps what they accept.
   After each call, write the answer into Product or Technical, delete the item, and append the
   decision with its reason to `decisions.md`; a rejected assumption becomes a question.
4. Show the brief in chat (it is short: the whole file), then ask one question that names the change,
   for example "Approve the brief of `$ARGUMENTS`?", with the options "Approve the brief" (first) and
   "Not yet". The hook records the approval. If the user does not approve, stop. Never create
   `.decisions-approved` yourself; writing it is blocked.
5. Continue the `spec-flow:propose` workflow for this change from the next `ready` artifact: specs,
   then tasks. Every requirement must trace to a line under "Behaviour" in the brief. If while
   writing you hit something the brief does not settle, stop, add it to "To confirm", ask, and get
   approval again (the hook re-checks brief.md); never fill the gap with an assumption.
