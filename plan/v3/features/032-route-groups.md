# Feature 032: Route groups

## Identity and status

- Matrix identity: 32 - Route groups
- Audit state: decision-ready
- Audit note: historical audit 2026-08-01 (Python defects fixed); surface measured from
  four-language source 2026-08-10 and prose completed. No framework code changed.
- Dependencies: Feature 31 router/dispatch, Feature 33 middleware pipeline, the write-auth
  gate (ADR-0049)
- Dependants: every grouped route set; the CLI route listing (renders group prefixes and auth
  markers); Swagger
- Existing ADRs: ADR-0015 (routing surface) and ADR-0019 (routing-surface security intent);
  the middleware-never-opens-a-gate rule (ADR-0049)
- Shared fixtures: `route_groups_contract.json` is required, including a NESTED-group case

- Current state: reopened for a standalone 3.14 audit (was hidden in the 11/12/79 bundle)

## Why this feature exists

A route group lets an engineer apply one prefix and one policy chain to a set of
routes without changing how those routes match or dispatch.

## Boundary

Feature 32 owns deterministic prefix joining, nested group composition,
middleware inheritance/order and group-level policy declarations. It does not
own route matching precedence, middleware hook execution or CLI rendering.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Surface | `RouteGroup` (`core/router.py`) | `Router::group($prefix, $callback, $middleware=[])` | router group | `group(prefix, callback, middlewares?)` + static |
| Nested prefix | fixed (was dropped -- source comment) | correct | correct | correct |
| Slash normalization | could form `/apiusers`, `/api//users` | ALL combos normalized (reference) | not normalized | not normalized |
| Middleware inheritance | fixed (ran twice) | correct | correct | correct |
| Group auth | correct | correct | `auth_handler:` accepted+displayed but NEVER dispatched (false declaration) | correct |
| Adding middleware disables write-auth gate | fixed | correct | correct | correct |
| Historical regression suite | Python only | none | none | none |

The `group(prefix, callback, middleware)` surface agrees across the four (a static/class method
plus a `RouteGroup` that nested groups compose). The historical audit (2026-08-01) fixed three
Python defects -- group middleware ran twice, a nested prefix was dropped, and merely adding
middleware disabled the write-route auth gate -- all documented in the Python source comments.
Two gaps survive and are the substance of this standalone audit: Ruby accepts and DISPLAYS an
`auth_handler:` on a group but dispatch never calls it (a false security declaration), and only
PHP normalizes every leading/trailing slash combination -- Python, Ruby and Node can still form
`/apiusers` (no separator), a path with no leading slash, or `/api//users` (double slash). Only
Python received the historical regression suite.

### Historical evidence retained

The old audit fixed three Python defects: group middleware ran twice, a nested
prefix was dropped, and merely adding middleware disabled the write-route auth
gate. PHP, Ruby and Node were already correct on those measured cases.

Two gaps remained:

- Ruby accepted and displayed `auth_handler:` on a group but dispatch never
  called it, creating a false security declaration.
- Only PHP normalized all leading/trailing slash combinations. Python, Ruby and
  Node could form `/apiusers`, a path without a leading slash or `/api//users`.

Only Python received the historical group regression suite. The standalone
audit must establish one prefix grammar, one inheritance/order formula, an
explicit group-auth decision and a shared nested-group fixture for every
current and future language.

## Public surface contract

`group(prefix, callback, middleware=[])` opens a route group: routes registered inside the
callback receive the joined prefix and the group's middleware. Groups NEST -- a group inside a
group joins both prefixes and inherits both middleware chains. The method is a class/static
method in all four, with a `RouteGroup` composing the nesting. A group may declare
group-level policy (auth); a declared policy MUST be honored at dispatch, never merely
displayed.

## Inputs and outputs

- Input: a prefix string, a callback that registers routes, and an optional middleware list
  (and optionally a group auth declaration).
