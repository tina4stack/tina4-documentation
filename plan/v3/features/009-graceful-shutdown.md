# Feature 009: Graceful shutdown

## Identity and status

- Matrix identity: 9 — Graceful shutdown and signal handling
- Audit state: decision-ready; implementation is deliberately deferred
- Release boundary: v3 / 3.14.0; parity-breaking corrections are permitted
- Dependencies: Feature 1 dotenv, Feature 8 health/readiness and the active
  server/worker transport
- Dependants: background tasks, WebSockets, queues, services, database/cache/
  session clients, logging and generated deployments
- Existing decision: ADR-0017 (state-machine/deadline/validation/hook/worker clauses superseded by ADR-0047)
- Current shared executable fixture: none
- Re-audit date: 2026-08-10

Feature 9 is **not complete**. The original audit repaired serious
single-process defects and its real-signal suites remain green, but this
re-audit reached the deployment paths those suites omit. Node's actual
`TINA4_PRODUCTION=true` cluster drops an in-flight request when the container's
primary PID receives SIGTERM. Python's uvicorn path did not accept the audited
WebSocket upgrade, so it cannot send the promised 1001 close frame. Ruby and
Node disagree with ADR-0017 by accepting a zero-second timeout, only PHP has an
application shutdown hook, programmatic close is not one portable lifecycle,
and no shared fixture proves any of it.

This audit changes no framework source. It defines the clean-room lifecycle,
the executable parity plan and the implementation formula for every current or
future Tina4 language.

## Owner decisions APPROVED (finalized 2026-08-10)

Feature 9 carried its decisions in the prose. The review surfaced three; Andre
settled them.

- **A: ADR-0017 is SUPERSEDED by a new ADR-0047, not amended in place** (the third
  such supersession, after ADR-0014 -> ADR-0045 and ADR-0016 -> ADR-0046). ADR-0047
  records the six-state machine, the deadline model below, fail-on-invalid timeout
  validation, the programmatic/hook surface, the worker supervisor and long-running
  modes; ADR-0017 keeps a Superseded-by pointer.
- **B: the budget is a bounded DRAIN plus a guaranteed CLEANUP reserve, not one
  whole-lifecycle deadline.** `TINA4_SHUTDOWN_TIMEOUT` stays the total budget measured
  from `QUIESCING` (k8s grace = timeout + 5 unchanged), but the drain is bounded by
  `timeout - reserve` and cleanup (hooks, resource close, final log flush) is
  guaranteed the reserve, so a slow drain can never starve it. The reserve is
  `min(5s, timeout/4)`, identical in all four for parity. Production adapters map the
  DRAIN portion (`timeout - reserve`) to the server's native graceful timeout (uvicorn
  `timeout_graceful_shutdown`, Puma `force_shutdown_after`); cleanup runs after, within
  the reserve. This is what makes the guarantee hold on third-party servers, where the
  native knob bounds only the drain.
- **C: reverse-dependency order is authoritative for cleanup; logging is pinned last.**
  The closeable registry closes each resource before those it depends on, with
  reverse-registration as the tiebreak for independent resources, and logging always
  closed last so every prior step can still log. The category list (queues/backplanes
  -> DBs -> cache/session -> logging) is the expected illustration, not a separate rule.

FINAL bar unchanged: publish ADR-0047, materialize `shutdown_contract.json`, wire the
four runners, and pass the real-signal/container/broker lab matrix.

## Why this feature exists

An engineer should be able to stop a Tina4 application without knowing which
web server, worker model or language runtime currently owns the socket. Tina4
must stop admitting work, finish work it already accepted within a bounded
period, tell persistent clients it is leaving, release every framework-owned
resource and report an honest process outcome.

This is not just a web-server nicety. A rolling deployment, queue worker,
service runner, Ctrl-C during development and an explicit application stop all
need the same lifecycle. Requiring application developers to install signal
handlers, await a language-specific close primitive or remember which database
and queue handles Tina4 opened misses the framework's production-ready and DX
principles.

## Boundary

Feature 9 owns:

