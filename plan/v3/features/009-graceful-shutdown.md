# Feature 9: Graceful shutdown (signal handling)

Audited 2026-07-31. Part of `98-feature-audit.md`.

A container orchestrator sends SIGTERM and kills the process after a grace
period. Dropping in-flight requests on SIGTERM is a production defect, not a
style question. This audit measured what each framework really does, and found
two defects in Node that reach production on every rolling deploy.

## Files

| | signal handling | shutdown work |
| --- | --- | --- |
| python | `tina4-python/tina4_python/core/server.py` (`_signal_handler`) | same file, after `await shutdown.wait()` |
| php | `tina4-php/Tina4/Server.php` (`start`, `stop`, `cleanup`) | same file |
| ruby | `tina4-ruby/lib/tina4/shutdown.rb` | same file (`initiate_shutdown`) |
| node | `tina4-nodejs/packages/core/src/server.ts` (`gracefulShutdown`) | same file |

## How this was measured

No mocks, and no in-process seam. Calling a handler function directly proves
that the function runs. It proves nothing about whether the signal reaches it,
whether the listener stops accepting, or what the process exits with.

Every number below comes from the same probe: spawn a real server as a child
process, issue a real HTTP request to a route that occupies the handler for 2.0
seconds, send a real POSIX signal to that process 0.6 seconds into the request,
then record the response, the listener state, and the exit code from `waitpid`.

One trap surfaced during measurement and is worth recording, because it
produced a false green. A signal makes a blocking `sleep` or `usleep` return
early with EINTR. The PHP handler looked like it drained when the signal had
only interrupted its sleep: the response came back in 0.604 seconds instead of
2.0, carrying the correct body. Every slow route in these tests is now
wall-clock bounded (`while (microtime(true) < $end)`) so an interrupted sleep
cannot masquerade as a completed handler.

Platform: macOS 26.5.2, Darwin 25.5.0, arm64. PHP 8.5.7, Ruby 4.0.2,
Node 24.9.0.

Python needs a note. The first-pass measurements in the table below ran on an
ad-hoc 3.14.5 virtualenv; the per-framework work and its suite ran on the
project's own uv-pinned 3.13.5. Both are above the 3.12 floor where
`asyncio.Server.wait_closed()` began waiting for open connections, which is the
mechanism the drain depends on, so the measured outcome is the same on both.
The 3.13.5 figure is the representative one because it is the interpreter the
project actually pins.

Signal delivery and socket teardown differ on Linux, which is where this
deploys. See "Linux re-measurement" below.

## Measurements (before any fix) - BUILT-IN servers only

Read the scope of this table before trusting it. **The Python and Ruby rows
measured the BUILT-IN server, not the production one.** Python's uvicorn was not
installed in the probe venv, so `run()` never took its production branch, and
Ruby's row is WEBrick. Both frameworks hand the socket to a third-party server
in production, and none of the behaviour below survives that handoff. See "The
production server owns the socket" for the gap and how it is closed.

| framework | server measured | in-flight request | connection after signal | exit | drain |
| --- | --- | --- | --- | --- | --- |
| python | built-in asyncio | COMPLETED (200) | refused | 0 | 1.42s |
| php | own server (the only one) | COMPLETED (200) | accepted, then RESET | 0 | 1.46s |
| ruby | WEBrick | COMPLETED (200) | accepted, 503 JSON | 0 | 1.43s |
| node, plain `startServer()` | own `node:http` (the only one) | DROPPED | refused | 143 | 0.15s |
| node, one `background()` task | own `node:http` | n/a | still serving 200 | never exits | HUNG |

SIGINT matched SIGTERM in all five rows. SIGHUP is trapped nowhere: `waitpid`
reported killed-by-signal in all four.

The Python and Ruby rows are honest about what they cover and useless as
production evidence. That distinction is the finding, not a caveat on it: a
measurement that silently exercises the dev path reports the framework as
healthy on exactly the path nobody deploys.

## The two Node defects

### 1. A plain app trapped nothing

