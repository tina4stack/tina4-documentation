# Feature 007: Middleware pipeline

## Identity and status

- Matrix identity: 7 — Middleware pipeline
- Audit state: decision-ready; implementation is deliberately deferred
- Release boundary: v3 / 3.14.0; parity-breaking corrections are permitted
- Dependency: Feature 6 router and dispatch
- Dependants: CORS, CSRF, authentication, rate limiting, response cache,
  request logging, sessions and application middleware
- Existing decisions: ADR-0012, ADR-0014 (result-table clause superseded by ADR-0045)
- Current shared executable fixture: none
- Re-audit date: 2026-08-10

Feature 7 is **not stable**. The four approved characterisation suites are
green, but they preserve only the old before/after cases. They do not prove a
middleware stack. Adversarial execution found missing unwinds, after hooks for
middleware that never entered, non-functional `next()` behavior in Node, async
authorization bypass in Python, response mutation after transport commit and
several incompatible public middleware shapes.

## Owner decisions APPROVED (finalized 2026-08-10)

This packet declared no open product choices. The re-audit review surfaced three
genuine calls; Andre settled them, and one clean-room nit is fixed.

- **A: ADR-0014 is SUPERSEDED by a new ADR-0045, not amended in place.** The
  phase-specific before/after result tables replace ADR-0014's single-table rule.
  Per the decision-log convention (supersede, do not silently change), ADR-0045
  records the new tables and marks ADR-0014's result-table clause superseded;
  ADR-0014 stays as the historical record with a Superseded-by pointer. Backlog
  item 1 publishes ADR-0045.
- **B: pair rebinding is REMOVED - mutation-only.** A hook can no longer return
  `[request, response]` to swap object identities. Request and response are mutable
  framework objects; hooks mutate in place, and response replacement stays covered
  by the 'return Response' row. This drops a return shape from BOTH tables, and one
  more semantic table a future language must implement, consistent with the other
  3.14 removals (blocks, two-argument filters, status sniffing). The before and
  after tables, the removed-forms list, defect M7-15, the fixture cases and the
  migration notes are updated to match.
- **C: a bare `false` before-hook keeps the canonical 403 (ratified as written).**
  `return false` = deny/forbidden -> 403; a middleware wanting another status
  returns an explicit Response. 403 is the correct default for a policy denial.

Ratified: normal HTTP responses stay buffered and mutable until the unwind finishes
so every after hook can change them, with explicit streaming carved out as a
separate commit-on-first-chunk mode - a conscious memory tradeoff, accepted.

Clean-room nit fixed: the canonical 403 body follows the same response-surface
contract as the 500 (the delegation now names both).

These close the DESIGN half of the FINAL bar for Feature 7. Remaining to reach
FINAL: publish ADR-0045, materialize `middleware_contract.json`, and wire the four
executable runners (backlog items 1, 2, 12).

## Why this feature exists

An engineer inserts reusable behavior around request handling once. Tina4 then
runs it in the declared order on every applicable path, lets it continue or
answer explicitly, guarantees cleanup for every layer that entered and returns
one final response before the transport commits it.

The engineer must not need to know which internal runner is active, convert a
framework return value, compensate for a language-specific ordering accident,
or discover that a correctly declared hook was silently ignored.

## Boundary

Feature 7 owns:

- global, group and per-route middleware registration;
- pre-match versus post-match global placement metadata;
- class-hook and continuation-function middleware shapes;
- middleware discovery, validation and inspection;
- effective ordering when scopes and shapes are combined;
- continuation, short-circuit and response replacement rules;
- entered-layer tracking and reverse unwinding;
- sync/async invocation where the runtime supports both;
- middleware exception conversion and cleanup guarantees;
- the point at which the standard HTTP response may be committed;
- the named string-spec resolver mechanism;
- reset/clear behavior for tests, reload and repeated application startup;
- the middleware scaffolder contract;
- executable parity data and runner reporting for this feature.

It delegates:

- route matching, auth-gate placement and 404/405 selection to Feature 6;
- request and response object details to the routing-surface feature;
- the policy inside CORS, CSRF, rate limiting, cache and logging middleware to
  those features;
