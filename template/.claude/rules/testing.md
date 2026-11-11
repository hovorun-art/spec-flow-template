---
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "apps/*/test/**"
  - "tests/**"
---

# Writing tests

The order of work (test first, when the checks and reviews run, who runs e2e) is in `CLAUDE.md`
("Testing", "Checks"). This file is how a test is written.

## Readable first

Tests are the main way the result is checked, by the user and by the reviewers, so a test must be
understood in one read, without opening other files.

- The name says the behaviour (the scenario's name), and the body shows three things in order: the
  setup, the one action, the expected result. Separate them with a blank line.
- One behaviour per test. A second action or an unrelated assertion is a second test.
- Show in the test what matters for it: the input that triggers the case and the expected value,
  as literals. Hide what does not matter behind a small builder or helper with a telling name
  (`aJob({ status: 'failed' })`), reused across the file or taken from `tests/support`.
- No logic in tests: no loops, conditions or computed expectations. A table of cases
  (`it.each`) is fine when the rows read as a table.
- Expected values are written out, never derived by the same code that is under test.
- Short beats complete: do not assert everything you can, assert what the scenario promises.

## Rules

- One test file per source file (`random.ts` → `random.test.ts`), next to it; no grab-bag test
  files. Test behaviour, not language facts: no tests that a token is a `symbol` or that a constant
  exists.
- Name the test after the spec scenario it covers; it sets up the scenario's WHEN and asserts its THEN.
- Deterministic: time, randomness and I/O come in through injected ports (`Clock`, `Random`,
  `Sleeper` from `packages/kernel`); time with Vitest's own tools (`vi.useFakeTimers()`,
  `vi.setSystemTime()`).
- Backend unit tests mock a class's dependencies with `mockDeep<Port>()` from `vitest-mock-extended`
  and pass them as its `d: <Class>Deps` object. Stub each expected call with the `...Once` forms
  (`mockResolvedValueOnce`, `mockRejectedValueOnce`, `mockReturnValueOnce`,
  `mockImplementationOnce`), never the persistent ones, so an unexpected extra call gets nothing and
  fails. No shared fake packages, and no tests for test doubles.
- Test data never comes from our own app code (e.g. the kernel `Random`): ids and other generated
  values come from Node directly (`randomUUID()` from `node:crypto`), held in a named constant when a
  test compares the same value twice; no hardcoded UUID literals.

## Levels

Each case is tested once, at the lowest level that can observe it.

- **Unit** (Vitest): `*.test.ts` / `*.test.tsx` next to the source file.
- **Integration** (Vitest): `*.int.test.ts` next to an `infra/` adapter, one adapter against its real
  dependency (e.g. started in a Testcontainer). Run with `npm run check:full`, not at each task group.
- **Per-app backend e2e** (Vitest): `apps/<service>/test/e2e/*.e2e.test.ts`, one file per spec area,
  plus exactly one shared `<service>-under-test.ts` (one class: starts the app, holds the shared
  HTTP calls, error-body checks and seeding; no fixture or fake-service classes).
  - The app's own storage is real: a fresh instance per file, migrated with the app's own
    migrations and emptied before each test.
  - Everything outside the app is mocked at its domain port with `mockDeep<Port>()` (other
    services' clients, brokers, caches), swapped in for the port's DI token where the app is
    wired, and reset with `mockReset` before each test.
  - Build the config with the app's own config parser, start the app the way its bootstrap does
    (never a copy of its setup), listen on port 0 at `127.0.0.1`, and call the routes with `fetch`.
  - Drive the app only through its HTTP API; data in a state no route can create is stored
    through the app's own repository, taken from the DI container by its token. Assert on HTTP
    responses (parsed with the contract schemas) and on the calls the mocks received. No probe
    routes: an unexpected failure is a real provider made to throw once
    (`vi.spyOn(provider, 'method').mockRejectedValueOnce(...)`).
  - These tests are cached by Turborepo, so they must depend on nothing but the code.
- **Contract checks** through the shared Zod schemas in `packages/contracts` (no Pact).
- **Web e2e** (Playwright) in `apps/web`, and **system e2e** (`tests/system-e2e`, Playwright) against
  the whole system running together.
