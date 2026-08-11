# Feature 47: In-process background tasks

## Identity and status

- Matrix identity: 47 - Background tasks (in-process fire-and-forget periodic work, distinct from the durable
  Queue, feature 89)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language source (correcting a prior-session doc that called
  Python's mechanism "a thread + a lock" - it is an asyncio coroutine - claimed PHP "openswoole" support that
  does not exist, and left the shutdown cell unverified though all four resolve it). Python
  `core/server.py:102` `background` + `:234` `background_tick_loop` (`ebbab30`); PHP `Tina4/App.php:1176` +
  `Tina4/Server.php:610` (`6faabac5`); Ruby `lib/tina4/background.rb:22` (`6d5b1de`); Node
  `packages/core/src/background.ts:55` (`27cf0f4`).
- Dependencies: the server run loop (where ticks fire), graceful shutdown (38).
- Dependants: periodic in-process work (cache sweeps, heartbeats) that does not need durability.
- Existing ADRs: none dedicated.

- Catalog phase: Routing and middleware

## Why this feature exists

An app sometimes needs periodic in-process work without a durable queue. The audit questions: does it run
where the app actually deploys, is it stopped cleanly on shutdown, and is the surface the same in all four?
The feature is real in all four, but it SILENTLY DOES NOTHING under the default production server in Python
(and under PHP-FPM/Swoole in PHP), and the surface diverges.

## Existing implementation evidence

Real in all four, but different mechanisms and a production gap:

- PYTHON: `background(callback, interval=1.0) -> BackgroundTask` (`server.py:102`), a handle with `.stop()`
  (`:74`); `background_task_count()` (`:120`), `stop_all_background_tasks()` (`:126`). Runs as an asyncio
  COROUTINE per task (`:234` via `asyncio.create_task`), NOT a thread; a sync callback is offloaded to a
  shared threadpool (`:266`); the `threading.Lock` (`:50`) guards ONLY the registry. CRITICAL:
  `_start_background_tasks` is called at ONE site (`:3697`) inside the built-in asyncio `_serve()`; the
  production ASGI path returns earlier (`:3527-3530`) and the lifespan handler starts nothing - so under
  uvicorn/hypercorn/granian, tasks NEVER START (silent no-op). See the register.
- PHP: `background(callable, interval=1.0): self` (`App.php:1176`) - returns `$this`, NOT a handle; stop by
  callback identity (`stopBackground`, `:1200`); `backgroundTaskCount()` (`:1229`). Runs INLINE in the
  single-threaded `stream_select` accept loop (`Server.php:610` idle branch), no thread. FOOTGUN: under
  PHP-FPM or the Swoole/RoadRunner/FrankenPHP per-request adapter there is no accept loop, so the task
  silently never runs; the prior doc's "openswoole" support is unfounded.
- RUBY: `register/background(callback, interval:)` returns a Hash DESCRIPTOR (`background.rb:27`), NOT a handle
  with `.stop()`; `stop_task`/`stop_all`; there is NO count method (only `tasks`). Runs as a real dedicated OS
  THREAD per task (`:82`), no fiber.