`startServer()` registered no signal handler at all. SIGTERM therefore hit
Node's default disposition. The process died in 150 milliseconds, the in-flight
response came back as "connection closed without response", and the exit code
was 143.

The CLI had a handler, and it was worse than none:

```ts
const shutdown = () => { server.close(); process.exit(0); };
```

Node's own documentation says `server.close()` is asynchronous and "keeps
existing connections". The close callback is the only honest signal that
everything drained. Exiting on the next line kills the very requests the close
was waiting for. That code was not dead. It was a lie about what it did.

### 2. Registering a background task made it hang forever

This is the finding that only a real signal to a real process could surface.

`background.ts` bound `process.on("SIGTERM", cleanup)` where `cleanup` cleared
timers and never exited. The comment described it as "additive: it does not
call process.exit() or interfere with other shutdown logic". That description
was the bug.

Registering any listener for SIGTERM REPLACES Node's default disposition. A
handler that does not exit does not add to the default. It cancels it. Measured:
a server with one registered background task ignored SIGTERM completely, kept
answering 200s, and was still running when the probe gave up after 40 seconds.

Under Kubernetes that means every pod burns the full
`terminationGracePeriodSeconds` and dies by SIGKILL on every rolling deploy.
Docker and Kubernetes are the default deployment target, so this was hitting
production.

The handler also bought nothing. `_arm()` calls `timer.unref()` on every
background timer, so a background task never holds the event loop open and never
needed clearing to let the process exit.

## The worst defect found: PHP made an embedded App unkillable

This is not a graceful-shutdown gap. It is a process that ignores `kill` and
`docker stop`.

`Tina4\App` registered SIGTERM and SIGINT handlers from its **constructor**
(`App.php:293`, inside `__construct` declared at line 194 - not from `start()`,
which is line 469), binding both to `$this->shutdown()`.

PHP dispatches a `pcntl_signal` handler only when `pcntl_signal_dispatch()` runs
or `pcntl_async_signals(true)` is set. Neither happens unless a server loop is
running. Constructing an App without running the server therefore produced the
worst of both worlds:

- Registering the handler **suppressed SIGTERM's default terminate action**.
- Nothing ever dispatched it, so **the handler body never ran either**.

Measured: a probe process that constructed an App and then looped **survived
SIGTERM**, ran its full six seconds, and exited 0 on its own. For any embedder,
`kill` and `docker stop` were no-ops, with no operator workaround.

The milder second half of the same mistake: `bin/tina4php` constructs the App
(line 1028) then calls `$server->start()` (line 1073), which binds the same two
signals to `$this->stop()`. `pcntl_signal` replaces rather than chains, so on the
serve path Server's registration won and App's handlers were dead code.

Fixed by deleting `registerSignalHandlers()` outright. Server owns the signals;
`App::shutdown()` and its `onShutdown()` callbacks now run from
`register_shutdown_function`, firing on every exit route without a second handler
that can fight or mask the first. A named regression test pins that an embedded
App with no event loop is still killable by SIGTERM.

This is the same shape as the Node defect: two implementations of one lifecycle,
neither aware of the other. Node's pair fought and produced a hang. PHP's pair
does not fight only because the later registration silently wins.

## The production server owns the socket, and everything above ran after it

Python and Ruby hand the listening socket to a third-party production server.
Every shutdown behaviour described above lives AFTER that handoff and never
executes where operators deploy.

| Framework | production server | contract |
| --- | --- | --- |
| Python | uvicorn / hypercorn / granian when `not is_debug` (`core/server.py:3219-3226`) | LOST |
| Ruby | Puma when `!is_debug` (`lib/tina4.rb:437-462`) | LOST |
| PHP | own server throughout | applies |
| Node | own `node:http` + cluster | applies |

Both call the starter and `return`. Ruby is the sharper case: `tina4ruby.gemspec:22`
declares `spec.add_dependency "puma", "~> 6.0"`, so Puma is ALWAYS installed and
the `rescue LoadError` fallback to WEBrick cannot be reached in production.
Ruby's Puma path does call `Tina4::Shutdown.setup`, but with a nil `@server`, so
its listener shutdown is a no-op and it only traps signals Puma already traps.

