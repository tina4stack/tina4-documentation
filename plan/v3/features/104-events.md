# Feature 104: Event and listener system

## Identity and status

- Matrix identity: 104 - Event and listener system (the observer/pub-sub bus: on / once / off / emit /
  emit_async / listeners / events / clear)
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-11 at Python `core/events.py` (172), PHP
  `Tina4/Events.php` (296), Ruby `lib/tina4/events.rb` (155), Node `packages/core/src/events.ts` (216).
  Suites are reported, not re-run.
- Dependencies: the structured logger (`Log.warning`) for listener-error reporting; the route-error /
  500 path, which is the sole internal emitter.
- Dependants: application listener code (scaffolded by the `generate listener` CLI command); the
  `tina4.request.error` observability hook.
- Existing ADRs: none.
- Shared fixtures: NONE. `events_contract.json` is owed (EV-10). Each language has a real, no-mock suite
  (Python ~28, PHP 28, Ruby 23, Node in two files), and the middleware-isolation test in each explicitly
  states the error contract is "mirrored in php/ruby/nodejs" and cross-references the sibling suites -
  strong parity intent, but no single oracle enforces it.

- Catalog phase: Developer internals

## Why this feature exists

The event bus lets one part of an application announce that something happened and another part react,
without the two knowing about each other. A listener registers for a named event; an emitter fires that
name with a payload; every listener runs. It is the decoupling primitive behind "on user signup, send a
welcome email" without wiring the signup code to the mailer.

Tina4's bus is deliberately small and zero-dependency. It adds priority ordering (higher runs first), a
one-shot `once`, per-listener error isolation so one bad listener never breaks the rest, and a `strict`
mode that re-raises instead. The framework itself uses it for exactly one thing: announcing an uncaught
route error as `tina4.request.error` so an application can log or alert on it.

## Boundary

This packet owns the `Events` bus in each language: registration (`on`, `once`), removal (`off`,
`clear`), dispatch (`emit`, `emit_async`), introspection (`listeners`, `events`), the priority ordering,
the once semantics, and the error-isolation / strict / logging contract.

It does NOT own: the `Log` subsystem it reports errors through; the route-dispatch error path that emits
`tina4.request.error` (owned by the server/router); the CLI `generate listener` scaffolder. The bus is a
callee of the error path and a producer for the logger.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | `core/events.py` module funcs (no class) | `Tina4/Events.php:21` static class | `lib/tina4/events.rb:16` singleton class | `packages/core/src/events.ts:77` static class |
| Registry | module `defaultdict(list)` | static `array` | class `Hash.new{[]}` | module `Map` |
| Strict spelling | `emit(..., strict=False)` kwarg | `emitStrict()` separate method | `emit(..., strict: false)` kwarg | `emit(event, {strict}, ...args)` options object |
| Async model | `emit_async` awaits coroutines sequentially, returns results | `emitAsync` is a SYNCHRONOUS alias, returns results | `emit_async` Thread-per-listener, returns array of Threads | `emitAsync` awaits sequentially, returns Promise of results |
| once removal timing | before invocation | AFTER the loop | before invocation | before invocation |
| Internal emitter | `tina4.request.error` (server.py:1940) | same (Router.php:797) | same (rack_app.rb:675) | same (server.ts:1277) |
| Focused tests | test_events.py ~28 + middleware_events + router_error_event | EventsTest 28 + MiddlewareEvents + RouterErrorEvent | events_spec 23 + middleware_events + router_error_event | events.test.ts + middlewareEvents.test.ts + routerErrorEvent.test.ts |

## Public surface contract

The surface is the same set of operations, spelled idiomatically:

- `on(event, callback, priority = 0)` - register (Python/Node also as a decorator; Ruby takes a block).
- `once(event, callback, priority = 0)` - register a one-shot.
- `off(event, callback = null)` - remove one listener by identity, or all listeners for the event when
  no callback is given.
- `emit(event, ...args)` - fire; returns a results array (one slot per listener, in priority order).
- `emit_async` (`emitAsync`) - the async variant (see Providers for the per-language reality).
- `listeners(event)` - the callbacks for an event, in priority order.
- `events()` - the registered event names.
- `clear()` - remove everything.
- Strict mode re-raises the first listener error instead of isolating it. Its spelling is
  language-idiomatic: a `strict` keyword (Python, Ruby), a separate `emitStrict` method (PHP, which has
  no keyword arguments), or a leading `{ strict: true }` options object (Node).

