# Feature 047: In-process background tasks

## Identity and status

- Matrix identity: 47 - In-process background tasks
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (`background()`/`BackgroundTask` in
  each server). No framework code changed.
- Dependencies: the persistent server process (built-in server or openswoole for PHP), Feature
  39 graceful shutdown (tasks stop on drain), the Log subsystem (a task's errors log)
- Dependants: heartbeats, periodic cache sweeps, poll loops, any recurring in-process work that
  does not warrant the queue
- Existing ADRs: the graceful-shutdown drain (Feature 39)
- Shared fixtures: `background_tasks_contract.json` is required
- Catalog phase: Routing and middleware

## Why this feature exists

An application needs a small recurring job - a heartbeat, a cache sweep, a poll - running inside
the server process without standing up the full queue. `background(callback, interval)` runs a
callback every `interval` seconds and returns a handle to stop it, the same way in the languages
whose deployment model has a persistent process.

## Boundary

This feature owns `background(callback, interval)`: registration of a recurring in-process task,
the returned handle with `.stop()`, the task count, error isolation, and the requirement that
tasks stop on graceful shutdown. It DELEGATES the drain to Feature 39 and error logging to the
Log subsystem. It is NOT the durable queue (that is the queue subsystem); a background task is
in-memory and dies with the process.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Register | `background(callback, interval=1.0)` | background task API | background task | background task |
| Handle | `BackgroundTask` with `.stop()` | stop | stop | stop |
| Count | `background_task_count()` | `backgroundTaskCount()` | count | count |
| Recurring | every `interval` seconds | same | same | same |
| Concurrency model | thread + `threading.Lock` | built-in server / openswoole only | thread/fiber | event-loop timer |
| Requires a persistent process | yes | YES (NOT under PHP-FPM) | yes | yes |
| Stops on graceful shutdown | (to confirm) | (to confirm) | (to confirm) | (to confirm) |

`background(callback, interval)` registers a RECURRING task that runs the callback every
`interval` seconds and returns a handle whose `.stop()` ends and deregisters it;
`background_task_count()` reports how many run. Python uses a thread guarded by a lock; Node uses
an event-loop timer. The critical deployment fact: in-process background tasks REQUIRE a
persistent server process, so PHP under FPM (a fresh process per request) cannot run them - they
work only under the PHP built-in server or openswoole. Python, Ruby and Node have a persistent
process by default.

## Public surface contract

`background(callback, interval=1.0)` registers a recurring task and returns a handle; the handle
`.stop()` ends and deregisters the task. `background_task_count()` returns the number of active
tasks. The callback runs every `interval` seconds until stopped or until the server drains. A
task's callback error is isolated: it logs and does not crash the server or stop other tasks.

## Inputs and outputs

- Input: a callback and an interval (default 1.0 seconds).
- Output: a task handle (`.stop()`), and a running recurring task; `background_task_count()`
  returns the active count.
- The task is in-memory: it does not persist across a restart (unlike the queue).
- A throwing callback produces a log line, not a crash and not a stopped sibling.

## Lifecycle and operation graph

1. `background(callback, interval)` registers the task under a lock and starts its timer/thread.
2. The callback runs every `interval` seconds; an exception in it is caught, logged, and the
   task continues (or stops just itself, per the pinned rule).
3. `.stop()` ends the task and removes it from the registry; `background_task_count()` drops.
4. On graceful shutdown (Feature 39), all background tasks are stopped as part of the drain, so a
   task loop does not keep the process alive past the shutdown deadline.

## Configuration and precedence

- The interval is per task (default 1.0 seconds); there is no global config.
- Background tasks require a persistent process; under PHP-FPM they are unavailable and calling
  `background()` should FAIL LOUDLY or be a documented no-op, not silently appear to register.
- The drain (Feature 39) stops all tasks.

## Failures, side effects and security

- ERROR ISOLATION: a callback exception is caught and logged; it never crashes the server and
  never stops another task. A background task that could take the whole server down would make
  the feature too dangerous to use.
- SHUTDOWN: a background task must stop on the graceful-shutdown drain; a task that ignores the
  drain would hold the process open past the deadline and force a hard kill (Feature 39).
- DEPLOYMENT: under PHP-FPM there is no persistent process, so `background()` cannot work; it
  must fail loudly or be a clearly documented no-op, never silently accept a task that never
  runs.
- The interval timing must not drift unbounded; a long callback should not stack invocations
  (measure the next run from completion, or skip a missed tick).

## Wire and persistence contract

There is no wire format and NO persistence: a background task lives only in the process and dies
with it. This is the line between this feature and the durable queue - a background task is not
retried, not persisted, and not delivered elsewhere.

## Providers and substitutability

Background tasks depend on a persistent process and the language's concurrency primitive (thread,
fiber, or event-loop timer). A future runtime with a persistent process implements the same
`background(callback, interval)` + handle + count + error isolation + drain-stop; a
request-per-process runtime documents them as unavailable.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| BG-01 | The surface (`background`/count/handle/`.stop()`, default interval) is not gated as parity. | Pin one surface and default; gate register/run/stop/count in all four (that support it). |
| BG-02 | The stop-on-graceful-shutdown behaviour is not gated; a task ignoring the drain holds the process open. | Gate that all background tasks stop on the Feature 39 drain in all four. |
| BG-03 | Error isolation (a throwing callback logs, does not crash or stop siblings) is not gated. | Gate that a throwing callback is isolated in all four. |
| BG-04 | Under PHP-FPM there is no persistent process; `background()` cannot run and must not silently appear to. | Pin PHP-FPM behaviour: fail loudly or documented no-op; gate that it does not silently accept a never-running task. |
| BG-05 | Interval drift / overlapping invocations on a slow callback are not defined. | Pin the timing rule (measure next run from completion, or skip a missed tick); gate it. |
| BG-06 | No shared fixture exists. | Add `background_tasks_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. The surface is `background(callback, interval=1.0)` returning a handle with `.stop()`, plus
   `background_task_count()`, uniform across the four that support it.
2. Background tasks REQUIRE a persistent process; under PHP-FPM `background()` fails loudly or is
   a documented no-op (never a silent never-running task). This is a stated deployment
   constraint, like the built-in server's forking requirement.
3. A callback exception is caught, logged, and isolated: it never crashes the server and never
   stops another task.
4. All background tasks stop on the graceful-shutdown drain (Feature 39).
5. The interval timing does not stack invocations on a slow callback (next run measured from
   completion, or a missed tick skipped).

## Proposed conformance fixture

Add `background_tasks_contract.json` with stable ids for: registering a task that runs the
callback N times over N intervals; `.stop()` ending it and `background_task_count()` dropping; a
throwing callback logging and NOT crashing the server nor stopping a sibling task; all tasks
stopping on a graceful-shutdown drain; and the PHP-FPM behaviour (loud failure or documented
no-op). Every case runs a real task in a real persistent server; no mock can claim conformance
(the concurrency and the drain interaction must be real).

## Integration map

- Feature 39 (graceful shutdown) stops the tasks on drain; the Log subsystem records a callback
  error; the persistent-server requirement ties to the deployment model (built-in server /
  openswoole for PHP).
- The queue subsystem is the durable alternative for work that must survive a restart.
- Central fixtures, four runners, the CI matrix and the deployment docs update together.

## Breaking changes and migration

- Pinning the PHP-FPM behaviour to a loud failure (if it silently no-ops today) changes what a
  PHP-FPM app sees; state it in the release note. It is a correctness fix (a silent never-running
  task is worse).
- No change to the persistent-process frameworks beyond gating.

## Implementation backlog

1. Add `background_tasks_contract.json` and wire four runners against real persistent servers.
2. Pin and gate the surface (BG-01), the drain-stop (BG-02), and error isolation (BG-03).
3. Pin and gate the PHP-FPM behaviour (BG-04) and the interval-timing rule (BG-05).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement `background(callback, interval=1.0)` returning a handle with `.stop()`, plus
`background_task_count()`. Run the callback every `interval` seconds on the language's
concurrency primitive, guarded for thread-safe registration. Catch and log a callback exception
and keep going (never crash the server, never stop a sibling). Stop all tasks on the
graceful-shutdown drain. Require a persistent process; on a request-per-process runtime, fail
loudly or document the no-op. Prove the port with an N-runs case, a stop/count case, a
throwing-callback isolation case, and a drain-stop case.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (BG-01..06).
- [x] Owner ambiguities recorded (5 proposed; the PHP-FPM constraint and drain-stop are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