- the canonical 500 and 403 bodies and response serialization to the response surface;
- explicit streaming and WebSocket lifecycle to their own features.

Feature 7 still owns whether the delegated policy is invoked at the correct
place, exactly once, and unwound when it entered.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Orchestrator | `tina4_python/core/middleware.py` | `Tina4/Middleware.php` | `lib/tina4/middleware.rb` | `packages/core/src/middleware.ts` |
| Route path | `core/server.py` | `Tina4/Router.php` | `lib/tina4/router.rb` + `dispatch_pipeline.rb` | `packages/core/src/router.ts` + `server.ts` |
| Public global registry | one | one | one | two merge points |
| Class hooks awaited | no | synchronous runtime | synchronous runtime | yes |
| Continuation chain | real onion | real onion | real onion | sequential flag loop |
| Focused local baseline | 68 passed | 60 tests / 148 assertions | 65 examples | dependencies not installed locally |
| Focused lab baseline | 68 passed | 60 tests / 148 assertions | 65 examples | 17 passed over a real socket |

Audited local source heads were Python `29feeab`, PHP `c75c7b0e`, Ruby
`ea3aa88` and Node `813b50b`, all on `v3`. The one local commit ahead of each
remote only wires the already approved Feature 1 dotenv fixture and does not
change middleware source.

The serialized lab run used root through
`/root/tina4-lab/with-lab-lock.sh` on `the lab host`. Its middleware
source modules at Python `12cc44bb`, PHP `46f96429`, Ruby `25ac783` and Node
`96a5050e` have no diff from the audited local middleware modules. The green
baseline therefore applies to the same implementation under audit.

## Public surface contract

Every language must expose idiomatic equivalents of these concepts:

| Concept | Required behavior |
| --- | --- |
| use | register a global middleware layer with explicit phase metadata |
| route/group attachment | append middleware layers in declaration order |
| class hooks | discover and run validated before/after hooks |
| continuation function | receive request, response and one-shot `next` |
| named spec | resolve a registered name and arguments or fail immediately |
| list/effective list | expose declaration and actual execution order |
| clear/reset | remove every registry and resolver entry owned by the app/test |
| scaffold | generate the portable continuation form and explicit returns |

The portable registration record is:

```text
middleware_id          stable identity for inspection and diagnostics
spec                    callable, class, configured instance, or named spec
kind                    class_hooks | continuation
scope                   global | group | route
phase                   pre_match | post_match | route
registration_index      stable order within its scope
source                   file/module and line when available
name                     inspectable class/function/registry name
configuration            redacted inspectable arguments where safe
```

Every explicit registration creates one layer. There is no deduplication by
class or type. Two configured instances of one class are two layers. A global
layer explicitly attached again to a route runs at both registrations. Hot
reload must remove registrations by source ownership instead of relying on
hidden class deduplication.

`Middleware.use` and `Router.use` are one registry, not parallel registries that
the server later guesses how to merge. `clear/reset` empties that registry,
route attachments and application-owned named resolvers so a repeated startup
is deterministic.

## The two portable middleware shapes

### Continuation function — the scaffolded default

The portable concept is:

```text
middleware(request, response, next)
    do work before
    downstream_response = next()
    do work after
    return downstream_response
```

The spelling and await syntax are language-idiomatic. The semantics are not:

- the first declared middleware is the outermost layer;
- `next()` immediately descends into the next layer or handler;
- code after `next()` runs during reverse unwind;
- omitting `next()` is a short-circuit and must return a Response explicitly;
- `next()` may be called at most once and only during that invocation;
- a second or late call is a middleware protocol error and becomes a clean 500;
- after `next()`, returning null/nil/undefined uses the downstream/current
  Response so logging-only middleware is concise;
- before `next()`, returning null/nil/undefined is invalid because it neither
  continued nor answered; fail cleanly instead of hanging or inventing 200;
- returning a Response replaces the downstream/current response;
- continuation functions may be synchronous or asynchronous where the runtime
  supports both; the dispatcher resolves an awaitable result and also accepts
  an immediate result.