Events are keyed by exact string; there is NO wildcard or namespace matching in any language (dotted
names like `user.created` are pure convention). A listener may register more than once and then fires
more than once. Priority is higher-first and stable (equal priorities keep registration order) in all
four.

## Inputs and outputs

- `emit` input: an event name plus arbitrary args, forwarded verbatim to every listener. Output: an
  array of listener return values in priority order, with a null slot for any listener that threw (in
  non-strict mode). An unknown event returns an empty array.
- `on` / `once` output: void (Python/Ruby return the callable/block as a removal handle; Node/PHP return
  void).
- `off` / `clear` output: void in all four (no removed-count is returned).
- `emit_async` output diverges (EV-01): Python, PHP, and Node return a results array (a Promise of one
  in Node); Ruby returns an array of Thread objects the caller must join.

## Lifecycle and operation graph

1. `on` / `once` append an entry (priority, callback, once-flag) to the event's bucket and re-sort by
   priority descending.
2. `emit` snapshots the bucket (all but Python), then for each listener in priority order: removes it
   first if it is a once (all but PHP), calls it, collects the return value, and on a throw either
   re-raises (strict) or logs a warning and pushes null (default).
3. `emit_async` does the same with the language's async model.
4. `off` / `clear` remove listeners.
5. The only framework caller is the route-error path, which emits `tina4.request.error` with
   `{exception, request}` inside its own try/catch before rendering the 500.

## Configuration and precedence

The bus reads NO environment variables in any language. Strict mode is a per-call choice, never an env
flag - there is no `TINA4_EVENTS_STRICT`. The only indirect env coupling is that listener-error logging
flows through `Log.warning`, which obeys the logger's own `TINA4_LOG_*` settings.

## Failures, side effects and security

- Error isolation (the core contract, matched in all four): in the default mode a listener that throws
  does not abort the others; its slot is null and the failure is logged at warning level (with a
  stderr/console fallback if the logger itself throws). N listeners always yield N results. Strict mode
  re-raises the first error and stops.
- Catch breadth differs (EV-08): PHP catches `Throwable`, Python `Exception`, Ruby
  `StandardError`/`ScriptError`, Node any thrown value. A non-StandardError raised in Ruby is not
  isolated. Edge case, untested.
- Re-entrancy (EV-04): PHP (copy-on-write foreach), Ruby (dup before iterate), and Node (spread copy)
  all snapshot the listener list, so a listener that registers or removes during an emit is safe. Python
  iterates the live list and mutates it in place on registration, so `on()` called during an emit can
  reorder or skip the in-flight iteration. Latent, untested.
- No security surface: the bus never reads untrusted input as code, touches no filesystem or network,
  and holds no secrets. It is process-local, in-memory only.
- No thread safety: none of the four locks the registry, yet Ruby ships a threaded `emit_async`.
  Concurrent registration and emit across threads is unsynchronized (Ruby is the only one where this is
  reachable through the public API).

## Wire and persistence contract

There is no wire format and no persistence. The registry is in-memory and process-local (a module
dict/map/array or a class hash). State does not survive a restart and is not shared across processes or
instances. `clear()` is the only bulk reset.

## Providers and substitutability

