# Feature 32: Route groups

## Identity and status

- Matrix identity: 32 - Route groups (shared prefix + middleware)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language source (correcting a stub whose RG-03 "Ruby group auth
  never dispatched" and RG-06 "group suite Python-only" are STALE/fixed). The group API exists in all four; the
  real live divergence is prefix slash-normalization. Python `core/router.py:158` (`46007c1`); PHP
  `Tina4/Router.php:270` (`ab871934`); Ruby `lib/tina4/router.rb:673` (`f549923`); Node
  `packages/core/src/router.ts:279` (`1319cf3`).
- Dependencies: the router, the middleware pipeline (7), the write-auth gate.
- Dependants: apps grouping routes under a prefix/middleware.
- Existing ADRs: none dedicated.

- Catalog phase: Routing and middleware

## Why this feature exists

A route group applies a shared prefix and middleware to a block of routes. The audit questions: does it exist,
does the prefix join cleanly, and does group middleware ever weaken the write-auth gate. It exists in all four
(no absence) and never weakens the gate (gated), but the prefix-join grammar diverges - only PHP normalizes.

## Existing implementation evidence

Measured, all four:

- `group(prefix, callback[, middleware])` exists in all four - two surface shapes: an object handed to the
  callback (Python `RouteGroup`, Node `RouteGroup`) vs ambient registration (PHP static state, Ruby
  `instance_eval` `GroupContext`). All apply a shared PREFIX + shared MIDDLEWARE and support NESTING (prefix
  concatenates, middleware composes) - each gated by a real test in all four.
- Group middleware NEVER disables the secure-by-default write-auth gate (RG-04), gated by a 401 test in all
  four (Python `router.py:367`, PHP `Router.php:1631`, Ruby `router.rb:24`, Node `router.ts:186`).
- The PREFIX-JOIN grammar diverges: PHP fully normalizes (single separator, no double slash, `Router.php:2159`)
  - the reference; Python bare-concats (`/api`+`users` -> `/apiusers`, `router.py:339`); Ruby `chomp` strips
  one trailing slash (`/apiusers` AND `/api//users`, `router.rb:785`); Node does NO normalization (the worst).
  No slash-normalization test in any language.
- Only Ruby's `group()` accepts a group-level `auth_handler:` (`router.rb:673`); py/php/node groups have no
  group-level auth declaration.
- STALE prior claims: RG-03 (Ruby group `auth_handler` never dispatched) is FALSE - Ruby dispatches it now
  (`dispatch_pipeline.rb:484`); RG-06 (group regression suite Python-only) is FALSE - all four ship
  near-identical suites.

## Public surface contract

`Router.group(prefix, cb)` attaches a shared prefix + middleware to nested routes; nesting composes; group
middleware never opens the write-auth gate. The prefix-join should be uniform (today only PHP is correct).

## Inputs and outputs

- Input: a prefix + a callback registering routes (+ optional middleware). Output: routes registered under the
  prefix with the middleware.

## Lifecycle and operation graph

1. `group(prefix, cb)` sets the prefix/middleware. 2. Routes registered inside inherit them. 3. Nesting
concatenates prefixes + composes middleware. 4. The write-auth gate still applies.

## Configuration and precedence

- Group middleware is outermost; route middleware inner. No env. A user route's own `noAuth`/`secured` still
  decides auth (group middleware never overrides it).

## Failures, side effects and security

- SECURITY: group middleware never disables the write-auth gate (verified). The risk is the prefix-join bug:
  a route can register at the WRONG path (`/apiusers` instead of `/api/users`) in Python/Ruby/Node when the
  route path omits its leading slash - a silent mis-registration. See the register.

## Wire and persistence contract

Routes are registered at compile time; the group is a registration-time concept. No wire/persistence.

## Providers and substitutability

A future runtime must offer a group API with a NORMALIZED prefix join, composing middleware, nesting, and the
write-auth gate intact.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| RG-SLASH-NORMALIZE | The prefix+path JOIN grammar diverges and is UNGATED: PHP fully normalizes (single separator, collapses double slashes, `Router.php:2159-2163`) - the reference; Python bare-concats so `group("/api")`+`get("users")` -> `/apiusers` (`router.py:339`); Ruby `chomp` strips only ONE trailing slash so both `/apiusers` and `/api//users` occur (`router.rb:785`); Node does NO normalization at all. So a route can silently register at the wrong path in Python/Ruby/Node. No slash test in any language. | Converge on PHP's normalization (one separator, no double slash, leading slash) in Python/Ruby/Node; gate it with a fixture. |
| RG-RUBY-ONLY-AUTH | Only Ruby's `group()` accepts a group-level `auth_handler:` (`router.rb:673`); Python/PHP/Node groups have no group-level auth declaration. A surface asymmetry (not a security gap - writes are secure-by-default everywhere, and Ruby DOES dispatch the handler now, correcting the stale RG-03). | Decide whether a group-level auth declaration is a required surface in all four (add to py/php/node) or Ruby-only. |
| RG-SURFACE-SHAPE | The surface diverges: object-to-callback (py/node) vs ambient static state (php) vs `instance_eval` (ruby). Functionally equivalent, but bare `get`/`post` inside a group works in php/ruby and not py/node (which need `group.get(...)`). | Document the two shapes; decide whether to converge (low priority - behaviour matches). |
| RG-NO-FIXTURE | No shared `route_groups_contract.json`; each language has its own hand-written suite (similar-by-convention, not driven by shared bytes). | Add a shared fixture (prefix join + nesting + write-auth-gate). |

## Owner decisions

- RG-DEC-01 (proposed): converge the prefix slash-normalization on PHP's grammar (RG-SLASH-NORMALIZE) in
  Python/Ruby/Node and gate it - the real live divergence (a route mis-registers at `/apiusers`).
- RG-DEC-02 (proposed): decide group-level auth parity (RG-RUBY-ONLY-AUTH) and add the shared fixture
  (RG-NO-FIXTURE). Note the stale RG-03/RG-06 are corrected (both fixed).

## Proposed conformance fixture

A shared fixture: `group("/api")` + `get("users")` and `get("/users")` and `group("/api/")` + `get("/users")`
ALL resolve to `/api/users` in all four (catches RG-SLASH-NORMALIZE); nested groups compose prefix +
middleware; group middleware does NOT open a write route (a tokenless write -> 401).

## Integration map

- Consumers: apps grouping routes. Composes: the router, the middleware pipeline (7), the write-auth gate.

## Breaking changes and migration

- Normalizing the prefix join changes the registered path for currently-mis-registered routes (e.g. a route
  that relied on `/apiusers`) - a correctness fix; note it.

## Porting capsule

Offer `group(prefix, callback[, middleware])` that applies a NORMALIZED shared prefix (one separator, no double
slash, single leading slash - PHP's grammar; a bare concat mis-registers `/apiusers`), composes shared
middleware (group-outermost), supports nesting (prefix concatenates, middleware composes), and NEVER lets group
middleware disable the write-auth gate. Decide whether a group-level auth declaration is a required surface.

## Audit closure checklist

- [x] Boundary and public surface complete (group API x four).
- [x] Lifecycle and producer/consumer edges complete (prefix + middleware + nesting).
- [x] Configuration, failure (slash-join) and SECURITY (write-auth-gate intact) rules complete.
- [x] Wire (registration-time) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (exists all four; slash-join diverges; RG-03/06 corrected).
- [x] Owner ambiguities decided (RG-DEC-01 slash-normalize, RG-DEC-02 auth/fixture).
- [x] Conformance fixture (prefix join + write-auth) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
