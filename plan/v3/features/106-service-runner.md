# Feature 106: Service runner

## Identity and status

- Matrix identity: 106 - Service runner (long-running named background services with cron / interval /
  daemon scheduling and a lifecycle)
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-11 at Python `service/__init__.py` (578), PHP
  `Tina4/ServiceRunner.php` (596) + `Service.php` (87), Ruby `lib/tina4/service_runner.rb` (338) +
  `service.rb` (60), Node `packages/core/src/service.ts` (475). SVC-01 was self-verified on the Python
  master (`stop()` references no instance and calls no `.stop()`). Suites are reported, not re-run.
- Dependencies: the logger (Python/PHP/Ruby log listener errors; Node does not); the cron matcher (per
  language); the discovery directory. Sibling of the simpler `background()` periodic-task mechanism.
- Dependants: application code only. No framework subsystem starts a service; the CLI scaffolds service
  files but never runs them.
- Existing ADRs: none.
- Shared fixtures: NONE. `service_contract.json` is owed. Each language has a real, no-mock suite
  (Python 49, PHP 50, Ruby 41, Node ~40 assertions), yet NONE starts a class-based `Service` through the
  runner - the exact gap that hides SVC-01 and SVC-02.

- Catalog phase: Developer internals

## Why this feature exists

The service runner runs the daemons an application needs alongside its web server: a queue drainer, a
nightly report, a health poller. You register a named service with a schedule - an interval, a cron
expression, or "daemon" (the service owns its own loop) - and the runner starts each one, retries it if
it crashes, and is supposed to stop it on shutdown.

It is the heavier sibling of `background()`. `background()` runs a simple interval callback inside the
server's own loop and is wired into graceful shutdown. The service runner adds cron, per-service retry,
filesystem discovery, a daemon mode, and a class-based `Service` contract - but, as this audit finds, it
is not wired into shutdown in any language, and its class-based contract is broken in all four.

## Boundary

This packet owns the `ServiceRunner` (register / start / stop / discover / list) and the `Service` base
class (the `run` / `stop` / `should_stop` contract) in each language, plus the cron matcher and the
per-service scheduling loop.

It does NOT own: the `background()` mechanism (a separate, lifecycle-wired periodic API); the queue
consumer (a separate daemon path); the CLI `generate service` scaffolder; the framework's signal
handling (which never calls the runner). The runner is a callee of application code only.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Runner type | instance (`ServiceRunner()`) | static (`ServiceRunner::`) | class-methods (global) | static (`ServiceRunner.`) |
| Execution model | `threading.Thread` per service | `pcntl_fork` process per service (start-all); foreground blocking (start-named) | `Thread` per service | `setInterval` timers, single event loop |
| Service base | `Service.run` abstract | `Service::run` abstract | `Service#run` abstract | `Tina4Service.run` abstract |
| register signature | kwargs (interval, cron, daemon, max_retries) | options array | options hash + block | options object |
| Class-based start | stores handler=instance (callable) | stores `asCallable()` | stores `method(:run)` - ARITY BUG (SVC-02) | stores `asHandler()` |
| Class-based stop routing | stored, never called (SVC-01) | stored, never read (SVC-01) | stored, never read (SVC-01) | stashed, never read (SVC-01) |
| Wired to shutdown | no | no | no | no |
| Focused tests | 49 real | 50 real | 41 real | ~40 real |

## Public surface contract

The intended shared surface: `register(name, handler, options)` for a callable service and
`register_service(name, service, options)` for a `Service` subclass (which must implement `run`);
`start(name?)` / `stop(name?)`; `discover(dir)` to load `src/services`; and `list` / `is_running` /
`clear`. A service runs on an interval, on a cron expression, or as a daemon (its own loop), selected by
options. `register_service` forces daemon mode. A `Service` subclass gets `stop()` / `should_stop()`
from the base to cooperate with shutdown.

The surface diverges in spelling and shape: Python uses keyword arguments and is instance-based; PHP,
Ruby, and Node use an options map and are static/global; PHP adds PID-file management and `shutdown` /
`reset`; Node adds `watch` / `unwatch` hot-reload; Ruby adds a `Tina4.service` DSL. The registration
shape (kwargs vs options map) and the instance-vs-static split are findings below.

## Inputs and outputs

- `register` input: a name, a callable (receiving a service context), and scheduling options. Output:
  void.
- `register_service` input: a name and a `Service` instance. Output: void. This path is BROKEN (SVC-01
  everywhere; additionally SVC-02 in Ruby).