- the shutdown state machine and exactly one lifecycle coordinator per process;
- SIGTERM and SIGINT ownership for Tina4-owned processes;
- programmatic shutdown and application shutdown hooks;
- listener admission stop, in-flight accounting and deadline enforcement;
- worker/cluster propagation, respawn suppression and straggler termination;
- background/service/queue-consumer quiescing and draining;
- WebSocket close code 1001 during normal shutdown;
- the framework-owned resource cleanup registry and ordering;
- shutdown logging and exit semantics;
- production-server adapter configuration and lifecycle hooks;
- Docker PID 1 signal delivery and generated Kubernetes grace settings;
- executable parity data and language-runner reports.

It delegates:

- path/status behavior of liveness and readiness to Feature 8;
- HTTP dispatch and response completion to Feature 6;
- the actual `close` operation of a database, queue, cache, session store,
  WebSocket backplane or logger to its owning feature;
- at-least-once job acknowledgement/redelivery to the queue contract;
- production server internals to uvicorn/Hypercorn/Granian, Puma and equivalent
  language-native servers;
- Rust CLI child-process-tree cleanup to the Tina4 CLI.

Those features must register resources or in-flight work with Feature 9; they
must not install competing SIGTERM handlers.

## Current implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Built-in server coordinator | `core/server.py` | `Tina4/Server.php` | `lib/tina4/shutdown.rb` | `core/src/server.ts` |
| Production transport | uvicorn/Hypercorn/Granian | Tina4 server/worker pool | Puma | `node:http` cluster |
| Real-signal focused suite | 20 passed | 14 tests / 95 assertions | 11 examples | 23 passed |
| Production-variant suite | uvicorn included above | worker pool: 7 / 23 assertions | Puma: 8 examples | cluster startup: 2 tests |
| SIGTERM drains single server | yes | yes | yes | yes |
| SIGTERM drains production workers | unproven beyond one uvicorn process | only pool exit/port proven | HTTP proven under Puma | **no** |
| WebSocket 1001, built-in | yes | yes | yes | yes |
| WebSocket 1001, production | **no proof; lab upgrade returned 404** | same server | structurally too late/unproven under Puma | unproven in cluster |
| Positive timeout only | yes | yes | **no: zero accepted** | **no: zero accepted** |
| Portable application hook | no | `App::onShutdown` only | no | no |
| Awaitable programmatic lifecycle | no common surface | no common surface | no common surface | `close()` returns immediately |
| Shared fixture/checker | no | no | no | no |

Audited source heads were Python `29feeab`, PHP `c75c7b0e`, Ruby `ea3aa88` and
Node `813b50b`, all on staging `v3`. Python's unrelated local `uv.lock` change
was preserved and excluded from this audit.

The serialized lab ran as root through `/root/tina4-lab/with-lab-lock.sh` on
Linux with real child processes, signals and sockets. The focused total was 68
tests/examples plus 95 PHP assertions. Additional production suites were green,
but the adversarial cluster probe sent SIGTERM only to Node's primary PID while
a four-second request was running:

```text
primary exit      143
in-flight request TypeError: fetch failed
new connection    refused
```

That is the container behavior: Kubernetes asks the runtime to signal process
1, not every descendant as a process group. The existing Node shutdown suite
sets `TINA4_PRODUCTION` off and signals the complete detached process group, so
it cannot detect this failure.

The organization issue sweep found no open issue specifically tracking this
Feature 9 regression. Existing server issues concern separate CLI/PHP-FPM and
malformed-request paths; absence of an issue is not evidence of parity.

## Platform authority