There is no external provider; each bus is hand-rolled on the language's own primitives (Node
deliberately does NOT wrap `node:events`/`EventEmitter` - it is a custom Map-backed bus, so its priority
/ once / isolation semantics match the others rather than inheriting EventEmitter's). The substitution
axis is the async model, and it is NOT uniform (EV-01): Python and Node await coroutine/Promise listeners
sequentially in priority order and return results; PHP has no real async and makes `emitAsync` a
synchronous alias; Ruby spawns a thread per listener and returns the threads. No dependency is added in
any language.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| EV-01 | `emit_async` return contract diverges. Python / PHP / Node return a results array (a Promise of one in Node); Ruby returns an array of Thread objects the caller must `.join`, with non-deterministic completion order. A program ported from one to another gets a different return type and a different concurrency guarantee. | OWNER DECISION (EV-DEC-01). Recommendation: make the return uniform - Ruby's `emit_async` joins its threads internally and returns the results array like the others (keeping the thread-per-listener execution if desired). If fire-and-forget is intended, give it a distinct name. Document the concurrency reality per language either way. |
| EV-02 | `once` + async is broken in Python and Ruby. Python's `once` wrapper is a sync function, so under `emit_async` an async once-listener's coroutine is never awaited (a dangling coroutine). Ruby's `emit_async` never removes the once entry, so a once-listener fired asynchronously re-fires on the next async emit. Node and PHP are correct. Latent, untested in both. | FIX Python (await the underlying callable when it is a coroutine) and Ruby (remove the once entry in `emit_async` too). Node is the correctness reference. Add a named regression in all four. |
| EV-03 | `once` removal timing diverges. Python, Ruby, and Node remove the once-listener BEFORE invoking it (re-entrancy-safe); PHP removes it AFTER the loop. A PHP once-listener that re-emits its own event re-fires because the removal has not happened yet. Latent, untested. | FIX PHP to remove the once before invocation, matching the other three and the re-entrancy comment already in the Ruby/Node source. Add a re-entrant-once regression. |
| EV-04 | Re-entrant registration is unsafe in Python only. Python iterates the live listener list and `on()` appends+sorts it in place, so registering during an emit can reorder or skip the running iteration. PHP / Ruby / Node all snapshot the list first. Latent, untested. | FIX Python to iterate a copy of the listener list (snapshot), matching the other three. |
| EV-05 | Strict spelling differs three ways: `strict=` keyword (Python, Ruby), `emitStrict()` separate method (PHP), `{strict}` options object (Node). All are language-idiomatic (PHP and TS lack Python/Ruby keyword args). The PHP CLAUDE.md doc omits `emitStrict`/`emitAsync`/`emitAsyncStrict`. | NO code change - accept the idiomatic spellings. Document all three forms uniformly in `28-*`/the events docs, and fix the PHP CLAUDE.md to list the strict/async methods it actually ships. |
| EV-06 | Empty-bucket leak. Python `events()` and Ruby `emit`/`listeners` on an unknown event leave an empty event key behind (the `defaultdict` / Hash default proc), so `events()` can report names with zero listeners. PHP and Node do not (they read without creating). | Low priority. Fix Python and Ruby to not create a bucket on a read/`emit`-miss, or filter empty buckets out of `events()`. |
| EV-07 | Ruby does not normalize the event key, so a String and a Symbol of the same text are DISTINCT buckets; the other three are string-typed. A Ruby caller mixing `"evt"` and `:evt` silently splits listeners. | OWNER DECISION (low priority): normalize the Ruby key with `event.to_s`, or document that the key is compared by object identity/equality. |
| EV-08 | Catch breadth differs (PHP `Throwable` > Python `Exception` > Ruby `StandardError`/`ScriptError`). A non-StandardError raised by a Ruby listener escapes isolation. | Low priority. Align on the broadest reasonable per language (Ruby could add the relevant error classes) or document the boundary. Edge case. |
| EV-09 | Python-only cleanups: a stale docstring in `tests/test_router_error_event.py` still asserts the OLD "a higher-priority listener that raises stops the rest / emit propagates the first exception" semantics (contradicts the current isolate-and-continue default; the test's assertions do not catch it); and the top-level `tina4_python` package re-exports only `on`/`emit`/`once`/`off`, omitting `listeners`/`events`/`clear` that `core` exposes. | Correct the docstring to the current contract; export the full introspection surface at the top level for symmetry. Small. |
| EV-10 | No `events_contract.json`, no CONTRACT-MAP row, no ADR. The isolation tests state parity intent and cross-reference each other, but no shared oracle enforces the priority / results / isolation / once / internal-event contract. | Add `events_contract.json` (below) and the first Events ADR ratifying the contract and the EV-01..EV-05 decisions. |

## Owner decisions

- EV-DEC-01 (proposed): unify the `emit_async` return contract (Ruby joins and returns results) or
  formally document the language-native divergence. Recommendation: unify to a results array.
- EV-DEC-02 (proposed): fix `once` under async in Python and Ruby (EV-02).
- EV-DEC-03 (proposed): fix PHP once-removal to before-invocation (EV-03).
- EV-DEC-04 (proposed): fix Python re-entrancy by snapshotting the listener list (EV-04).
- EV-DEC-05 (proposed): accept the three idiomatic strict spellings; fix the PHP doc (EV-05).
- EV-DEC-06 (proposed): decide the empty-bucket behaviour (EV-06) and Ruby key normalization (EV-07).

## Proposed conformance fixture

`events_contract.json` - the same scripted sequence drives a runner in each language against the real
bus (no doubles; listeners are plain in-process functions). Cases:

- Registration + emit: three listeners, assert the results array is in priority order with equal
  priorities in registration order.
- Isolation: a middle listener throws; assert results are `[r1, null, r3]`, the other listeners ran, and
  a warning was logged (assert against real log output).
- Strict: the same throw under strict re-raises the first error and the later listeners do NOT run.
- once: fires once, honours priority, and is gone on the second emit.
- once re-entrancy (EV-03 witness): a once-listener that re-emits its own event does NOT re-fire (fails
  on current PHP).
- once + async (EV-02 witness): an async once-listener is awaited and fires exactly once under
  `emit_async` (fails on current Python and Ruby).
- emit_async result (EV-01 witness): `emit_async` yields the same results array as `emit` (fails on
  current Ruby, which returns threads).
- Re-entrant register (EV-04 witness): a listener that calls `on()` during an emit does not corrupt the
  in-flight results (fails on current Python).
- off / clear: removing one vs all; unknown-event and unknown-callback are no-ops.
- Internal event: emitting `tina4.request.error` reaches a registered listener with `{exception,
  request}` (already proven per-language; lift into the shared fixture).

## Integration map

- Exports: each language exports the bus (`on`/`emit`/`once`/`off` at minimum; Python's top-level export
  is narrower - EV-09).
- Framework emitters: exactly ONE, `tina4.request.error` with `{exception, request}`, from the
  route-error / 500 path, wrapped in its own try/catch. Identical in all four (the per-language tests
  cross-reference each other as the parity oracle).
- Framework listeners: NONE. The framework subscribes to nothing; the bus is otherwise app-facing.
- CLI: the `generate listener` command scaffolds `src/listeners/<event>.<ext>` application files that
  call `on(...)`. That is generated app code, not framework wiring.
- Documentation: `docs/{python,php,ruby,nodejs}` cover events; the PHP page/CLAUDE.md needs the EV-05
  method-list correction.

## Breaking changes and migration

- EV-01 (Ruby `emit_async` returns results): a Ruby caller that today does `emit_async(...).each(&:join)`
  would change. Provide the join internally and return results; document the one-line migration. Breaking
  for Ruby only, and the surface is niche.
- EV-02 / EV-03 / EV-04: bug fixes that only change incorrect edge behaviour (async once, re-entrant
  once, re-entrant register). No correct program depends on the broken behaviour; ship with the
  regressions.
- EV-06 (empty buckets): `events()` may stop returning zero-listener names. Document it.
- No wire/storage migration exists (there is no persistence).

## Implementation backlog

Dependency-ordered:

1. Write the first Events ADR ratifying the core contract (priority, results, isolation+strict+log, the
   single internal event) and the EV-01..EV-05 decisions.
2. Fix the latent correctness bugs with named regressions in all four: EV-02 (async once, Python+Ruby),
   EV-03 (once timing, PHP), EV-04 (re-entrancy, Python), and unify EV-01 (Ruby return).
3. Author `events_contract.json` and a runner per language; flip owed to proven; add the CONTRACT-MAP
   row.
4. Apply the low-priority items: EV-06 (empty buckets), EV-07 (Ruby key), EV-08 (catch breadth), EV-09
   (Python docstring + exports), and the PHP doc fix (EV-05).

## Porting capsule

A clean-room implementation needs: a per-event ordered list of `{priority, callback, once}`; `on`/`once`
that append and re-sort descending by priority (stable, so equal priorities keep registration order);
`emit` that snapshots the list, removes each once BEFORE calling it, forwards all args, collects results
in priority order, and on a throw either re-raises (strict) or logs a warning and pushes null;
`emit_async` with the same semantics and a results-array return; `off` (by identity, removing all copies,
or the whole bucket) and `clear`; `listeners` (callbacks in priority order) and `events` (names, no empty
buckets); exact-string keys with no wildcard; no env, no persistence, no lock; and one framework emitter
`tina4.request.error` with `{exception, request}` on the route-error path. This packet is sufficient for
a clean-room implementation.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