- `start` / `stop` output: void; they spawn or signal the per-service worker.
- `list` output: per-service metadata (name, running, last run, error count). `is_running` output: bool.
- The service context passed to a callable exposes at least `running` (a cooperative stop flag) and
  `name`; the exact shape is not identical across languages (part of the missing contract).

## Lifecycle and operation graph

1. `register` / `register_service` / `discover` populate a registry.
2. `start` iterates the registry (insertion order) and launches each service in the language's execution
   model (thread, fork, or timer). Double-start is guarded everywhere except PHP.
3. Each worker loops per its mode: interval (sleep then run), cron (poll and run when the expression
   matches), or daemon (run once, the handler owns its loop).
4. A crash is caught, counted, and retried up to `max_retries` (default 3) with a fixed backoff; a
   consecutive success resets the counter; exhausting retries stops that service and leaves the others.
5. `stop` signals the cooperative flag and waits (a hardcoded 5s join in Python/Ruby; SIGTERM in PHP;
   `clearInterval` in Node), then forgets the worker. It does NOT route to a class-based service's own
   `stop()` (SVC-01), and no signal handler calls `stop` at all (SVC-SHUTDOWN).

## Configuration and precedence

- `TINA4_SERVICE_DIR` (default `src/services`) - the discovery directory. Read in all four.
- `TINA4_SERVICE_SLEEP` (default 5s) - the cron poll cadence. Read in PHP, Ruby, and Node; NOT read in
  Python (Python hardcodes its backoff and cron re-check). This is SVC-ENV.
- Everything else is a per-service option or a code literal: `max_retries` default 3, interval default
  60s, the 5s shutdown join, the retry backoff (Python 2s, Ruby 1s, PHP `TINA4_SERVICE_SLEEP`, Node
  none). No env governs worker count or the shutdown drain.

## Failures, side effects and security

- SVC-01 (universal, self-verified on Python): a class-based `Service` registered via
  `register_service` cannot be stopped by `ServiceRunner.stop()` in ANY language. Each stores the
  instance with a comment promising `stop()` routes to it, but `stop()` never reads the instance and
  never calls its `stop()`. The runner flips its own context flag, which is a DIFFERENT object from the
  service's `_running`, so a `while not should_stop()` loop never exits. Result: a leaked thread
  (Python/Ruby), a hard-killed fork (PHP), or an infinite loop (Node).
- SVC-02 (Ruby, severe): Ruby's `register_service` stores `service.method(:run)`, a strict zero-arg
  `Method`, but the runner calls `handler.call(ctx)` with one argument, raising `ArgumentError` on every
  invocation. The crash is retried 3 times and the service dies. The documented class-based pattern never
  runs at all in Ruby. (The lenient `to_proc` path exists but is not the one registered.)
- Error handling: a crashing handler is caught and retried in all four; Python, PHP, and Ruby LOG the
  error (warning/error), but Node SILENTLY SWALLOWS it (the caught error is never logged - no logger in
  the file), contradicting the framework's log-loud policy (SVC-LOG).
- Daemon-died-silently footgun: a daemon that throws once (below `max_retries`) leaves the service marked
  running with nothing rescheduling it, so `is_running()` reports true for a dead service (sharpest in
  Node, present in the daemon modes generally).
- Shutdown (SVC-SHUTDOWN): NONE of the four is wired into the framework's signal handling. On SIGTERM the
  framework stops `background()` tasks but never the runner. The drain is a hardcoded 5s join in
  Python/Ruby with NO kill fallback (the thread leaks; Ruby even documents a `join || kill` in its
  sibling `Background` but does not use it here), a SIGTERM hard-kill with no drain in PHP, and a bare
  `clearInterval` (no in-flight drain) in Node.
- Re-entrancy: Node's timer ticks are fire-and-forget (not awaited), so a slow async tick overlaps the
  next with no guard.
- No security surface: process-local, no untrusted input executed. (PHP forks and writes PID files under
  `data/services`; no privilege change.)

## Wire and persistence contract

There is no wire format. The only persistence is PHP's PID files under `data/services` (to track forked
children for SIGTERM); Python, Ruby, and Node keep state in memory only. State does not survive a
restart. The cron expression is a 5-field string parsed per language.

## Providers and substitutability