The canonical `next()` takes no arguments. Request and response are mutable
framework objects. A continuation that needs a different object uses the
framework's explicit mutation surface; ports must not invent a language-specific
`next(req, res)` contract.

### Class hooks — retained public API

A middleware class may declare one or more language-idiomatic hooks:

| Language | Before prefix | After prefix |
| --- | --- | --- |
| Python | `before_` | `after_` |
| PHP | `before` followed by a non-empty suffix | `after` followed by a non-empty suffix |
| Ruby | `before_` | `after_` |
| Node | `before` followed by a non-empty suffix | `after` followed by a non-empty suffix |

Exact `before` and `after` names are invalid. A registered class with no valid
hook is invalid. Registration/startup fails with the class, bad name and valid
shape; Tina4 never silently accepts an authorization middleware whose hook
cannot execute.

Discovery is deterministic:

- base class before subclass;
- source-definition order within each class;
- an override occupies the inherited hook's position and runs once;
- before hooks run in discovered order;
- after hooks within the same class run in discovered order;
- the class itself is one pipeline layer, so different classes unwind in
  reverse layer order.

Class hooks receive `(request, response)`. In async-capable runtimes the
dispatcher accepts either an immediate value or an awaitable from every hook.
An un-awaited coroutine/promise is never interpreted as “continue.”

## One effective pipeline

Class hooks and continuation functions are not separate batches. The framework
adapts both to one entered-layer stack while retaining the Feature 6 auth
boundary:

```text
pre-match globals, declaration order
  -> route match and metadata
  -> post-match globals, declaration order
  -> auth gate
  -> group/route middleware, declaration order
  -> handler or fallback result
  -> entered route layers, reverse order
  -> entered post-match globals, reverse order
  -> entered pre-match globals, reverse order
  -> response finalization and transport commit
```

Mixed class/function declarations keep their exact declared order. A list
`[function A, class B, function C]` enters A, B, C and exits C, B, A. A runtime
may implement adapters differently, but may not move every class ahead of every
function as Python, PHP and Ruby currently do.

Pre-match globals that entered unwind on every later outcome: match, 404, 405,
OPTIONS, static/template fallback, auth rejection, route short-circuit, handler
throw and normal success. Post-match globals only enter after a route matched,
but once entered they also unwind on auth rejection. Route middleware does not
enter before auth and therefore must not receive an after hook on an auth
rejection.

The implementation records layers as they enter. It never reconstructs an
after list from all registered middleware. If layer B short-circuits before C,
the owed unwind is B then A; C gets neither before nor after.

## Class-hook result contract

ADR-0014 correctly made an explicit returned Response the primary answer, but
its “same table on every hook” and retained status sniffing do not survive a
real unwind. This re-audit supersedes that clause with ADR-0045 before
implementation.

### Before hooks

| Return | Behavior |
| --- | --- |
| Response | replace the current response and stop descent at any status |
| `false` | stop descent; preserve an explicit response, otherwise create canonical 403 |
| null/nil/undefined | continue |
| anything else | protocol error -> clean 500 |

There is no `status >= 400` compatibility path in the 3.14 contract. Null means
continue. A middleware that wants to answer returns the Response or `false`.
Status sniffing is implicit, cannot express redirects, makes an unrelated
response mutation control flow and is not a rule a clean-room port should
copy. Pre-3.14 is the allowed point to remove it with a migration message.

### After hooks

| Return | Behavior |
| --- | --- |
| Response | replace the current response; continue unwinding owed layers |
| null/nil/undefined | keep the current response; continue unwinding owed layers |
| `false` or anything else | protocol error -> clean 500; continue unwinding owed layers |

An after hook cannot cancel cleanup already owed to outer layers. That is why
the before table cannot be copied mechanically into the after phase. A throw or
invalid return is logged with middleware identity and hook, changes the final
response to the canonical 500, and still permits every remaining owed unwind.

## Exceptions and response commitment