Both handoffs ARE gated on debug, so `TINA4_DEBUG=true` reaches the built-in
server. An earlier draft of this document's ADR claimed Ruby's was ungated and
that WEBrick was unreachable; both were wrong, and the correction is recorded in
ADR-0017 rather than quietly removed. The gap is real; that description of it
was not.

The resolution follows ADR-0011's shape: **the outcomes are the contract, the
mechanism is per-server.** Draining and the deadline belong to uvicorn and Puma
and are CONFIGURED, never reimplemented - `TINA4_SHUTDOWN_TIMEOUT` maps onto
uvicorn's `timeout_graceful_shutdown` and Puma's `force_shutdown_after`, because
an env var that means one thing on the built-in server and nothing on the
production one is a lie on the path that matters. The database close and the
WebSocket 1001 belong to Tina4, because no third-party server can know those
exist.

## Decisions

Recorded as **ADR-0017** in `plan/v3/DECISIONS.md`. Settled under ADR-0012:
standard and convention first, then what the mainstream frameworks and
platforms actually do, then add-on libraries, and only then internal precedent.

### Authorities checked

| authority | what it does |
| --- | --- |
| Kubernetes | Sends SIGTERM, waits `terminationGracePeriodSeconds` (default 30), then SIGKILL. The grace period covers the preStop hook AND the shutdown together. |
| Node `server.close()` | Documented as asynchronous. Stops accepting new connections, keeps existing ones, fires the callback once all connections end. |
| Gunicorn | `graceful_timeout` default 30 seconds. TERM starts a graceful shutdown and waits for workers to finish current requests. |
| Puma | TERM: "the worker will attempt to finish then exit". `force_shutdown_after` defaults to `:forever`. SIGHUP reopens log files, or behaves like INT when no `stdout_redirect` is set. |
| Exit codes | `128 + signum` is a shell abstraction for reporting a process killed BY a signal. It is not POSIX, and it is not what a process that traps and exits cleanly reports. |

### D1: `TINA4_SHUTDOWN_TIMEOUT`, default 30 seconds, all four

The authorities split: Gunicorn bounds at 30, Puma waits forever. Internally
Ruby already had `TINA4_SHUTDOWN_TIMEOUT` at 30 while Python and PHP waited
without bound.

The other three adopt Ruby's spelling. 30 matches both Gunicorn and the
Kubernetes default grace period, so the drain finishes just before the SIGKILL
rather than being truncated by it. An unbounded wait does not avoid truncation.
It only means SIGKILL does the truncating, with no clean exit and no log line
naming what was still in flight.

An invalid or negative value warns and falls back to 30. A typo must not turn
shutdown into a zero-second force-kill.

### D2: exit 0 on a clean drained shutdown, all four

Python, PHP and Ruby already exited 0. Node exited 143 only because nothing
handled the signal.

A process that was asked to stop and did so cleanly should report success.
Gunicorn and Puma both halt 0 on a handled TERM. The Kubernetes consequence
decides it: 143 is recorded as signal-killed and counts as a failure for a Job
or `restartPolicy: OnFailure`, while 0 is a clean termination.

### D3: RFC 6455 close code 1001 on every live WebSocket

No framework sent a close frame. PHP closed its WebSocket clients with no frame
at all; the other three let the sockets vanish with the process.

RFC 6455 section 7.4.1 defines 1001 "going away" for exactly this case, a server
going down. This is conformance, not invention. A client told 1001 reconnects on
a schedule. A socket that simply vanishes looks like a network fault and
produces an error.

A WebSocket never "finishes" the way a request does, so waiting for one to drain
would burn the whole budget every time. The close frame goes out first, then the
listeners close.

### D4: close the listener so a late connection gets a clean refusal

Three frameworks did three different things to a connection arriving after the
signal. They cannot all be right.