There is no external provider. The execution model IS the substitution axis, and it is inherently
language-specific: OS threads (Python, Ruby), forked processes (PHP, because PHP has no threads), or
event-loop timers (Node, single-threaded). This divergence is defensible per language, but it means the
runtime SEMANTICS differ (true parallelism vs cooperative interleaving vs separate memory), and the
SERVICE CONTRACT that should paper over it (what the context exposes, how stop is observed) is not
uniform - which is what makes SVC-01 land differently in each.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SVC-01 | UNIVERSAL BUG (all four, self-verified on Python): a class-based `Service` cannot be stopped through `ServiceRunner.stop()`. Every language stores the instance "so stop() can route to service.stop()" but never calls it; `stop()` flips the runner's context flag, not the service's `_running`. The documented pattern hangs/leaks on shutdown. No test starts a class-based service through the runner, so it ships unverified everywhere. | FIX all four: `stop()` must call the stored instance's `stop()` (and/or bridge the runner context to the service's flag). Add the missing regression in all four: register a `Service` subclass, `start()`, then `stop()`, and assert the loop actually exits within the drain. |
| SVC-02 | RUBY, SEVERE: `register_service` stores `service.method(:run)` (strict zero-arg) but the runner calls it with `(ctx)`, raising `ArgumentError` every invocation; retried 3x then dead. The documented class-based service NEVER runs in Ruby. | FIX Ruby: register `service.to_proc` (a Proc ignores the extra arg) or make `Service#run` accept an optional context, matching the callable contract. Covered by the same SVC-01 regression once it actually starts. |
| SVC-EXEC | The execution model diverges three ways: threads (Python, Ruby), forked processes (PHP), event-loop timers (Node). Inherent to each language, but the runtime semantics and the service context differ. | OWNER DECISION (SVC-DEC-02): accept the language-native execution model but RATIFY a uniform service contract - the context fields, the cooperative-stop semantics, the retry/backoff policy - so a service written to the contract behaves the same everywhere. Document the per-language execution model. |
| SVC-STATIC | Python is the lone instance-based runner (`ServiceRunner()`); PHP, Ruby, and Node are static/global. A program written against one does not port to the other. | OWNER DECISION (SVC-DEC-03). Recommendation: align on one model (the DI container, feature 105, has the same split - resolve them together). Given 3-of-4 are static/global, either make Python static too or offer both a default and instances everywhere. |
| SVC-SHUTDOWN | No language wires the runner into graceful shutdown; on SIGTERM the framework stops `background()` but not services. The drain is a hardcoded 5s join with no kill fallback (Python/Ruby leak the thread), a hard-kill with no drain (PHP), or a bare timer clear (Node). | OWNER DECISION (SVC-DEC-04): wire `ServiceRunner.stop()` (all services) into the framework's SIGTERM/SIGINT handler, add a kill/force fallback after the drain (Ruby already has `join || kill` in `Background` to copy), and honour `TINA4_SHUTDOWN_TIMEOUT` for the drain instead of a hardcoded 5s. Or explicitly document that the app owns service shutdown. |
| SVC-LOG | Node silently swallows a crashed handler's error (no logger in the file); Python, PHP, and Ruby log it. | FIX Node: log the caught error via the framework logger, matching the log-loud policy and the other three. |
| SVC-DOUBLESTART | PHP does not guard double-start (it forks/re-runs unconditionally); Python, Ruby, and Node guard it. | FIX PHP: guard on `isRunning()` before starting, matching the other three. |
| SVC-ENV | Python does not read `TINA4_SERVICE_SLEEP` (PHP, Ruby, Node do); its backoff/cron cadence is hardcoded. | FIX Python: read `TINA4_SERVICE_SLEEP` for the cron poll cadence, matching the other three. |
| SVC-SURFACE | Registration shape diverges: Python keyword args vs an options map (PHP/Ruby/Node); method sets drift (PHP PID/shutdown/reset, Node watch/unwatch, Ruby `clear!`/DSL). | OWNER DECISION (SVC-DEC-05): pick one registration shape (an options map is the 3-of-4 consensus) and a core method set; keep language-appropriate extras but document them as non-core. |
| SVC-FIXTURE | No `service_contract.json`, no CONTRACT-MAP row, no ADR. Four real suites, none of which starts a class-based service through the runner. | Add `service_contract.json` (below) and the first ServiceRunner ADR. |

## Owner decisions

- SVC-DEC-01 (proposed): fix the correctness bugs - SVC-01 (all four), SVC-02 (Ruby), SVC-LOG (Node) -
  with the missing class-based-start-then-stop regression in all four.
- SVC-DEC-02 (proposed): ratify a uniform service contract over the language-native execution models.
- SVC-DEC-03 (proposed): align the instance-vs-static model (with feature 105).
- SVC-DEC-04 (proposed): wire the runner into graceful shutdown with a kill fallback and
  `TINA4_SHUTDOWN_TIMEOUT`, or document app-owned shutdown.