| Failure point | Required result |
| --- | --- |
| class/function entry throws | clean logged 500; unwind layers already entered |
| handler/downstream throws | outer continuation may handle it; otherwise clean logged 500 and unwind |
| class/function exit throws | clean logged 500; continue remaining unwind |
| invalid hook name/spec/shape | fail registration/startup with actionable diagnostic |
| unknown named spec/bad argument | fail registration/startup, never silently skip |
| second/late `next()` | clean logged 500; handler/downstream never executes twice |
| async value in a sync-only port | explicit unsupported error at registration, not a runtime no-op |

For ordinary HTTP responses the transport commits headers and body only after
the middleware unwind and final response policies finish. An after hook may
therefore replace the Response or add a header in every language. Node cannot
make `after` mean “in-process callback that is already too late for the wire.”

Explicit streaming is a separate mode because its first chunk commits the
response. A streaming feature must document which middleware operations remain
legal after commit and expose the committed state. It cannot silently weaken
the normal-response contract.

## Named middleware resolver

Feature 7 owns one resolver API and exact failure behavior, not the policy list
inside every built-in feature.

- syntax is `Name` or `Name:arg1:arg2` with escaping/typing defined by the
  owning middleware schema;
- names are case-sensitive canonical identifiers;
- the registry exposes name, owner feature and argument schema;
- all route/group/global paths use the same resolver;
- unknown names, invalid arity and invalid argument types fail at registration;
- each built-in feature decides whether it publishes a name and contributes
  its parity cases;
- the combined named registry must be identical across languages before 3.14.

Python currently knows `ResponseCache`, `RateLimit`, `RateLimiter`, `Cors` and
`CORS`; PHP, Ruby and Node only wire `ResponseCache`. Feature 7 must not paper
over that difference with aliases in one runtime. The owning feature either
publishes one canonical name everywhere or removes the name everywhere.

## Contradictions and defects measured on 2026-08-10

| ID | Severity | Measured contradiction | Required correction |
| --- | --- | --- | --- |
| M7-01 | P1 | All four enter class A then B and run `A.after` before `B.after`: `A.in, B.in, A.out, B.out`. Acquire/release layers are not nested. | track entries and unwind layers B then A |
| M7-02 | P1 | After first class short-circuits, all four run the after hook of a later class whose before hook never ran. Probe: `Stop.in, Stop.out, Never.out`. | unwind only recorded entries |
| M7-03 | P1 | On a tokenless secured route PHP/Ruby/Node trace only `G.in`; the entered global never gets `G.out`. Python traces `G.in, G.out, R.out`, incorrectly running route after without route before. | unwind entered globals on auth rejection; never run unentered route middleware |
| M7-04 | P1 | A successful pre-match layer followed by 404 traces only `P.in` in Python, PHP and Ruby; Node's no-match return has the same missing after path. | carry the entered stack through every fallback and unwind before commit |
| M7-05 | P1 | Node continuation probe is `outer.in, outer.out, inner.in, inner.out, handler`; its `next()` only flips a boolean and does not descend. Python/PHP/Ruby produce true onion order. | build one nested continuation chain in Node |
| M7-06 | P1 | Python calls an `async def before_gate` without awaiting it. Probe result: handler continues at status 200 plus “coroutine was never awaited.” An async auth gate is bypassed. | resolve awaitables from every hook and gate the regression |
| M7-07 | P1 | Node route after hook executes, but after a normal JSON handler the wire header is null because the response already ended. Existing tests only prove an after header when the handler deliberately leaves the response open. | defer normal HTTP commit until unwind finishes |
| M7-08 | P1 | Python/PHP/Ruby permit a continuation to call `next` twice and execute the handler twice. Node happens to execute it once only because `next` does not descend at all. | one-shot continuation with deterministic protocol error |
| M7-09 | P2 | Mixed shapes do not share an order: Python/PHP/Ruby extract functions and run classes first; Node preserves loop order but lacks continuation semantics. | adapt every shape to one ordered chain |
| M7-10 | P2 | Python treats any three-argument callable as async. A synchronous three-argument middleware fails with `TypeError: object Response can't be used in 'await' expression`. | accept immediate or awaitable result |
| M7-11 | P2 | Python deduplicates configured instances by `type`; two distinct instances become one effective layer. | remove type/class deduplication |
| M7-12 | P2 | The after-result contract is already split: Python/PHP/Node stop remaining after hooks on `false`; Ruby continues. Ruby also continues after a returned Response. ADR-0014 claims one table. | adopt the phase-specific tables above; supersede ADR-0014 with ADR-0045 |
| M7-13 | P2 | Ruby pattern blocks run twice when any pre-match class exists because both passes call the global block registry. The same block uses a different result contract from class hooks. | remove the Ruby-only block form from the portable surface |
| M7-14 | P2 | Ruby/PHP retain two-argument filter middleware; Python silently treats a two-argument function as an inert class-like object; Node's type admits the three-argument form only. | remove the legacy filter shape; continuation or class hooks only |
| M7-15 | P2 | Node route-class runner's boolean return type cannot carry a replacement Response through the unified chain. | return/replace the Response through the unified chain (pair rebinding removed, decision B) |
| M7-16 | P2 | Hook validation is absent. Wrong or exact `before`/`after` names can register and silently do nothing, with language-specific prefix matching. | validate at registration/startup and fail explicitly |
| M7-17 | P2 | Node merges `Router` class middleware and `MiddlewareRunner` globals; reset and inspection have two authorities. | one registry and one reset seam |
| M7-18 | P2 | String registries disagree: Python exposes five aliases/names, the other three one. | central named registry; feature-owned names identical everywhere |
| M7-19 | P2 | The generator is a four-way split: Python/Ruby teach the legacy status path, PHP teaches returned Response, Node generates a function instead of class hooks. | generate the portable continuation form in all languages |
| M7-20 | P3 | No shared `middleware_contract.json` exists; current suites duplicate examples and omit the adversarial lifecycle. | create executable fixture and four hash-reporting runners |

