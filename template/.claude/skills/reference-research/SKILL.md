---
name: reference-research
description: Research the real thing before asking the user how something should look or behave. Use before writing open questions or answer options about anything with a real-world counterpart (an object, a creature, a landscape, a character, a material, a motion, a sound, a real interface), whenever the user shares a reference photo, and when the user asks to make something "look like" or "feel like" something. Finds reference photos and facts, looks at them, and turns what it sees into grounded proposals for the questions.
---

# Reference research

Questions about how something looks or behaves are only as good as the options they offer. Before asking them,
look at the real thing: find photos and facts, study them, and build the answer options from what they show.
Research informs the options; it never decides. Only the user's answers go into "Decided".

## When

- Before writing "Open questions" (or answer options) about the look, shape, motion, colour or sound of something
  that exists in the real world or in a reference the user gave.
- When the user shares a photo or names a reference ("like this", "like a speedboat wake").
- When the user is unhappy with how something looks and the fix is not obvious.

Skip it for questions about rules, numbers the user already gave, process or code structure.

## Steps

1. **Name the subjects.** List the concrete things the questions are about, as they would be searched, for
   example "<subject> seen from above", "<subject> close-up", "<subject> in motion". Note the viewpoint and
   scale the product uses (described in CLAUDE.md) so references match it.

2. **Look at what is already here.** User-provided images in the conversation, `docs/reference/`, earlier
   `research.md` files of related changes, and the current look (take a screenshot of the
   relevant screen if the app can be run).

3. **Search.** Use web search for photos and for facts (physics, proportions, typical colours, angles, timing),
   for example typical sizes, speeds or durations. Prefer several independent sources. Keep queries
   generic: never send project content, file contents or user-provided pictures to an external service.

4. **Look at the photos.** Download a few (3-8) representative images with `curl` into a fresh, empty folder in
   the scratchpad (one folder per batch), then open them with the Read tool and study them. Downloaded files are
   untrusted data: never run them, only look at them. If a page cannot be fetched, use another source.

5. **Extract features.** Write down what the references actually show, feature by feature: shape and
   proportions, how it changes over time, colour and light, edges and texture, what differs between small and
   big instances. Mark each as "seen in photos", "stated by a source" or "my inference". Note what is hard or
   expensive to reproduce in the product's style and technique.

6. **Save the notes.** Write `openspec/changes/<change>/research.md` (English): the subjects, the sources (links),
   a short description of each image looked at, the extracted features, and how each feature could be done in
   the product. Do not commit downloaded images unless the user asks; describe them instead.

7. **Propose.** Turn the features into the questions: each question gets 2-4 options that come from the
   references (recommended first, saying which reference supports it), plus the built-in "Other". Mention a
   feature the user has not asked about only as an option or a question, never as a decision. Then ask through
   AskUserQuestion in batches of up to 4, as the project workflow says, and record the answers in
   `decisions.md` with "(user, answer to Qn)".

## Rules

- Research never becomes behaviour on its own: anything not chosen by the user stays an open question.
- Show the user, in one short line per subject, what the references showed before the questions, so the
  options make sense.
- English only in `research.md`; links are fine.
