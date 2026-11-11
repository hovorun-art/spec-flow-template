---
paths:
  - "apps/web/**"
---

# Web app (functional React)

- Feature folders (`src/features/<feature>/`), each with its own components, hooks and API calls.
  Components, hooks and plain functions only: no layers, classes, interface-plus-implementation
  pairs or DI (those are backend rules).
- Data through the feature's hooks and API calls, typed with `packages/contracts`; dependencies
  through arguments, props or context. <!-- TODO: server-state library, UI kit, global store (only
  when a real need appears). -->
- Text shown to users comes from the translation files (`locales/`), never hardcoded.
- Unit tests (`*.test.tsx` next to the component) go through what the user sees and does
  (<!-- TODO: library, e.g. @testing-library/react -->); components get their data through their
  feature's hooks and API calls, and the test fakes the network at `fetch`
  (<!-- TODO: library, e.g. MSW -->).
- Web e2e: Playwright in `apps/web` (task `test:e2e:ui`), main agent only.