PHP's accept-then-RESET is the worst of the three. The client sees a transport
error indistinguishable from a network fault. Ruby's 503 is more informative but
still keeps the listener open. Python refuses, which is simplest and which a load
balancer already handles correctly.

All four converge on Python's behaviour: stop accepting first, then drain what
was already accepted.

### D5: SIGHUP stays untrapped

No framework traps it, so the default disposition terminates the process. Puma
uses SIGHUP to reopen log files and Gunicorn to reload config. Neither is a
Tina4 need: the Rust CLI owns file watching, and production logs go to stdout
(see `TINA4_LOG_OUTPUT`).

Adding it would be a new feature, not a parity fix. The tests pin the current
behaviour so nobody restores it by accident.

## Tests

Identical case names across all four, so the suites compare line for line:

```
SIGTERM lets the in-flight request finish
SIGTERM stops accepting new connections
SIGTERM exits with code 0
SIGTERM releases the listening port
SIGINT lets the in-flight request finish
SIGINT exits with code 0
SIGHUP is not trapped and terminates the process
a registered background task does not block shutdown
TINA4_SHUTDOWN_TIMEOUT bounds the drain
```

| framework | file |
| --- | --- |
| python | `tina4-python/tests/test_graceful_shutdown.py` |
| php | `tina4-php/tests/GracefulShutdownTest.php` |
| ruby | `tina4-ruby/spec/graceful_shutdown_spec.rb` |
| node | `tina4-nodejs/test/gracefulShutdown.test.ts` |

Two cases need explanation. "SIGHUP is not trapped" asserts the process is gone
AND that a signal killed it rather than a clean exit 0, which pins the
deliberate non-handling. "TINA4_SHUTDOWN_TIMEOUT bounds the drain" boots with
the timeout set to 1 against a 6-second handler and asserts the process exits in
well under 4 seconds. The in-flight request is cut short there, which is the
whole point of a bound.

Each test spawns a detached child in its own process group, redirects the child's
stdout and stderr to a file, and kills the process group in a finally block. An
inherited file descriptor keeps the runner's pipe open and wedges a piped test
run forever, even after the runner itself has finished.

## Negative proofs

Every gate was proven able to fail. Node, run at the committed HEAD:

| probe | result |
| --- | --- |
| Remove the `process.on("SIGTERM")` registration from `startServer` | 8 failures. "SIGTERM lets the in-flight request finish" reported `socket hang up`; "SIGTERM exits with code 0" reported `code=143`. Exactly the original defect. |
| Reinstate the `background.ts` listener, keeping the new one | 12 passed. The old handler is redundant now, not harmful, because `startServer` also handles the signal and exits. Recorded because it shows the probe alone does not prove the gate. |
| Both together (the exact original code) | "a registered background task does not block shutdown" failed with `timedOut=true`. The hang reproduces. |
| Ignore `TINA4_SHUTDOWN_TIMEOUT` in the race | "TINA4_SHUTDOWN_TIMEOUT bounds the drain" failed: exited after 9654ms against a 1-second budget. |

## Two process-hygiene traps this audit hit

Both cost real time, and the next person testing signal handling will meet them.

**A dead child handle is not proof the server died.** `tsx` runs the real server
as a CHILD of the process the test handle points at. A signal that kills the
wrapper but not the server sets `exitCode` on the handle while the server keeps
listening. Cleanup code guarded with "only kill if the handle still looks alive"
therefore skips the one case that actually leaks. This audit's own measurement
run left three orphaned servers holding ports 49402, 49564 and 49607, all from
the SIGHUP cases, where SIGHUP killed the wrapper and the server survived.

Call `killpg` unconditionally and let the ESRCH throw be caught, rather than
gating it on the handle. Then verify with `lsof -ti:<port>` on every port used.
The process handle lies; the port does not.

**`pkill -f` is machine-wide, and every framework repo has identically named
processes.** Four parallel audits each run `tsx test/run-all.ts` from their own
worktree. `pkill -f "run-all"` matches all four. During this audit a broad pkill
killed other agents' suites, and a suite here died from the same hazard in
reverse.

