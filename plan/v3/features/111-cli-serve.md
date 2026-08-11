# Feature 111: CLI serve (dev server orchestration)

## Identity and status

- Matrix identity: 111 - `tina4 serve [project]` (start the dev server: file watcher + SCSS + browser +
  child supervision)
- Audit state: decision-ready
- Audit note: SINGLE Rust implementation in the `tina4` binary. Measured 2026-08-11 from
  `tina4/src/main.rs` (`handle_serve` at :535, `Commands::Serve` at :274, child supervision at
  :802-1065), `src/watcher.rs` (622), `src/session.rs` (861), and the CLI `CLAUDE.md` architecture
  section. Not a four-language parity feature.
- Dependencies: `notify` (watcher), `grass` (SCSS), `ctrlc` (signals), the language dev servers it
  supervises, and the framework's `/__dev/api/reload` endpoint.
- Dependants: `tina4 init` (offers serve), `tina4 setup` (starts serve), every dev session.
- Existing ADRs: none dedicated.
- Shared fixtures: NONE; watcher/child-supervision behaviour is documented and partly unit-tested.

- Catalog phase: CLI (single Rust binary, subcommand)

## Why this feature exists

`tina4 serve` is the dev loop. It resolves the project, detects the language, starts that framework's dev
server, watches the source tree and pushes a live reload to the browser on a change, compiles SCSS, opens
the app, and cleans up the whole process tree on exit. It is the CLI's most-used command and the reason a
Tina4 edit-save-see cycle is instant.

Its hardest job is process hygiene: it runs the language server as a child, and it must kill the entire
child tree (npx -> tsx -> node, uv -> python, bundle -> ruby) on any termination signal so a stale server
never orphans and never holds a port.

## Boundary

This packet owns the `serve` subcommand: project resolution, language detection, port selection, child
spawn + supervision, the file watcher and its reload POST, SCSS compilation, and browser launch. It is
the SOLE file watcher for the stack (the frameworks removed their own).

