---
paths:
  - "package.json"
  - "**/package.json"
  - "turbo.json"
  - "tooling/**"
  - ".github/workflows/**"
---

# Scripts, tasks and the Turborepo cache

<!-- TODO: keep in sync with the root and workspace package.json scripts -->
Root `package.json` (with a `packageManager` field, which Turborepo requires):
```json
"check":      "TURBO_CACHE_DIR=\"$(git rev-parse --path-format=absolute --git-common-dir)/turbo-cache\" turbo run typecheck lint test:unit",
"check:full": "TURBO_CACHE_DIR=\"$(git rev-parse --path-format=absolute --git-common-dir)/turbo-cache\" turbo run typecheck lint test:unit test:integration",
"test:e2e":   "TURBO_CACHE_DIR=\"$(git rev-parse --path-format=absolute --git-common-dir)/turbo-cache\" turbo run test:e2e test:e2e:ui --concurrency=1"
```

Each workspace defines the tasks it has: `typecheck` (`tsc --noEmit`), `lint` (`eslint . --cache
--max-warnings 0`), `test:unit`, `test:integration` (Vitest projects `<app>:unit`,
`<app>:integration`), `test:e2e` (a backend app's Vitest e2e), `test:e2e:ui` (Playwright: `apps/web`
and `tests/system-e2e`), `build`, `dev`.

- Turborepo (`turbo.json`) caches a task by a hash of its inputs: the workspace's files, the
  workspaces it depends on, the root configs (`globalDependencies`) and the locked packages. An
  unchanged workspace gets its result replayed instead of running again.
- The cache lives in the repository's shared git directory, so every worktree of the project
  reuses it. A new root config that changes results must be added to `globalDependencies`.
- `test:e2e` is cached because a backend app's e2e depends only on the code (fresh storage per
  file, everything outside mocked). `test:e2e:ui` is never cached.
- E2e runs one workspace at a time (`--concurrency=1`). One workspace only:
  `npm run test:e2e -- --filter=<workspace>`.
- A new kind of check becomes a task in `turbo.json` and joins `check` or `check:full`; the CI
  workflow runs the same root scripts.