- NODE: `background(callback, intervalSeconds=1): {stop}` (`background.ts:55`), a real handle;
  `stopAllBackgroundTasks()`, `backgroundTaskCount()`. Runs as an event-loop TIMER (re-armed `setTimeout`,
  `unref`'d; `:89-93`), not a thread.
- ERROR ISOLATION: a callback error is caught + logged and never crashes the server, in all four. NON-OVERLAP
  is enforced in all four (await-before-next / re-arm-after-settle / synchronous inline / sequential thread).
- SHUTDOWN: stopped on drain where tasks actually run, proven by REAL graceful-shutdown tests in all four
  (Python built-in server, PHP `GracefulShutdownTest`, Ruby `graceful_shutdown_spec`, Node
  `gracefulShutdown.test`).

## Public surface contract

`background(callback, interval)` schedules periodic in-process work; a handle (or callback identity) stops it;
a count reports how many run; errors are isolated; shutdown stops them. The surface is NOT uniform (see the
register), and the "it runs" guarantee is broken under some production deployments.

## Inputs and outputs

- Input: a callback + an interval. Output: a running periodic task (where the run loop exists) + a stop
  mechanism. NO output under production ASGI (Python) or PHP-FPM/Swoole (PHP) - the task never starts.

## Lifecycle and operation graph

1. Register (append to the registry). 2. Start: Ruby/Node at registration; Python at built-in-server boot
   (NOT under ASGI); PHP in the accept loop (NOT under FPM/Swoole). 3. Tick: run the callback, catch errors,
   do not overlap. 4. Shutdown: stop/cancel/join the tasks.

## Configuration and precedence

- Interval per task (default 1.0s); no global config, no env var, no concurrency cap, in any language.

## Failures, side effects and security

- A callback error is caught + logged; the server does not crash and other tasks continue (all four). No
  security surface. The dangerous failure is SILENT: the task never runs under the default production server
  (Python ASGI, PHP FPM/Swoole) with no error - see the register.

## Wire and persistence contract

None (in-process only). No persisted state; this is NOT the durable queue (89).

## Providers and substitutability

Runtime-level. A future runtime should run background tasks under its ACTUAL production server (not only a dev
built-in), expose one surface (a stop-handle + a count), isolate errors, and stop them on shutdown.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| BG-PY-PROD-NOOP | Python `background()` tasks are REGISTERED but NEVER STARTED under the default production ASGI server (uvicorn/hypercorn/granian): `_start_background_tasks` is called only inside the built-in asyncio `_serve()` (`server.py:3697`); the production path returns earlier (`:3527-3530`) and the ASGI lifespan startup starts nothing. So `background()` is a SILENT no-op in production, and the graceful-shutdown tests exercise only the built-in server, so it is untested. | Start background tasks from the ASGI lifespan startup (and stop them on lifespan shutdown), or loudly warn/document that they require the built-in server. |
| BG-PHP-FPM-SWOOLE-NOOP | PHP `background()` appends with NO deployment guard (`App.php:1178`); under PHP-FPM (per-request) or the Swoole/RoadRunner/FrankenPHP adapter (`App.php:1423-1484`, per-request, never calls `runTickCallbacks`) there is no accept loop, so the task silently never runs. The prior doc's "openswoole" background support is unfounded. | Detect a non-persistent SAPI and warn (or refuse) at `background()` registration; correct the openswoole claim. |
| BG-PY-ASYNC-NOT-THREAD | The prior doc states Python runs "a thread guarded by a lock"; FALSE - it is an asyncio coroutine (`server.py:234` via `create_task`); the `threading.Lock` guards only the registry, and only a SYNC callback touches a threadpool. | Correct the doc: Python is an event-loop coroutine, not a thread-per-task. |
| BG-SURFACE-DIVERGE | The surface diverges: Python/Node return a stop-HANDLE; PHP returns `$this` (stop by callback identity); Ruby returns a Hash descriptor (no `.stop()`); Ruby has NO count method (only `tasks`, so a caller uses `.length`). The prior doc's uniform "stop"/"count" cells hide this. | Pin ONE surface (a handle with `.stop()` + a `count`) across the four (Ruby gains a handle + count; PHP gains a handle). |
| BG-PHP-FPM-FOOTGUN | (Subsumed by BG-PHP-FPM-SWOOLE-NOOP) the prior doc's BG-04 (PHP-FPM silently registers a never-running task) is CONFIRMED real and open. | See BG-PHP-FPM-SWOOLE-NOOP. |
| BG-OVERLAP-STALE | The prior doc's BG-05 says interval-drift / overlapping invocations "are not defined"; the CODE defines NON-OVERLAP in all four (await-before-next `server.py:275`, re-arm-after-settle `background.ts:70-86`, synchronous inline PHP, sequential thread Ruby). Only the shared FIXTURE is missing, not the behaviour. | Gate non-overlap with a fixture; drop the "not defined" framing. |
| BG-NO-FIXTURE | No shared `background_tasks_contract.json` exists; nothing gates the surface, error isolation, non-overlap, or stop-on-shutdown. | Add it once BG-DEC-01/02 land. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- BG-DEC-01 (proposed, THE call - a silent production no-op): make Python `background()` actually run under the
  default production ASGI server (BG-PY-PROD-NOOP) by starting tasks from the lifespan startup, and guard/warn
  PHP under PHP-FPM/Swoole (BG-PHP-FPM-SWOOLE-NOOP). Today the feature silently does nothing in the common
  production deployment for two of four languages.
- BG-DEC-02 (proposed): pin ONE surface - a stop-handle + a count - across the four (BG-SURFACE-DIVERGE);
  correct the Python-thread (BG-PY-ASYNC-NOT-THREAD) and PHP-openswoole claims; add the shared fixture gating
  the surface, error isolation, non-overlap, and stop-on-shutdown (BG-OVERLAP-STALE, BG-NO-FIXTURE).

## Proposed conformance fixture

A shared fixture (real server): a registered task ACTUALLY RUNS under the language's PRODUCTION server (catches
BG-PY-PROD-NOOP and BG-PHP-FPM-SWOOLE-NOOP), a callback error is isolated (the server survives, other tasks
continue), invocations do not overlap, and the task is stopped on graceful shutdown (exit 0, no leaked
thread/timer). The surface (handle `.stop()` + count) is identical across the four.

## Integration map

- Consumers: periodic in-process work. Composes: the server run loop (where ticks fire), graceful shutdown
  (38). Distinct from the durable Queue (89).

## Breaking changes and migration

- Starting Python tasks under ASGI changes behaviour (they now run in production) - a correctness fix, note
  it. Pinning the surface (Ruby/PHP gain a handle; Ruby gains a count) is additive. Guarding PHP under FPM is
  a new warning.

## Porting capsule

Background tasks must RUN under the language's ACTUAL production server (not only a dev built-in - the Python
ASGI and PHP-FPM/Swoole silent-no-op bug), expose ONE surface (`background(cb, interval)` returning a handle
with `.stop()`, plus a `count`), isolate a callback error (catch + log, never crash the server, other tasks
continue), never overlap invocations (await/re-arm after each run), and stop cleanly on graceful shutdown.
Prove it with a task that runs under the production server, an error that is isolated, and a clean stop on
shutdown.

## Audit closure checklist

- [x] Boundary and public surface complete (background + stop + count x four).
- [x] Lifecycle and producer/consumer edges complete (register -> start -> tick -> stop) - INCLUDING the
  production start gap.
- [x] Configuration (none), failure (silent prod no-op) and security rules complete.
- [x] Wire (none, in-process) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (asyncio not thread; prod no-op; surface diverges) -
  correcting the prior thread/openswoole claims and the unverified shutdown cell.
- [x] Owner ambiguities decided (BG-DEC-01 prod-run, BG-DEC-02 surface).
- [x] Conformance fixture (runs-in-prod + isolation + shutdown) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
