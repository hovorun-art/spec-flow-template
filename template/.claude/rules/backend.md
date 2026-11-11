---
paths:
  - "apps/*/src/{domain,infra,app}/**"
  - "apps/*/src/main.ts"
  - "apps/*/test/**"
  - "packages/{kernel,service-kit,contracts}/**"
---

# Backend code (DDD + onion, OOP)

These rules apply to `apps/<service>`, `packages/kernel` and `packages/service-kit`. They never apply
to `apps/web` (see `.claude/rules/web.md`): do not force layers, classes, interface-plus-implementation
pairs or DI onto React.

## Layers

Every service's `src/` has exactly `domain/`, `infra/` and `app/` (plus `main.ts`). Features go inside
each layer as subfolders (`domain/health/`, `infra/health/`, `app/health/`), with deeper subfolders
when they divide the code logically (`infra/health/http/`).
- `domain/`: only what is not implemented: interfaces (ports and use cases) with their
  Request/Response types and DI token, value types, and domain errors. No classes with logic, no
  framework, database driver or logger imports.
- `infra/`: every implementation of a `domain/` interface: use-case logic and adapters (database,
  cache, queue and HTTP clients, the logger).
- `app/`: the server framework's entry points (routes or controllers, guards, error mapping,
  lifecycle hooks) and the wiring (`app/app.module.ts`, `app/<feature>/<feature>.module.ts`, or the
  framework's equivalent); entry points call `domain/` interfaces through DI tokens.

Dependencies: `domain/` imports only `packages/kernel`, contract types and other `domain/` files;
`infra/` imports `domain/`, `infra/`, kernel and contracts; `app/` imports `domain/`, kernel and
contracts, and only `*.module.ts` files import `infra/` to wire it. ESLint
(`eslint-plugin-boundaries`) enforces it.

## Classes

- Interfaces first: every class implements an interface (from `domain/`, the kernel, or a framework
  interface). No standalone classes. Bound to their interface through DI with a `Symbol` token.
- No free functions: all logic lives in class methods. A helper used by one class is a `private`
  method of it. Exempt: `main.ts` and configuration files.
- Constructors take at most two objects: `d: <Class>Deps` (collaborators: ports, clients, loggers)
  and, when the class needs configuration, `p: <Class>Params` (values and options), always with
  named properties, never positional values:
  `constructor(private readonly d: HeartbeatLoopImplDeps, private readonly p: HeartbeatLoopImplParams)`.
  A class with only data (an error) takes just `p`. The wiring builds both in factories. Exempt:
  classes the framework instantiates itself (controllers, guards, filters, hooks).
- Every public method that has inputs takes one request object and returns one response object (or
  a Promise of it), named `<Method><Interface>Request` / `<Method><Interface>Response`, e.g.
  `HeartbeatLoop.run(req: RunHeartbeatLoopRequest): Promise<RunHeartbeatLoopResponse>`. A method
  without inputs takes no parameter at all: `clock.now()` returns `NowClockResponse`. Applies to
  kernel ports too. Exempt: framework-owned signatures (`canActivate`, `catch`, controller handlers
  returning contract types).
- Implementation names: `<Tech><Interface>` when a technology or strategy distinguishes it
  (`HttpPaymentGateway`, `SqlOrderRepository`); `<Interface>Impl` only when there is nothing
  meaningful to distinguish it by yet. File names follow the class (`http-payment-gateway.ts`,
  `heartbeat-loop.impl.ts`). Test fakes: `Fake<Interface>`.
- Features use each other only through `domain/` interfaces and their DI tokens, never another
  feature's `infra/` class. Calls between features must work if the other side later becomes a
  remote service: plain data in and out (contract types), no shared entities, no shared transactions.
- Name things after the domain, not after technical roles (processor, manager, helper, utils).

## Services and shared code

- Each service owns its data: only it touches its tables; others read through its HTTP API. Apps
  never import each other's code; they talk over HTTP.
- No logic is written twice: framework-free shared code goes to `packages/kernel`, framework-bound
  shared code to `packages/service-kit`; apps add their own parts through params.
- Time, randomness and sleeping come in through injected ports (`Clock`, `Random`, `Sleeper` from
  `packages/kernel`), so the logic tests deterministically.
- Health checks report only their own process, never related services.
- Structured JSON logging through a logger port (<!-- TODO: the logger library -->).

## Validation and contracts

Every request, message and response body has a Zod schema in `packages/contracts`; types are inferred
from the schemas (`z.infer`), never written twice. Input is validated at the edge (HTTP handlers and
message consumers); inner layers trust their types.

## Errors

Our own error classes extending `DomainError`, each with a stable `code` from the closed list
`ERROR_CODES` in `packages/kernel` (a code outside it does not compile; contracts build the
`ErrorCode` schema from the same list), plus structured `details`. A new failure adds its code to
`ERROR_CODES` first, and its HTTP status to the filter's table (in service-kit). Code handles errors
by class or `code`, never by message text. `domain/` interfaces declare these errors and `infra/`
code throws them; one exception filter per app maps codes to HTTP status and a uniform body (`code`,
`message`, `details`). Never throw strings or bare `Error` for expected failures; unknown errors are
logged and returned as a generic 500.