No framework source was changed during this audit.

## Removed legacy/public forms

The 3.14 portable surface removes:

- Ruby-only `Middleware.before(pattern) { ... }` and `.after` block registries;
- two-argument callable/filter middleware;
- implicit short-circuit by response status;
- class-hook `[request, response]` pair rebinding (mutate the framework objects in
  place, or replace the response by returning a Response);
- class/type deduplication;
- silent acceptance of a class with no valid hook;
- language-specific `next(request, response)` continuation signatures.

These forms increase the number of semantic tables without enabling behavior
that the two canonical shapes cannot express. Removing them before stability is
smaller and safer than teaching a future language five historical middleware
APIs.

## Proposed executable fixture

Create `plan/v3/fixtures/middleware_contract.json`. It is runtime-neutral data,
not test-name text. Every case contains:

```text
id
registrations[]        kind, scope, phase, order, hooks/function behavior
request                method, path, auth outcome and initial response
expected_trace[]       exact entry/handler/unwind events
expected_response      status, headers and normalized body
expected_error         optional registration/runtime diagnostic category
```

Each runner loads the same file, executes real framework middleware and emits:

```json
{
  "feature": 7,
  "fixture_version": 1,
  "fixture_sha256": "...",
  "language": "...",
  "consumed": 42,
  "passed": 42,
  "failed": []
}
```

The aggregate audit fails when a runner is missing, consumes zero cases,
reports an old hash/version, skips a required capability or disagrees on trace
or wire response.

### Registration and validation cases

- global, nested group and route registration preserve exact order;
- pre-match phase is registration metadata, not a class-name special case;
- class with inherited and overridden hooks;
- exact `before`/`after`, no hook, instance method where static is required,
  unknown spec and bad named arguments fail explicitly;
- two configured instances of one class both run;
- duplicate explicit registrations both run;
- repeated clear/start/reload does not retain ghost entries;
- same registry feeds inspection and execution.

### Lifecycle and ordering cases

- class A/B success: `A.before, B.before, handler, B.after, A.after`;
- continuation A/B has the same trace;
- mixed function/class/function preserves declared entry and reverse exit;
- short-circuit A prevents B/handler and unwinds A only;
- short-circuit B unwinds B then A;
- pre-match success followed by match, 404, 405, OPTIONS and fallback;
- post-match success followed by auth rejection;
- route middleware never enters or exits on auth rejection;
- route short-circuit and handler throw unwind exactly the entered layers;
- base/derived and multiple-hook definition order;
- standard handler response remains mutable during every after hook.