Kill by explicit PID, or include the worktree path in the pattern
(`.worktrees/audit-009/`). A process name alone does not identify whose process
it is.

## A wrapper's exit status is not the suite's

This one is not specific to shutdown, and it nearly defeated the verification
for this feature. It generalises to any suite run under any harness, so it is
recorded here rather than in a commit message that nobody will read again.

A long test run started through a background task, a job runner, a CI step or a
shell wrapper reports TWO exit statuses, and they are not the same number. The
wrapper reports whether the wrapper finished. The suite reports whether the
tests passed. A harness that surfaces the first one is telling the truth about
the wrong process.

Measured here: a full Node run was killed by SIGTERM at file 49 of 217. Its own
log ended with `NODE_FINAL_EXIT=143`. The task notification said the command
completed with exit code 0. Both statements were accurate. Only one of them was
about the tests.

The failure mode is worse than a missing result, because a killed run and a
passing run look identical from outside: no failures printed, no error, a clean
"completed". Nothing distinguishes them except the child's own final line, and
a run that dies partway simply stops printing rather than announcing that it
stopped.

The practice that catches it, and the reason every suite in this audit is run
this way:

```sh
npm test > run.log 2>&1; echo "EXIT=$?" >> run.log
```

Then read `EXIT` out of the log, and check the file count against the expected
total. `128 + signum` in that field means a signal killed the run: 143 is
SIGTERM, 137 is SIGKILL, 130 is SIGINT. None of them is a pass. "No FAIL lines"
is not a pass either, because a run that was killed before reaching a failing
test also has no FAIL lines.

Never report a suite green on a status you did not read from the suite itself.

## Deployment guidance

Two operational notes that belong beside the probe YAML, neither of which the
framework can fix.

**Set `terminationGracePeriodSeconds` above `TINA4_SHUTDOWN_TIMEOUT`.** At the
Kubernetes default both are 30, so a drain that used its full budget would race
SIGKILL. Measured drain is about 1.5 seconds, so this is theoretical today, but
the ordering should be explicit:

```yaml
spec:
  terminationGracePeriodSeconds: 45   # above TINA4_SHUTDOWN_TIMEOUT
  containers:
    - name: app
      env:
        - name: TINA4_SHUTDOWN_TIMEOUT
          value: "30"
```

**Endpoint removal is not instant.** During termination there is a window where
kube-proxy may still route to a pod whose endpoint removal has not propagated.
The fix is a `preStop` hook sleep, which is the operator's concern:

```yaml
      lifecycle:
        preStop:
          exec:
            command: ["sh", "-c", "sleep 5"]
```

Remember that the grace period covers the preStop hook and the shutdown
together.

## Linux re-measurement

These results are macOS-measured. Re-measure on Linux before trusting any of the
following in production:

- **Exit codes and `waitpid` reporting** under a container init (PID 1 does not
  get default signal dispositions, so an unhandled SIGTERM behaves differently
  in a container than it does here).
- **PHP's accept-then-RESET.** The listen backlog behaviour that produced it is
  kernel-specific.
- **The SIGHUP timings.** Ruby's process exited at the moment the in-flight
  request finished rather than at the signal, which suggests the VM defers the
  terminating signal to a checkpoint. The outcome (killed by signal) is stable;
  the timing is not.

The assertions in all four suites are written against outcomes (drained,
refused, exit code) rather than Darwin timings, so they should hold on Linux.
That is a prediction until someone runs them there.

## Cleanup

Three half-implementations of one lifecycle became one. `background.ts` and the
CLI's `serve.ts` no longer register signal handlers; `startServer()` owns the
whole path and calls `stopAllBackgroundTasks()` as its first step. A process
using `background()` without a server now keeps Node's correct default and
terminates on SIGTERM.

Two implementations of one lifecycle is the shape that produced this bug. The
handler that clears timers and the handler that exits were never going to agree,
because neither knew the other existed.