Kubernetes sends the configured stop signal—SIGTERM by default—to process 1,
marks terminating endpoints not ready, and sends SIGKILL to processes still
running after the grace period. The grace countdown includes any `preStop`
hook. See the current
[Kubernetes Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
and [container lifecycle hook](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
documentation.

Node documents that `server.close()` stops accepting new connections and waits
for active HTTP work, while `closeAllConnections()` is forceful and does not
close upgraded WebSocket/HTTP2 sockets. See the
[Node HTTP server documentation](https://nodejs.org/api/http.html#serverclosecallback).

RFC 6455 defines WebSocket close code 1001 for an endpoint going away, including
a server going down. The existing ADR decision remains correct; see
[RFC 6455 section 7.4.1](https://www.rfc-editor.org/rfc/rfc6455.html#section-7.4.1).

ASGI lifespan provides startup and shutdown messages but does not replace the
server's own signal/drain implementation. Tina4 uses it for resources the ASGI
server cannot know about; see the
[ASGI lifespan specification](https://asgi.readthedocs.io/en/latest/specs/lifespan.html).

## One state machine

Every Tina4-owned long-running process has one atomic lifecycle:

```text
STARTING -> RUNNING -> QUIESCING -> DRAINING -> CLEANUP -> STOPPED
                                      |                     ^
                                      +---- deadline --------+
```

- `STARTING`: resources may initialize; startup failure is not a graceful stop
  and exits non-zero after best-effort cleanup.
- `RUNNING`: listeners, workers and schedulers may accept new work.
- `QUIESCING`: entered exactly once by SIGTERM, SIGINT or programmatic shutdown;
  admission and scheduling stop immediately.
- `DRAINING`: work accepted before the transition may finish within the drain
  deadline (the total timeout minus the cleanup reserve).
- `CLEANUP`: application hooks and framework-owned resources close in defined
  order within the guaranteed cleanup reserve.
- `STOPPED`: completion is observable and the owning process can exit.

Repeated shutdown requests are idempotent. They neither install another timer
nor repeat hooks/cleanup. SIGKILL is intentionally unhandled. SIGHUP remains
untrapped by Tina4; file watching belongs to the Rust CLI and log rotation must
not require an application-level competing signal handler.

Exactly one coordinator owns INT/TERM for each process role. A constructor,
background helper, queue class, CLI wrapper and application callback may not
each install their own handler. Where a third-party production server owns the
signals, Tina4 installs no competing handlers and integrates through that
server's supported configuration and lifecycle hooks.

## Canonical shutdown sequence

The coordinator performs these phases in order:

1. Atomically enter `QUIESCING`, capture the monotonic start/deadline and log
   the reason.
2. Mark Feature 8 readiness unavailable. If an already accepted connection can
   still ask `/ready`, it receives 503.
3. Close every public/AI/listener socket and stop worker respawn. A new TCP
   connection is refused; an existing keep-alive connection cannot begin a new
   application request after quiescing.
4. Tell every worker/service/consumer to quiesce. Stop polling and scheduling
   new background/queue/service work.
5. Send WebSocket close frame 1001 with reason `server shutting down`, including
   application, dev-reload and backplane-managed connections.
6. Drain HTTP requests, the currently executing background/service callback and
   the currently claimed queue job. A completed queue job is acknowledged;
   work cut off by the deadline remains unacknowledged for at-least-once
   redelivery.
7. Run application shutdown hooks in reverse registration order.
8. Close framework-owned resources in reverse dependency order (close each before
   the resources it depends on), using reverse-registration as the tiebreak for
   independent resources, and always flush/close logging last. The typical result
   is queue consumers/backends and WebSocket backplanes, then named/default
   databases, then process-owned cache/session clients, then logging.
9. Log `shutdown_completed` with elapsed time, outcome and remaining counts,
   resolve the programmatic completion and exit according to the owner table.

Listener closure comes before WebSocket frames because upgraded connections no
longer depend on the listening socket. The order rejects late work immediately
while still giving existing peers an explicit departure signal.

No cleanup exception aborts the remaining cleanup. Every failure is logged with
resource/hook identity and redacted error details. A shutdown hook cannot
re-open admission, register new work or extend the deadline.

## Timeout contract

`TINA4_SHUTDOWN_TIMEOUT` is the total budget for the **whole shutdown lifecycle**,
measured with a monotonic clock from the first transition into `QUIESCING`, not a
fresh timer around only the HTTP drain. Within that total the drain phase is bounded
by `timeout - reserve` and cleanup (hooks, resource close, final log flush) is
guaranteed a `reserve` of `min(5s, timeout/4)`, so a slow drain can never starve
cleanup. The reserve is identical in all four languages.

- unset or empty selects 30 seconds;
- a configured value is a finite native Feature 1 number greater than zero;
- invalid, zero or negative configuration fails startup outright;
- fractional seconds are accepted by Tina4-owned servers;
- a third-party whole-second setting receives `ceil(value)`, never truncation or
  banker rounding to a shorter grace period;
- the deadline is resolved once at startup and cannot change mid-shutdown.

This intentionally supersedes ADR-0017's “warn and fall back” rule via ADR-0047.
The approved Feature 1 principle is that invalid configuration must fail when the
developer expects it to work. A misspelled shutdown budget must not silently become 30,
and an explicit zero must not mean immediate request loss in only Ruby and Node.

At the drain deadline (`timeout - reserve`) Tina4 logs `shutdown_timeout` with
remaining HTTP, background, job, worker and WebSocket counts; force-closes network
connections; cancels what the runtime can cancel; and leaves an interrupted claimed
job unacknowledged. Cleanup then runs within the reserve; if cleanup itself exceeds
the reserve, Tina4 performs bounded best-effort resource/log close and completes the
process outcome. It does not wait indefinitely in a thread-pool destructor, user
hook, database driver or worker join after a deadline is real.

## Signals, process trees and exit status

| Process/socket owner | SIGTERM/SIGINT after completed or bounded shutdown |
| --- | --- |
| Tina4 built-in single server | exit 0 |
| Tina4 primary/supervisor | quiesce all descendants, wait/force within the one deadline, exit 0 |
| Tina4 worker | report completion to parent and exit 0; never respawn during shutdown |
| Third-party server | preserve its documented post-drain status/signal behavior |
| Programmatic shutdown | resolve successfully and leave exit choice to the caller |
| Startup/fatal failure | non-zero; cleanup must not disguise the failure as success |
| SIGHUP default disposition | terminated by signal, non-zero |

Cluster/supervisor behavior is part of the feature, not a deployment option
outside it. The primary receives the real container signal, disables respawn,
requests graceful worker shutdown, waits for acknowledgements/exit using the
same absolute deadline, then force-kills only stragglers. Each worker owns its
accepted requests and resources and runs the normal phases. Killing the primary
and relying on IPC teardown is not graceful shutdown.

Docker repository and generated images use exec-form `ENTRYPOINT`/`CMD` so the
runtime/primary is process 1. Tests inspect `/proc/1/cmdline` in the running
image and send SIGTERM to the container, not to a process group assembled by
the test harness.

## Programmatic and hook surface

Every language exposes idiomatic equivalents of:

```text
server.shutdown(reason = "application") -> awaitable/completion
server.shutting_down?                    -> boolean
on_shutdown(callback)                    -> removable registration
```

The signal path calls the same `shutdown` operation. An explicit close cannot
bypass WebSockets, hooks or resources, and completion does not resolve before
drain/cleanup finishes. Synchronous runtimes block on completion; asynchronous
runtimes return an awaitable. A fire-and-forget `close()` that starts database
cleanup later is not the contract.

Application hooks may be synchronous and, in async-capable runtimes,
asynchronous. They run once in reverse registration order because resources
normally unwind opposite to acquisition. Duplicate callbacks are distinct
registrations. The returned handle removes one registration for hot reload,
tests or application ownership. Registration after quiescing fails explicitly.
Hook exceptions are logged and the next hook still runs.

PHP's current `App::onShutdown` is the design seed, but not the final parity
surface: it is PHP-only, fluent rather than removable, runs after server cleanup
and therefore cannot reliably use resources it may need to flush.

Framework subsystems use an internal closeable registration carrying stable
name, owner, dependency order and idempotent close operation. Application
developers use `on_shutdown`; they do not manipulate the internal registry.

## Production server adapters

The observable outcomes are shared; the mechanism follows the socket owner:

- **Python built-in:** Tina4 closes listeners, drains tasks and owns exit.
- **uvicorn:** map the DRAIN deadline (timeout minus the cleanup reserve) to
  `timeout_graceful_shutdown`; run Tina4 resource/hook cleanup afterward within the
  reserve via ASGI lifespan for resources uvicorn does not own.
- **Hypercorn:** map the drain deadline to `graceful_timeout`; prove the same fixture cases.
- **Granian:** either map a real drain deadline and lifecycle hooks or fail
  startup when selected with an unsupported Feature 9 contract. A warning that
  `TINA4_SHUTDOWN_TIMEOUT` is ignored is not parity.
- **Ruby built-in:** Tina4 coordinates WEBrick.
- **Puma:** set `force_shutdown_after` to the drain deadline and use supported
  shutdown hooks; run Tina4 cleanup within the reserve before live peers/resources
  become unreachable.
- **PHP:** the Tina4 primary, pool workers and request children use one
  supervisor protocol.
- **Node:** both single and cluster modes use the same worker-aware coordinator;
  the primary may not take the default SIGTERM path.

`TINA4_DEFAULT_WEBSERVER` may select a deterministic built-in path, but it is not
a remedy for a broken production adapter. Every server Tina4 automatically
selects must meet Feature 9 or fail selection explicitly.

## Long-running Tina4 modes

The web server is not the only container process. Language CLI queue workers
currently handle Ctrl-C inconsistently and do not share one proven SIGTERM
lifecycle: Python catches `KeyboardInterrupt`, PHP and Node install SIGINT-only
handlers, and Ruby relies on default termination around its consume loop.

Queue workers, service runners and future schedulers consume the same
coordinator:

- SIGTERM and SIGINT stop polling for new work;
- the current job/callback receives the remaining deadline;
- completion is acknowledged only after the handler succeeds;
- deadline interruption leaves the job available for redelivery;
- backend connections and logs close before exit;
- process exit and logging follow the same rules as the server;
- `--once` remains a normal finite run and needs no signal.

This feature owns lifecycle integration. Queue acknowledgement details remain
owned by the queue feature and are tested with real brokers.

## Logs and observability

Feature 2 emits the same structured lifecycle events in every language:

| Event | Required fields |
| --- | --- |
| `shutdown_started` | reason/signal, timeout_seconds, pid, role |
| `shutdown_draining` | http_requests, background_tasks, claimed_jobs, workers, websockets |
| `shutdown_timeout` | elapsed_ms and the same remaining counts |
| `shutdown_resource_error` | redacted resource/hook name and error type/message |
| `shutdown_completed` | elapsed_ms, `drained` or `forced`, resources_closed, exit_owner |

The completed or timeout record is flushed to stdout and the selected log file
before exit. A shutdown must not recursively fill logs or wait forever for a
broken sink; Feature 2's sink failure policy remains in force.

## Deployment contract

Generated Kubernetes manifests set:

```yaml
spec:
  terminationGracePeriodSeconds: 35
```

The generated grace period is at least `ceil(TINA4_SHUTDOWN_TIMEOUT) + 5`.
Feature 8 startup/liveness/readiness probes remain separate. Kubernetes already
marks terminating endpoints not ready; Tina4 also enters its internal
quiescing/readiness state for non-Kubernetes supervisors and already accepted
connections.

A generated `preStop` hook is optional, never silently subtracted from the
shutdown budget, and only used when the deployment needs extra load-balancer
propagation time. The documentation states that Kubernetes starts the grace
countdown before running `preStop`.

## Contradictions and defects measured on 2026-08-10

| ID | Severity | Measured contradiction | Required correction |
| --- | --- | --- | --- |
| H9-01 | P1 | On Linux, SIGTERM to the Node production-cluster primary exited 143 and dropped a four-second in-flight request. The single-process suite stayed green because it disables production and signals a process group. | primary-owned graceful protocol: stop respawn, quiesce/drain workers, enforce one deadline, exit 0 |
| H9-02 | P1 | A real WebSocket upgrade through Python's selected production uvicorn path returned HTTP 404 on the lab, so no shutdown 1001 frame was possible. Existing 1001 coverage pins only the built-in server. | make the selected production transport support the route and prove 1001, or reject that unsupported server configuration |
| H9-03 | P1 | Long-running queue CLI paths do not share Feature 9: Python catches Ctrl-C, PHP/Node register SIGINT only, Ruby has no graceful coordinator. Container SIGTERM can interrupt a claimed job and skip backend cleanup. | reuse one coordinator and prove current-job ack/redelivery against real backends |
| H9-04 | P1 | No `shutdown_contract.json` or central runner exists. Four independently named suites can all be green while exercising different modes and rules. | add executable fixture data, four complete reports and a central checker |
| H9-05 | P2 | ADR-0017/Python/PHP require a positive timeout; Ruby and Node explicitly accept zero. PHP accepts only whole integers while the others accept fractions; Python rounds a production value instead of ceiling it. | one Feature 1 numeric rule, startup failure for non-positive/invalid, monotonic deadline and safe ceiling for integer knobs |
| H9-06 | P2 | Only PHP exposes `onShutdown`; it runs after server/database cleanup. Python, Ruby and Node have no portable application hook. | removable LIFO hooks before framework resource teardown, sync/async as supported |
| H9-07 | P2 | Programmatic shutdown is not the signal lifecycle. Node's returned `close()` is non-awaitable, omits WebSocket 1001/hooks, and launches database cleanup without waiting. Other ports expose different or internal controls. | one public idempotent completion-bearing shutdown operation used by signals and explicit callers |
| H9-08 | P2 | Existing timeout logic primarily bounds HTTP drain. User hooks, thread-pool callbacks, worker joins and resource drivers can outlive the advertised budget; Python cancels background runners then uses a non-waiting executor close whose threads may still delay interpreter exit. | one monotonic budget from QUIESCING, split into a bounded drain deadline plus a guaranteed cleanup reserve |
| H9-09 | P2 | Cleanup is hard-coded around some databases/background/WebSockets rather than a lifecycle registry. Activated queue/backplane/cache/session/log resources can be outside the path. | feature-owned closeable registry populated by each activated subsystem; reverse, idempotent cleanup |
| H9-10 | P2 | Production coverage is fragmented: Python proves uvicorn only and Granian explicitly warns it ignores the timeout; Ruby Puma proves DB/HTTP but not a live 1001 frame; PHP pool proves shutdown/port but not an in-flight worker request; Node cluster proves startup only. | run the full fixture against every automatically selectable server and worker mode |
| H9-11 | P2 | Existing harnesses commonly signal detached process groups. That is useful for cleanup but not the container contract, which signals process 1. It hid H9-01. | signal the exact primary/container PID for behavior; kill the group only in unconditional test cleanup |
| H9-12 | P2 | The current tests do not prove active background callbacks or claimed queue jobs finish, callbacks stop being scheduled, resource failures continue cleanup, or logs flush before forced exit. | add real bounded positive/negative cases and mutation witnesses |
| H9-13 | P3 | Shutdown log wording and fields differ across languages, making rolling-deploy diagnosis and timeout counts non-portable. | Feature 2 structured event contract above |

No framework source was changed during this audit.

## Executable parity fixture

Create `fixtures/shutdown_contract.json` version 1 as runtime-neutral inputs and
expected outcomes. It defines:

- signals and programmatic reasons;
- state transitions and phase ordering;
- timeout default, valid fractions and invalid values;
- fast/slow HTTP, keep-alive and late-connection scenarios;
- active/idle WebSocket scenarios and close-frame bytes;
- background callback and queue-job timing/ack expectations;
- hook ordering, removal, async completion and exception continuation;
- framework resource close order and injected real close failure;
- single, production-server, worker/cluster and CLI-consumer modes;
- expected process-owner exit class and structured log events;
- Docker PID 1 and Kubernetes grace expectations.

Each language runner consumes the same file and emits:

```json
{
  "feature": 9,
  "fixture_version": 1,
  "fixture_sha256": "...",
  "framework": "tina4-python",
  "modes": ["builtin", "uvicorn", "queue-worker"],
  "consumed_case_ids": ["..."],
  "failures": [],
  "needs": []
}
```

The central checker executes all four runners, rejects stale hashes, requires
every case for every applicable automatically selected mode and fails when a
required production server/service is missing on the lab. A declared
unsupported optional mode appears under `needs`; it never turns into a green
skip.

## Required real-process test matrix

Every signal case uses a real child or container, real socket and monotonic
wall-clock witness. Blocking fixture work is deadline-looped or async so EINTR
cannot fake completion.

| Area | Required proof in every language/mode |
| --- | --- |
| Signal delivery | exact primary PID gets TERM/INT; HUP retains default; no duplicate handlers |
| Admission | all listeners close first; late TCP refused; no new keep-alive request starts |
| HTTP | accepted slow request completes; timeout cuts it; response bytes are actually received |
| Workers | primary stops respawn, every worker drains, straggler forced, no descendant/orphan remains |
| WebSocket | real upgrade then real close frame 1001 before socket close; does not consume drain budget |
| Background | scheduler stops; active callback finishes inside budget; over-budget callback cannot hold process |
| Queue worker | real broker job completes+acks; timeout case is redelivered; backend closes |
| Hooks | removable, LIFO, once, sync/async, error continues, no late registration |
| Resources | real named/default DB and live backend clients close in reverse order; one close failure does not skip later cleanup |
| Programmatic | completion waits for identical phases and leaves process exit to caller |
| Timeout | invalid startup failure, positive fraction, monotonic deadline, whole lifecycle bound |
| Logs | exact event fields reach real stdout and file before normal/forced exit |
| Images | exec-form PID 1, `docker stop` drains, no orphan processes, port released |
| Fixture | current hash and exact case set reported for each selected mode |

Mutation witnesses must make the suite red when the primary takes default
SIGTERM, worker respawn remains enabled, `close()` resolves early, zero is
accepted, a group signal replaces PID1 delivery, 1001 is removed, a claimed job
is acknowledged before completion, a shutdown hook runs FIFO/after database
close, the deadline resets between phases, or the final log is not flushed.

## Implementation formula for another language

1. Implement Feature 1 typed configuration and validate one positive shutdown
   timeout during startup.
2. Model the six lifecycle states with one atomic, idempotent coordinator.
3. Make the coordinator the sole INT/TERM owner for every Tina4-owned process
   role; integrate rather than compete when a production server owns signals.
4. Expose completion-bearing programmatic shutdown and removable application
   hooks using the language's idioms.
5. Register every listener, worker, scheduler, consumer, WebSocket manager and
   closeable framework resource with stable ownership.
6. Implement the exact quiesce/drain/hook/cleanup sequence against one monotonic
   deadline.
7. Add supervisor IPC so one signal to process 1 drains all workers, disables
   respawn and force-kills only deadline stragglers.
8. Adapt every automatically selected production server using its native drain
   and deadline controls plus supported lifecycle hooks.
9. Integrate queue/service runners so current work finishes or remains safely
   redeliverable.
10. Emit and flush the Feature 2 lifecycle events, preserving fatal/startup
    failure status.
11. Generate exec-form images and Kubernetes grace greater than the Tina4
    timeout.
12. Consume the shared fixture and pass every mode, real-resource case and
    mutation witness locally and on the serialized Linux lab.

A future language is complete only when it adds a runner/mode report without
changing fixture expectations. Syntax, process APIs and production-server
mechanisms may differ; state transitions and observable outcomes may not.

## Migration to 3.14.0

- `TINA4_SHUTDOWN_TIMEOUT=0`, negative, non-finite and malformed values fail
  startup. Use a positive number; omit it for 30 seconds.
- Ruby and Node lose the zero-second immediate-close behavior. Python's
  production integer mapping changes from rounding to ceiling.
- Node production cluster begins exiting 0 after draining rather than dying 143
  and dropping work.
- Programmatic close becomes completion-bearing and runs the full lifecycle;
  callers in async runtimes must await it when they need shutdown complete.
- Application hooks become portable and run LIFO before framework resources;
  PHP code depending on FIFO/closed-database timing must migrate.
- Queue/service containers handle SIGTERM gracefully instead of relying on
  Ctrl-C/default termination.
- Generated Kubernetes grace becomes at least timeout plus five seconds.
- Automatically selected production servers that cannot honor the contract
  fail explicitly rather than warn and continue with partial shutdown.

## Completion gate

Feature 9 is complete only when:

- H9-01 through H9-13 are closed in all four current ports;
- ADR-0047 is published, superseding ADR-0017's state machine, deadline model
  (bounded drain + cleanup reserve), validation, programmatic-hook, worker and
  long-running-mode clauses (ADR-0017 keeps a Superseded-by pointer);
- the fixture, four runners and central checker pass with current hashes;
- every mutation witness is proven red;
- TERM sent to each real container's process 1 drains single and worker modes;
- every selected production server passes the full applicable matrix;
- real WebSocket peers receive 1001 in production;
- real queue jobs complete or redeliver correctly across TERM/deadline cases;
- final logs and resource closure are observed before process exit;
- generated deployment grace safely exceeds the Tina4 deadline;
- local and serialized Linux lab runs are green with zero unexplained skips or
  surviving descendant processes.