### Result and error cases

- before returns Response at 200, 302, 403 and 500;
- before returns false, null and invalid scalar;
- a hook merely sets 403 then returns null: handler continues, proving status
  sniffing is gone;
- after returns Response, null, false and invalid scalar;
- after Response replacement still runs outer cleanup;
- before, downstream and after throw paths with exact final 500 behavior;
- sync and async hook/function combinations in async-capable runtimes;
- sync three-argument Python middleware;
- async Python authorization gate actually denies;
- no-next explicit response; no-next null protocol error;
- double and retained/late next protocol errors; handler executes at most once.

### Wire cases

- after hook changes a header and replaces a JSON response after a normal
  handler; both changes reach a real client;
- 302 middleware response skips the handler and carries Location;
- 401 auth response carries global unwind headers/log event;
- 404 carries pre-match unwind header/log event;
- standard response commits only after unwind;
- explicit streaming cases are excluded until the streaming feature publishes
  its own commit policy.

### Mutation witnesses

The fixture is considered wired only after temporary mutations are proven red:

- iterate after classes forward;
- reconstruct afters from all registrations instead of entered layers;
- change Node `next` back to a boolean flag;
- omit `await`/awaitable resolution for a Python class hook;
- end a Node JSON response before after hooks;
- permit a second next call;
- deduplicate two instances by class;
- restore response-status sniffing;
- make a runner report a stale fixture hash.

## Mainstream comparison

The standard does not prescribe application middleware internals, so ADR-0012
moves to framework behavior. Django documents reverse response middleware.
ASP.NET Core documents that each component may work before and after `next`,
and that the response traverses prior middleware in reverse order. Express
defines `next` as executing the succeeding middleware, not setting a flag.

References:

- <https://docs.djangoproject.com/en/dev/topics/http/middleware/>
- <https://learn.microsoft.com/aspnet/core/fundamentals/middleware>
- <https://expressjs.com/en/5x/guide/writing-middleware/>

The Tina4 contract adopts the established nesting and short-circuit model while
keeping a smaller surface: one ordered registry record and two portable shapes.

## Owner decisions

No unresolved product choice blocks implementation. This re-audit makes the
following decisions for review:

- middleware is a nested stack, not independent forward before/after lists;
- only entered layers unwind, strictly outside-in / inside-out;
- both public shapes work at global, group and route scope;
- continuation functions are the scaffolder default;
- `next()` is no-argument, immediate and one-shot;
- class hooks accept immediate or awaitable results where supported;
- before and after use phase-specific result tables;
- after failure never cancels outer cleanup;
- the legacy status check, Ruby blocks, two-argument filters and pair rebinding are removed;
- normal HTTP response commit is after middleware unwind;
- every explicit registration is a layer; no type/class deduplication;
- a bad hook or spec fails explicitly;
- ADR-0014's result-table clause is superseded by ADR-0045, not copied into another language.

If any decision is intentionally different product policy, change it before
implementation and record the replacement in an ADR. Otherwise approval makes
this document the Feature 7 implementation contract.

## Integration map

| Consumer | Required integration |
| --- | --- |
| Feature 6 dispatch | carry one entered stack through match, auth, fallbacks and finalization |
| auth | post-match globals enter before it; route middleware enters only after it |
| CORS/CSRF/rate limit/cache/logging | publish canonical registry names/config and run through the same adapters |
| response/transport | expose mutable response until unwind; commit once |
| error handling | canonical logged 500 without abandoning owed cleanup |
| route/group API | append registration records without shape reordering |
| discovery/reload | own registrations by source and remove them atomically |
| CLI/MCP/doctor | show effective order, phase, scope, source, kind and configuration safely |
| scaffolder | generate continuation form with explicit response/next behavior |
| public documentation/book | teach only the two portable shapes and migration removals |
| parity gate | execute the fixture and verify version/hash/consumption |

## Breaking changes and migration

Release notes and startup diagnostics must call out:

- after hooks reverse across middleware layers;
- after runs only for a layer that entered;
- global after now runs on auth rejection and pre-match after on fallbacks;
- route after no longer runs when auth prevented route entry;
- Node `next()` becomes a real nested continuation and normal response commit
  moves after unwind;
