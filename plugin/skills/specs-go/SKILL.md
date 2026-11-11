---
name: specs-go
description: Approve the brief of an OpenSpec change and write its specs and tasks. Typed by the user as /spec-flow:specs-go <change>; also run after the user picks "Approve the brief" to continue the change. Resolves anything still open in brief.md first.
argument-hint: <change-name>
---

The user wants the open points of change `$ARGUMENTS` settled and the specs written. Approval itself
is recorded by a hook, never by you: when the user typed this command, or picked "Approve the brief"
in AskUserQuestion, the hook creates `openspec/changes/$ARGUMENTS/.decisions-approved` if `brief.md`
has no unchecked item left, and tells you the result. Never create that file yourself; writing it
is blocked.

1. Read `openspec/changes/$ARGUMENTS/brief.md`. If it does not exist, stop and say so.
2. If the hook did not report the approval, something is still open. If the user shared screenshots
   for this change, run the `spec-flow:ui-from-screenshots` skill first.
3. Continue step 4 of the `spec-flow:propose` skill for this change from its next `ready` artifact
   (`openspec status --change "$ARGUMENTS" --json`): **approval** when the brief is not approved
   yet, otherwise **specs**, then **tasks**; then its steps 5 to 7.