It does NOT own: the framework dev server it supervises (each framework serves and hot-reloads
in-process); the `/__dev/api/reload` endpoint (owned by the framework's dev-admin); the browser reload
transport (WebSocket `/__dev_reload`, framework side). The CLI watches and signals; the framework reloads
and broadcasts.

## Existing implementation evidence

- Dispatch: `main.rs:274` `Commands::Serve { project, port, host, dev, production, no_browser, no_reload }`
  -> `handle_serve` (`main.rs:535`).
- Project resolution: a named project resolves against `./<name>` then the configured projects folder, and
  the CLI `cd`s in before serving (`main.rs:278+`).
- Ports: per-framework defaults php 7145 / python 7146 / ruby 7147 / nodejs 7148 (`setup.rs:804-807`,
  documented `main.rs:92`); auto-increment to a free port if the default is in use (`main.rs:611`).
- Child supervision: the child is spawned as its own process-group leader (`set_process_group` ->
  `setpgid(0,0)`, `main.rs:1042-1065`), so `killpg` reaps the whole tree; the `ctrlc` termination handler
  (SIGINT/SIGTERM/SIGHUP, `main.rs:807-820`) triggers it. SIGKILL (-9) is uncatchable and reparents.
- Watcher (`watcher.rs`): watches `src/`, `migrations/`, `.env`; filters Access/Metadata-only events and
  `__pycache__`/`.git`/`.venv`/`node_modules`/`vendor`/`dist`/`target`/`logs` plus noise extensions
  (`.log`/`.db*`/`.sqlite`/`.tmp`/`.swp`/`.pyc`), with a real mtime check to defeat overlayfs spurious
  events; on a real change POSTs `/__dev/api/reload` (does NOT restart the child).
- SCSS: compiled via `grass` (zero-dep, no sass/node).

## Public surface contract

`tina4 serve [PROJECT] [--port N] [--host 0.0.0.0] [--dev] [--production] [--no-browser] [--no-reload]`.
Bare `tina4 serve` outside a project falls back to the configured projects folder (one project -> serve
it; several -> list; none -> guidance). `--production` auto-installs and uses the production ASGI/server;
`--no-browser` suppresses the browser; `--no-reload` disables the watcher; `--host` defaults to
`0.0.0.0`.

## Inputs and outputs

- Input: an optional project name, port/host overrides, and the dev/production flags.
- Output: a running framework dev server (as a supervised child), a file watcher pushing reloads, compiled
  SCSS, and (unless suppressed) an opened browser. On exit, the whole child tree is killed.
- The default `--host 0.0.0.0` binds the dev server to ALL interfaces.

## Lifecycle and operation graph

1. Resolve the project and `cd` in; detect the language from the entry file (app.py/index.php/app.rb/
   app.ts).
2. Choose the port (per-framework default, auto-incremented if busy).
3. Spawn the language dev server as a process-group-leader child; register the signal handler.
4. Compile SCSS; open the browser (unless suppressed).
5. Watch the source tree; on a real change, POST `/__dev/api/reload` so the framework hot-reloads
   in-process and broadcasts to browsers. The CLI never restarts the child on an edit; the respawn loop is
   dormant and kept only for crash detection.
6. On SIGINT/SIGTERM/SIGHUP, `killpg` the child tree and exit.

## Configuration and precedence

- `--host` (default `0.0.0.0`), `--port` (default per-framework), `--production`, `--no-browser`,
  `--no-reload` - all CLI flags.
- The configured projects folder (from `tina4 setup`) is the fallback root for bare `serve`.
- The framework side reads its own `TINA4_*` (debug, workers, shutdown timeout); the CLI passes through
  the mode.

## Failures, side effects and security

- SERVE-HOST (note, ties to API-01 / MCP-02): `serve` binds to `0.0.0.0` by DEFAULT, exposing the dev
  server (and its `/__dev/*` surface) to every interface on the network. That default is the precondition
  that makes the ungated `/__dev/api/docs/*` disclosure (API-01) and the MCP gate (MCP-02) matter: on a
  laptop on a shared network, a `TINA4_DEBUG=true` server bound to `0.0.0.0` is reachable by peers. The
  bind is convenient (test on a phone), but the CLI could default to `127.0.0.1` and require `--host
  0.0.0.0` to expose, shrinking the dev-surface threat window.
- Child orphaning: SOLVED for catchable signals via `setpgid` + `killpg` (the CLI `CLAUDE.md` records the
  Node `npx -> tsx -> node` leak this fixed). SIGKILL still reparents to init - unavoidable.
- Port contention: handled by auto-increment; confirm the increment is bounded (does not loop forever if
  the whole range is busy).
- The watcher's mtime check and event filter defeat the overlayfs/polling spurious-event storms that would
  otherwise reload continuously.
- No secret handling; the CLI holds no credentials.

## Wire and persistence contract

No persisted state. The only wire interaction is the CLI -> framework `POST /__dev/api/reload` on a change
(the framework then broadcasts `/__dev_reload` over WebSocket to browsers, with a `GET /__dev/api/mtime`
polling fallback). The CLI does not implement the browser reload; it only signals the framework.

## Providers and substitutability

The language dev server is the substitutable part: `serve` detects the entry file and runs the matching
framework's server (python/php/ruby/node), each of which hot-reloads in-process. The CLI's watcher, SCSS,
and supervision are shared across all four. No provider abstraction beyond the language switch.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SERVE-HOST | `serve` defaults `--host` to `0.0.0.0` (all interfaces), which is the precondition for the dev-surface exposure findings (API-01 ungated docs REST, and the reason the MCP gate exists). A dev server on a shared network is reachable by peers by default. | OWNER DECISION: default to `127.0.0.1` and require `--host 0.0.0.0` to expose on the network (a one-line change that shrinks the threat window), or keep `0.0.0.0` and rely on the per-route gates. Given API-01/MCP-02, defaulting to loopback is the safer default; document the flip. |
| SERVE-PORTCAP | Port auto-increment should be bounded so a fully-busy range fails with a message rather than looping. | Verify the loop has a cap; if not, add one (try N..N+50 then error). |
| SERVE-TESTS | Child-supervision and watcher behaviour are documented and partly unit-tested, but the killpg-on-signal path and the reload POST are hard to unit-test and rely on the recorded manual verification. | Keep the unit tests for the pure pieces (event filter, port pick); document the manual verification for the signal/reload paths (they touch real processes and a running server). |

## Owner decisions

- SERVE-DEC-01 (proposed): default `--host` to loopback and require an explicit flag to bind `0.0.0.0`
  (ties to API-01/MCP-02), or keep the current default and rely on gates.
- SERVE-DEC-02 (proposed): confirm/bound the port auto-increment.

## Proposed conformance fixture

Rust unit/integration tests for the deterministic pieces: the watcher event filter (a `.pyc`/`.log`/
`__pycache__` change is dropped; a real `src/*.py` change passes); the port picker (returns the
per-framework default, and the next free port when busy, with a bounded failure); and language detection
from the entry file. The signal/killpg and reload-POST paths stay manually verified (they need real
processes and a running framework), documented as such.

## Integration map

- Dispatch: `main.rs` `Commands::Serve`.
- Calls: language dev server (child), `grass` (SCSS), `notify` (watcher), the framework
  `POST /__dev/api/reload`.
- Called by: `tina4 init` (step 6), `tina4 setup`.
- Documentation: the CLI `CLAUDE.md` "Key Architecture" (watcher, child supervision, ports) is the
  reference; keep it and the framework dev-reload docs in sync.

## Breaking changes and migration

- SERVE-DEC-01 (loopback default) would change the default bind; document it and note `--host 0.0.0.0`
  for the test-on-a-device workflow. It is a security-improving default change.
- Port and watcher behaviour changes are internal.

## Implementation backlog

1. Decide SERVE-HOST (loopback default vs keep 0.0.0.0), coordinated with the API-01/MCP-02 fixes.
2. Confirm/bound the port auto-increment (SERVE-PORTCAP).
3. Keep the pure-piece unit tests; document the signal/reload manual verification.

## Porting capsule

`tina4 serve` is one Rust command. A clean-room reimplementation needs: project resolution (named ->
`./name` then the projects folder), language detection from the entry file, per-framework default ports
with bounded auto-increment, a child spawned as a process-group leader with a `killpg`-on-signal handler
(SIGINT/SIGTERM/SIGHUP) so the whole tree dies, a filtered file watcher (drop metadata/noise, mtime-check)
that POSTs the framework reload endpoint without restarting the child, SCSS compilation, and a browser
launch gated by `--no-browser`. Default the host to loopback unless told to expose (the SERVE-HOST
lesson).

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Single-implementation behaviour recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule (clean-room reimplementation) sufficient.