- Python awaits async hooks and accepts synchronous continuation functions;
- double next becomes a 500 protocol error instead of duplicate handler work;
- response status alone no longer short-circuits; return Response or false;
- class-hook `[request, response]` pair rebinding is removed; mutate the framework
  objects in place, or return a Response to replace it;
- Ruby block and Ruby/PHP two-argument filter forms are removed;
- wrong/no-hook classes and unknown named specs fail startup;
- distinct configured instances and repeated explicit registrations all run;
- generator output changes to the portable continuation shape.

Diagnostics should name the middleware, scope, source and exact replacement.
No compatibility mode is required before 3.14.0.

## Implementation backlog

Audit-first rule: do not execute this backlog until this audit is approved for
implementation.

1. Publish ADR-0045 superseding ADR-0014's result-table clause: nested unwinding,
   phase-specific result tables, and removal of response-status sniffing and pair
   rebinding.
2. Materialize `middleware_contract.json` with the lifecycle, wire and mutation
   cases above.
3. Define the canonical registration record, one registry and source-owned
   clear/reload behavior in every runtime.
4. Validate middleware shape, hook names, named specs and arguments at
   registration/startup.
5. Adapt class hooks and continuation functions to one nested execution model
   while retaining the Feature 6 auth boundary.
6. Carry an explicit entered-layer stack through every dispatch/fallback exit
   and unwind it in reverse.
7. Implement one-shot real continuations; accept sync/async results correctly
   and prevent duplicate handler execution.
8. Defer Node standard-response commitment until unwind completes; verify
   response replacement and headers over a real socket.
9. Remove legacy status sniffing, Ruby block handlers, two-argument filters and
   class/type deduplication.
10. Normalize named middleware publishing with the owning feature audits.
11. Make all scaffolders generate the continuation default and update migration
    diagnostics.
12. Wire four executable fixture runners that report exact fixture hash and
    consumption; make the aggregate checker execute them.
13. Prove every mutation witness red, then run focused/full local suites and
    serialized lab suites as root.
14. Update Tina4 public documentation, book examples, changelogs and the 3.14
    release checklist only after behavior is green.

## Porting capsule

A clean-room language port implements Feature 7 in this order:

1. create the canonical registration record and single registry;
2. support global pre/post phase metadata plus ordered group/route attachment;
3. validate named specs and the language's exact class-hook convention;
4. adapt class hooks and continuation functions to one layer interface;
5. build the effective chain without deduping or regrouping shapes;
6. enter layers in declaration order and push each successful entry;
7. let `next()` descend exactly once or require an explicit terminal Response;
8. resolve immediate/awaitable values according to the two phase tables;
9. unwind only entered layers in reverse on every outcome;
10. preserve cleanup after short-circuit, auth rejection and exceptions;
11. keep the ordinary response mutable until unwind and commit once;
12. expose the truthful registry/effective order to inspection and reset;
13. load the shared fixture, report its hash and execute every applicable case;
14. prove the mutation witnesses fail before claiming parity.

The port is incomplete if it copies only `before` and `after` method names. It
is complete when the same registration data and request produce the same exact
entry trace, handler count, unwind trace, native request/response, final wire response,
diagnostic and inspection order.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] All registration shapes and scope/phase combinations traced.
- [x] Sync, async, continuation and short-circuit paths probed.
- [x] Auth, 404 and response-commit lifecycle edges probed.
- [x] Ordering, entered-layer and cleanup guarantees specified.
- [x] Existing-language contradictions recorded with executable evidence.
- [x] Legacy removals and breaking migrations explicit.
- [x] Proposed shared fixture cases and mutation witnesses complete.
- [x] Integration map and dependency-ordered implementation backlog complete.
- [x] Porting capsule is clean-room sufficient.

Feature 7 is **audit-complete and decision-ready**, not implementation-complete
and not 3.14-stable. Approval records the contract; implementation must then
publish ADR-0045 superseding ADR-0014, create the executable fixture and make all four runtimes
conform before Feature 7 can be called complete.