- Output: registered routes whose match path is the normalized join of the group prefixes and
  the route path, and whose middleware chain is the inherited group chain plus the route's own.
- The joined path always has exactly one leading slash and no double slash and never omits the
  separator between a prefix and a route (`/api` + `users` = `/api/users`, never `/apiusers`).
- A declared group auth handler is invoked at dispatch for the group's routes.

## Lifecycle and operation graph

1. `group(prefix, callback, middleware)` pushes the prefix and middleware onto the router's
   group state and runs the callback.
2. Each route registered in the callback joins the current group prefix (normalized) and
   inherits the group middleware in a defined order (group-outermost, then route).
3. A nested group joins its prefix onto the parent's and inherits the parent chain; the state
   is restored when the callback returns (the Python nested-prefix bug was a failure to read
   the nested prefix back).
4. At dispatch, the route runs its inherited middleware chain ONCE (not twice) and, if the
   group declared auth, the auth handler runs and the write-auth gate stays in force.

## Configuration and precedence

- ONE prefix grammar: the join always yields a single leading slash, a single separator
  between segments, and no trailing slash artifact (PHP's normalization is the reference).
- ONE middleware inheritance/order formula: a route's chain is the group chains from outermost
  to innermost, then the route's own middleware; each runs exactly once.
- A group auth declaration is honored at dispatch; it is never silently accepted-and-ignored.
- Adding group middleware NEVER disables the framework's write-auth gate (ADR-0049).

## Failures, side effects and security

- SECURITY: a declared group auth handler that is displayed but never dispatched (Ruby today)
  is a FALSE security declaration -- the operator believes the group is protected and it is
  not. A declared handler MUST fire, or the declaration MUST be rejected at registration; it is
  never silently dropped.
- Adding middleware to a group must not disable the write-route auth gate (the Python defect);
  middleware never opens a gate (ADR-0049).
- Prefix normalization prevents a malformed path (`/apiusers`, `/api//users`) from matching the
  wrong route or bypassing a prefix-scoped policy.
- Group state is restored after a nested callback so a later sibling group is not polluted by a
  previous group's prefix or middleware.

## Wire and persistence contract

There is no persistence; the observable output is the matched PATH and the middleware chain.
The joined path is the normalized concatenation of the group prefixes and the route path,
identical across the four. The CLI route listing renders the group prefix and an auth marker,
so a displayed `[AUTH]` must correspond to a handler that actually runs.

## Providers and substitutability

Route groups are transport-level and engine-agnostic. A future runtime composes the same
`group(prefix, callback, middleware)` surface with the same prefix grammar, the same
inheritance/order formula, and the same honored-group-auth rule.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| RG-01 | Only PHP normalizes every slash combination; Python, Ruby and Node can form `/apiusers`, a no-leading-slash path, or `/api//users`. | Pin ONE prefix grammar (PHP's) in all four; gate the join cases. |
| RG-02 | The middleware inheritance/order formula is fixed in Python (was double-run) but not gated as parity. | Pin one formula (group-outermost to route, each once); gate it in all four. |
| RG-03 | Ruby accepts and DISPLAYS a group `auth_handler:` but dispatch never calls it -- a false security declaration. | A declared group auth handler MUST fire at dispatch, or the declaration MUST be rejected at registration; never silently accepted. Gate that a displayed `[AUTH]` corresponds to a handler that runs. |
| RG-04 | Adding group middleware disabled the write-auth gate in Python (fixed); not gated as parity. | Gate that group middleware never disables the write-auth gate (ADR-0049) in all four. |
| RG-05 | A nested prefix was dropped in Python (fixed); not gated as parity. | Gate a nested-group joined prefix in all four. |
| RG-06 | Only Python received the historical group regression suite. | The shared fixture runs in all four. |
| RG-07 | No shared route-groups fixture exists. | Add `route_groups_contract.json` including a nested-group case. |

## Owner decisions

Proposed for owner ratification:

1. ONE prefix grammar in all four (PHP's normalization is the reference): a joined path has a
   single leading slash, a single separator between segments, and no trailing-slash or
   double-slash artifact.
2. ONE middleware inheritance/order formula: a route's chain is the group chains from
   outermost to innermost, then the route's own, each middleware running EXACTLY once.
3. A group auth declaration is HONORED at dispatch. Ruby's accept-display-but-never-dispatch
   is a defect: either the declared handler fires, or the declaration is rejected at
   registration. A displayed `[AUTH]` must mean a handler that runs. This is the security
   decision this row exists to settle.
4. Group middleware NEVER disables the write-auth gate (ADR-0049); adding middleware to a
   group cannot open a gate.
5. The shared nested-group fixture runs in all four, not Python alone.

## Proposed conformance fixture

Add `route_groups_contract.json` with stable ids for: a single-group joined prefix
(`/api` + `users` = `/api/users`); the three malformed joins that must NOT occur (`/apiusers`,
`/api//users`, no-leading-slash); a NESTED group joining both prefixes and inheriting both
middleware chains in order; each middleware running exactly once (the double-run reproduction);
a group `auth_handler` that FIRES at dispatch (the Ruby false-declaration reproduction, gated
so a displayed `[AUTH]` runs); and group middleware NOT disabling the write-auth gate. Every
case runs against a real router over a real request; no mock router can claim conformance.

## Integration map

- Feature 31 (router/dispatch) owns matching and dispatch; this feature composes the prefix
  and middleware; Feature 33 (middleware pipeline) runs the inherited chain.
- The write-auth gate (ADR-0049) must survive group middleware; the CLI route listing renders
  the group prefix and the `[AUTH]` marker, which must reflect a handler that actually runs.
- Swagger documents grouped routes under their joined prefix.
- Central fixtures, four runners, the CI matrix and the routing docs update together.

## Breaking changes and migration

- Ruby's group `auth_handler:` becomes effective (fires at dispatch) or is rejected at
  registration; an operator relying on it believing it protected a group now gets real
  protection, or a clear error rather than a silent no-op. `Breaking:` entry for the
  reject-at-registration path.
- Slash-normalization convergence changes any path a non-PHP framework formed as `/apiusers`
  or `/api//users`; a route relying on a malformed join changes. State it in the release note.
- The middleware order/once-per-run formula aligns; a route relying on the double-run (rare,
  and a bug) changes.

## Implementation backlog

1. Add `route_groups_contract.json` (with the nested-group case) and wire four runners against
   a real router.
2. Pin the prefix grammar (RG-01) and gate the malformed joins in all four.
3. Make Ruby's group auth fire at dispatch or reject at registration (RG-03); gate that a
   displayed `[AUTH]` runs.
4. Gate the middleware order/once formula (RG-02) and the write-auth-gate survival (RG-04).
5. Gate the nested-prefix join (RG-05) in all four; port the historical regression suite.
6. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement `group(prefix, callback, middleware=[])` as a class/static method with a `RouteGroup`
that nests. Join prefixes with ONE grammar (single leading slash, single separator, no double
slash), inherit middleware from outermost group to route with each running exactly once, and
restore the group state after a nested callback. Honor a declared group auth handler at
dispatch (never display-only), and never let group middleware disable the write-auth gate.
Prove the port against a real router with a nested-group case and a group-auth-fires case.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (RG-01..07).
- [x] Owner ambiguities recorded (5 proposed; the group-auth security call is the key one).
- [x] Proposed shared cases and mutation witnesses complete (nested + group-auth-fires).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready. The `group(prefix, callback, middleware)` surface already agrees; the
work is one prefix grammar (PHP reference), one middleware order/once formula, and the security
call on Ruby's group auth (honor at dispatch or reject at registration -- never display-only).
The IMPLEMENTATION is the build phase and is NOT done; only Python has the historical regression
suite, so the shared nested-group fixture must run in all four. Decision-ready is not built.