- SVC-DEC-05 (proposed): unify the registration shape (options map) and core method set; add
  `TINA4_SERVICE_SLEEP` to Python; add the PHP double-start guard.

## Proposed conformance fixture

`service_contract.json` - the same scripted sequence per language against a real runner (no doubles;
real threads/forks/timers, a real service file on disk). Cases:

- Callable interval: register a fast-interval handler, start, observe it ran at least twice, stop, assert
  it stops.
- Class-based service (SVC-01 + SVC-02 witness): register a `Service` subclass whose `run` loops
  `while not should_stop()`, start, assert it runs, stop, assert the loop EXITS within the drain (fails
  on all four today; also fails to start on Ruby).
- Cron: a cron service fires on a matching minute and not otherwise.
- Retry: a handler that throws is retried up to `max_retries` then the service stops; a success resets
  the counter; the error is LOGGED (fails on Node today).
- Double-start: starting twice does not double-run (fails on PHP today).
- Discovery: a real service file under `TINA4_SERVICE_DIR` is discovered and started.
- Shutdown drain: `stop()` returns within the drain and leaves no running service (witnesses
  SVC-SHUTDOWN behaviour per the ratified policy).
- Context contract: the handler's context exposes the ratified fields and the cooperative stop flag.

## Integration map

- Exports: each language exports `ServiceRunner` and the `Service` base (Ruby also `Tina4.service`; Node
  also the cron helpers and types).
- Framework use: NONE starts a service. Not on the auto-discover path, not in server boot, not in the
  signal handler. This is uniform and is itself the SVC-SHUTDOWN concern.
- CLI: `generate service` scaffolds `src/services/*` files whose own comments tell the app to call
  `discover()` + `start()` itself. No CLI command runs the runner.
- Sibling mechanisms: `background()` (lifecycle-wired periodic tasks) and the queue consumer (a separate
  daemon path) both overlap the runner's purpose; the docs steer periodic work to `background()`.
- Documentation: the CLAUDE.md service sections and the `register_service` docblocks claim the class-
  based `stop()` is wired - false (SVC-01); correct them with the fix.

## Breaking changes and migration

- SVC-01 / SVC-02 / SVC-LOG: bug fixes. No correct program depends on a service that cannot stop, a Ruby
  service that never starts, or a swallowed error. Ship with the regressions.
- SVC-STATIC (if Python moves to static) and SVC-SURFACE (options map): breaking for the language that
  changes; document the migration. These are the reason those are owner decisions, not silent fixes.
- SVC-SHUTDOWN wiring: additive (services start being stopped on SIGTERM); a service that relied on
  surviving shutdown would change - document it.
- No persistence migration (PHP PID files are ephemeral).

## Implementation backlog

Dependency-ordered:

1. Write the first ServiceRunner ADR settling SVC-DEC-02..05 (contract, model, shutdown, surface).
2. Fix the correctness bugs with the missing regression in all four: SVC-01 (route stop to the
   instance), SVC-02 (Ruby arity), SVC-LOG (Node logging).
3. Align the small divergences: PHP double-start guard, Python `TINA4_SERVICE_SLEEP`, the options-map
   surface.
4. Wire graceful shutdown (SVC-DEC-04) with a kill fallback and `TINA4_SHUTDOWN_TIMEOUT`.
5. Author `service_contract.json` and a runner per language; flip owed to proven; add the CONTRACT-MAP
   row.

## Porting capsule

A clean-room implementation needs: a named registry of `{handler, options}`; `register` (callable) and
`register_service` (a `Service` subclass whose `run` is the loop) that BOTH end up callable with the
service context AND whose `stop()` the runner actually calls; `start` that launches each service in the
language's model (thread / fork / timer) with a double-start guard; the three scheduling modes (interval,
cron via a 5-field matcher polled every `TINA4_SERVICE_SLEEP`, daemon own-loop); crash handling that
logs, retries to `max_retries` with a fixed backoff, and resets on success; `discover` over
`TINA4_SERVICE_DIR`; `stop` that signals the cooperative flag, routes to the service instance's `stop()`,
drains within `TINA4_SHUTDOWN_TIMEOUT`, and force-kills after; and integration into the framework signal
handler. The class-based contract must be started AND stopped by a real test. This packet is sufficient
for a clean-room implementation once SVC-DEC-01..05 are settled.

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
