# Feature 129: Development port takeover

## Identity and status

- Matrix identity: 129 - Development port takeover (`tina4_python/core/server.py`;
  `tina4_python/cli/__init__.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, a UNIVERSAL safety finding. Measured 2026-08-11 from shipped source by
  four parallel readers (batched with 128 and 130). Python `core/server.py` + `cli/__init__.py`
  (`feature/csrf-fail-closed` HEAD `ebbab30`); PHP `Tina4/Server.php` + `bin/tina4php`
  (`feature/mcp-call-gate` HEAD `6faabac5`); Ruby `lib/tina4/webserver.rb` + `lib/tina4/cli.rb`
  (`feature/mcp-call-gate` HEAD `6d5b1de`); Node `packages/core/src/server.ts` + `packages/cli/src/bin.ts`
  (`feature/mcp-call-gate` HEAD `27cf0f4`).
- Dependencies: `lsof` (and `fuser`/`netstat`/`taskkill` fallbacks), POSIX signals, the container detector,
  and the PID safety filter.
- Dependants: `tina4 serve` (the developer restart loop).
- Existing ADRs: none dedicated. History: the CLI PID filter (`selectable_pids`) + container guard were
  added in 3.13.84 after a container killed itself as PID 1.

- Catalog phase: developer experience (dev server) - SAFETY-RELEVANT

## Why this feature exists

A developer restarts `tina4 serve` constantly, and the old process often still holds the port for a moment.
Rather than fail with "address already in use", the server claims the port: it finds whatever is listening
and kills it, then binds. It removes a papercut from the edit-restart loop. The risk is the flip side of
that convenience - "whatever is listening" is not always the old Tina4 server.

## Boundary

This packet owns the takeover: locating the port holder (`lsof` and friends), the safety filter, the
container guard, and the signal. It does NOT own the bind itself or the second (AI) port (feature 128, which
does NOT take over - it skips).

## Existing implementation evidence

Two takeover paths exist in every backend, with ASYMMETRIC safety. Parity table:

| Axis | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| CLI path (guarded) | `cli:_kill_process_on_port` | `bin/tina4php killProcessOnPort` | `cli.rb kill_process_on_port` | `bin.ts killProcessOnPort` |
| CLI PID filter | `selectable_pids` | `tina4SelectablePids` | `selectable_pids` | `selectablePids` |
| CLI container guard | `_in_container()` | `tina4InContainer()` | `in_container?` | `inContainer()` |
| Runtime path (UNGUARDED) | `server.py _kill_port` | `Server.php freePort` | `webserver.rb free_port` | `server.ts killPort` |
| Runtime path guarded? | NO | NO | NO | NO |
| Tina4-identity check | NONE | NONE | NONE | NONE |
| Opt-out flag/env | NONE | NONE | NONE | NONE |
| Dev-gated | NO | NO | NO | NO |

- CLI path (what `tina4 serve` invokes): runs `lsof -ti :PORT`, filters the PIDs through the language's
  `selectable_pids` (drops non-numeric tokens, `pid <= 1`, self, and own process-group), skips entirely
  inside a container, then SIGTERMs the survivors. This path is guarded and tested.
- Runtime path (the server's own bind-failure fallback): runs `lsof -ti` and SIGTERMs EVERY numeric PID with
  NONE of the guards - no container check, no `pid <= 1` guard, no self/group guard. In Python
  `"0".isdigit()` is true, so `os.kill(0, SIGTERM)` would signal the whole process group; a PID 1 holding
  the port would be SIGTERM'd. This path fires on any main-port bind failure and is the SOLE takeover under
  embedding/override (`TINA4_OVERRIDE_CLIENT=true`, a direct `App::run()`/`startServer()`, or a container
  where the CLI guard no-ops and leaves the port held).
- NEITHER path identifies the victim as a Tina4 server. There is no PID file, no `/__dev` health probe, no
  process-name match. Identification is purely "who holds the TCP port". Every backend's `selectable_pids`
  test even LOCKS IN that an arbitrary foreign PID (e.g. `5150`) is selected for killing.
- A third, non-destructive strategy exists and contradicts the takeover: Ruby's `Tina4.run!`
  (`find_available_port`) and PHP/Python's `App::run` (`findAvailablePort`) increment to the next free port
  instead of killing - but `tina4 serve` bypasses that path and takes the port over. So the same framework
  picks OPPOSITE strategies depending on the entry point.

## Public surface contract

No API surface. Contract as shipped: `tina4 serve` claims the requested port by SIGTERMing whatever holds
it (subject to the CLI guards), and the server's own bind-failure fallback does the same with no guards.
There is no flag to disable it and no restriction to Tina4-owned processes.

## Inputs and outputs

- Input: the target port, the OS process table (`lsof`), the container markers, and the current PID/group.
- Output: SIGTERM to the port holder(s), then a bind. Or, on the `run!`/`App::run` path, a bind on the next
  free port.

## Lifecycle and operation graph

1. `tina4 serve` resolves the port and calls the CLI takeover (skipped in a container; otherwise SIGTERMs
   the filtered PIDs holding the port).
2. The server starts and tries to bind. On success, done. On failure, the runtime fallback SIGTERMs every
   PID holding the port (no filter) and retries once.
3. A direct `App::run()`/`Tina4.run!`/`startServer()` (no CLI) either takes the port over via the runtime
   path or, on the `find-next` variant, binds the next free port.

## Configuration and precedence

- No configuration. `TINA4_OVERRIDE_CLIENT=true` (embedding) changes WHICH path runs (the unguarded runtime
  one), not whether takeover happens. There is no `TINA4_NO_TAKEOVER` / `--no-kill`.

## Failures, side effects and security

- SIGTERM to an unrelated process (the core risk). Because neither path checks Tina4 identity, a foreign
  process on the port - another developer's server, a database, a stray `http.server` - is killed on
  `tina4 serve`. The CLI guards only prevent self/init/group/container suicide, never "is this Tina4".
- The unguarded runtime path can SIGTERM PID 1 (container init) or, in Python, the whole process group via
  `os.kill(0, ...)`. This is the exact 3.13.84 container-suicide class, still live on the runtime path in all
  four (the fix landed only on the CLI path).
- Edge (Python): a foreign root-owned squatter makes the runtime path raise `PermissionError`, which is
  wrapped to `RuntimeError` and CRASHES boot (the CLI path catches per-PID and degrades). So the two paths
  fail differently on the same input.
- No production intent, but the runtime path is NOT dev-gated - it runs under `serve --production` / a
  production bind too.

## Wire and persistence contract

No persisted state. There is no PID file (its absence is part of the identity finding).

## Providers and substitutability

The port-holder lookup is `lsof` with `fuser`/`netstat`/`taskkill` fallbacks; no abstraction. The safety
filter (`selectable_pids`) and container detector are the only pluggable-in-spirit pieces, and they exist
only on the CLI path.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| TAKEOVER-NO-IDENTITY | Takeover kills whatever holds the port with NO Tina4-identity check (no PID file, no `/__dev` probe, no process-name match), in all four. A foreign dev server or database on the port is SIGTERM'd. The `selectable_pids` test in every backend asserts a foreign PID IS selected for killing - the behaviour is locked in, not incidental. | Before killing, confirm the holder is a Tina4 dev server: write a PID file (or a port-stamped marker) on start and only kill a matching PID, or probe the port for a Tina4 `/__dev` health signature and only take over on a match. Otherwise fail with a clear "port held by a non-Tina4 process" message. |
| TAKEOVER-UNGUARDED-RUNTIME | The runtime/core fallback (`_kill_port`/`freePort`/`free_port`/`killPort`) has NONE of the CLI path's guards - no container check, no `pid <= 1` guard, no self/group guard - so it can SIGTERM PID 1 or (Python) the whole process group. It fires on any bind failure and is the SOLE takeover path under embedding/override, and it is UNTESTED, in all four. | Apply the same `selectable_pids` + container guard (and the identity check above) to the runtime path, or route the runtime fallback through the CLI helper. Add a real test that the runtime path spares PID 1/self/group. |
| TAKEOVER-NO-OPTOUT | There is no way to disable takeover - no `TINA4_NO_TAKEOVER` / `--no-kill` in any backend. A developer who does NOT want their port-holder killed has no switch. | Add an opt-out env/flag; consider making takeover opt-IN (fail with a hint by default, take over on `--force`/env). |
| TAKEOVER-NOT-DEV-GATED | The runtime kill path is not gated on `TINA4_DEBUG` - it runs under a production bind too. Takeover is a dev convenience; killing a port holder in production is surprising. | Gate takeover to dev mode (or make it opt-in for production). |
| TAKEOVER-INCONSISTENT-STRATEGY | The same framework picks opposite strategies by entry point: `tina4 serve` KILLS the holder, but `Tina4.run!` / `App::run` (`find_available_port`/`findAvailablePort`) binds the NEXT FREE port instead. A developer gets different behaviour from `serve` vs a direct run. | Pick one policy (identity-checked takeover OR find-next) and apply it consistently across entry points, or document the divergence explicitly. |

## Owner decisions

- TAKEOVER-DEC-01 (proposed): add a Tina4-identity check before killing (PID file or `/__dev` probe) so
  takeover never kills a foreign process (TAKEOVER-NO-IDENTITY). Highest value.
- TAKEOVER-DEC-02 (proposed): bring the runtime path up to the CLI path's guards (or route it through the
  CLI helper) and TEST it (TAKEOVER-UNGUARDED-RUNTIME).
- TAKEOVER-DEC-03 (proposed): add an opt-out (`TINA4_NO_TAKEOVER` / `--no-kill`), gate takeover to dev, and
  reconcile the serve-vs-run strategy (TAKEOVER-NO-OPTOUT + TAKEOVER-NOT-DEV-GATED +
  TAKEOVER-INCONSISTENT-STRATEGY).

## Proposed conformance fixture

Real-process tests (no mocks) in all four:

1. Spare a foreign holder: start a NON-Tina4 listener on the port, run takeover, assert it is NOT killed
   (after TAKEOVER-DEC-01) and a clear message is returned.
2. Reclaim a real Tina4 holder: start a real Tina4 dev server, run takeover, assert the old PID is killed
   and the new server binds.
3. Runtime-path safety: assert the runtime fallback spares PID 1 / self / own group (after
   TAKEOVER-DEC-02).
4. Opt-out: with `TINA4_NO_TAKEOVER`, assert the port holder is NOT killed and the server fails/finds-next
   per the chosen policy.
5. Keep the existing pure `selectable_pids` filter tests (they are good - just not sufficient).

## Integration map

- CLI path: `tina4 serve` -> `killProcessOnPort` -> `selectable_pids` + container guard.
- Runtime path: the server bind-failure fallback -> `_kill_port`/`freePort`/`free_port`/`killPort` (no
  guards).
- Related: feature 128 (the second port SKIPS on collision, the opposite policy) and `App::run`/`run!`
  (`findAvailablePort`, the non-destructive alternative).

## Breaking changes and migration

- Adding the identity check changes behaviour: takeover will refuse to kill a non-Tina4 holder (previously
  it killed it). That is the point - document it as a safety fix. An opt-out flag and a dev gate are
  additive.

## Implementation backlog

1. TAKEOVER-DEC-01: identity-checked takeover (PID file or `/__dev` probe), all four, with the spare-foreign
   and reclaim-Tina4 tests.
2. TAKEOVER-DEC-02: guard + test the runtime path (or route it through the CLI helper), all four.
3. TAKEOVER-DEC-03: opt-out env/flag, dev-gate, and one consistent serve-vs-run strategy.

## Porting capsule

A clean-room reimplementation needs: a port-holder lookup (`lsof` + platform fallbacks); a PID safety filter
that drops non-numeric, `<= 1`, self, and own-group PIDs; a container detector that skips takeover; AND -
the piece all four are missing - a Tina4-IDENTITY check (a PID file the dev server writes, or a `/__dev`
health probe) so only a confirmed Tina4 instance is ever killed. Apply the SAME guards to every takeover
path (the runtime bind-failure fallback must not be a weaker twin of the CLI path). Provide an opt-out, gate
it to dev, and pick ONE policy (identity-checked takeover or find-next) across all entry points. Test it with
real processes: spare a foreign holder, reclaim a real Tina4 holder, and prove PID 1/self/group are safe.

## Audit closure checklist

- [x] Boundary and public surface complete (the two takeover paths x four).
- [x] Lifecycle and every producer/consumer edge complete (CLI path, runtime fallback, find-next
  alternative).
- [x] Configuration, failure, side-effect and security rules complete (no-identity, unguarded runtime path,
  no opt-out, not dev-gated recorded).
- [x] Wire/storage (no PID file - part of the finding) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (Ruby's third path, Python's crash-on-root-squatter).
- [x] Owner ambiguities decided and recorded (TAKEOVER-DEC-01..03 proposed).
- [x] Proposed conformance fixture (spare-foreign, reclaim-Tina4, runtime safety, opt-out) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
