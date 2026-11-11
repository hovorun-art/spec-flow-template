---
name: roadmap
description: Optional. Build, update or show a project roadmap (docs/roadmap/, one file per milestone) from docs/concept.md - milestones and the ordered changes to propose. Use only when the user asks for a roadmap, or asks what to build next or where the project stands in a project that already has docs/roadmap/.
---

# Roadmap

The roadmap is an optional planning aid: the flow (`start` → `propose` → `apply` → `archive` →
`finish`) never needs it, and a project without `docs/roadmap/` is complete. Never create one unless
the user asks for it.

It turns the concept into an ordered list of changes, so each `/spec-flow:propose` starts from a
known place instead of from scratch. It decides scope and order only, never behaviour: how each item
works is decided later, inside its own change, through its `brief.md`.

## Layout

- `docs/roadmap/NN-<slug>.md`, one file per milestone; the two-digit prefix sets the order. Separate files
  keep people who plan different milestones out of each other's way.
- Each file: `# Milestone N: <user-visible outcome>`, one line on what a user can do once it is
  done, `## Changes` as a table (`Change`, `Intent` in one line, `Depends on`) and `## Open questions`
  as `- [ ]` items for what the concept does not settle about scope or order.
- No statuses in the files. Status comes from git and OpenSpec, read from the main checkout:
  `openspec/changes/archive/*-<name>/` on the main branch means `done`; otherwise a branch named
  `<name>` (`git branch --list <name>`; a change's branch and worktree carry its name) means
  `in progress`; neither means `planned`. A change's folder exists only on its own branch until it is
  merged, so the main checkout's `openspec/changes/` does not show work in progress.
  So archiving a change never edits the roadmap.

## When

- When the user asks for a roadmap (there is no `docs/roadmap/` yet): build it.
- When the project has one and the user asks what to build next or where the project stands: show the
  status (step 6) and stop there unless they want changes.
- When the project has one and the concept changes, or a milestone needs to be added, split or
  reordered.

## Steps

1. **Read what exists.** `docs/concept.md`, every file in `docs/roadmap/`, `openspec/specs/`, the
   archived changes in `openspec/changes/archive/` and the branches of changes in progress
   (`git branch --list`, `git worktree list`).
2. **Draft milestones.** Each milestone is a user-visible outcome ("a user can ..."), in the order that
   gives something usable earliest. The first milestone is the smallest end-to-end slice.
3. **Split into changes.** Each change adds one capability, is small enough to review in one sitting and
   has a kebab-case name, unique across the roadmap (the future change and branch name). Note what each
   one depends on, also across milestones.
4. **Ask.** Scope, order and cuts are the user's call. Put the milestones and the doubtful items to the user
   with AskUserQuestion (see "Asking" in CLAUDE.md):
   what is in the first milestone, what can wait, which order. Anything the concept does not settle stays
   an open question in that milestone's file, not an assumption.
5. **Write the files** (English) on a `docs/roadmap` branch, never on the main branch (a hook denies
   it): run the `spec-flow:start` skill first if you are still on it. Follow "Layout". Edit only the
   milestones that change; to insert a milestone between two others, pick a free number or renumber
   only when the user agrees.
6. **Show the status.** One compact block: per milestone, its changes with the status derived as
   "Layout" says, and the next candidates (`planned` changes whose dependencies are `done`).
7. **Offer the next step.** Through AskUserQuestion. After writing: commit and the `spec-flow:finish`
   skill, since a change's worktree starts from the main branch and sees the roadmap only once it is
   merged. Otherwise: the `spec-flow:start` skill for a next candidate, or other options that fit.

## Rules

- No requirements, numbers or behaviour in the roadmap: one line of intent per change.
- Never write statuses into the files.
- Never reorder, move or drop items on your own; propose it and ask.
