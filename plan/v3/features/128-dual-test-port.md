# Feature 128: Dual development and test ports

## Identity and status

- Matrix identity: 128 - Dual development and test ports (`tina4_python/core/server.py` and siblings)
- Audit state: decision-ready
- Audit note: FOUR-language feature, consistent design. Measured 2026-08-11 from shipped source by four
  parallel readers (batched with features 129 and 130). Python `core/server.py` (`feature/csrf-fail-closed`
  HEAD `ebbab30`); PHP `Tina4/Server.php` (`feature/mcp-call-gate` HEAD `6faabac5`); Ruby
  `lib/tina4/webserver.rb` + `lib/tina4/rack_app.rb` (`feature/mcp-call-gate` HEAD `6d5b1de`); Node
  `packages/core/src/server.ts` (`feature/mcp-call-gate` HEAD `27cf0f4`).
- Dependencies: the built-in dev server (asyncio / stream-socket / WEBrick / node http), `TINA4_DEBUG`, the
  reload watcher, and the dev toolbar.
- Dependants: AI tooling and test clients that want a stable connection to the app while a developer edits
  code on the hot-reloading main port.
- Existing ADRs: none dedicated. Related memory: dual-port reload (base hot-reloads, base+1000 stable).

- Catalog phase: developer experience (dev server)

## Why this feature exists

While a developer edits code, the main dev port hot-reloads: the browser auto-refreshes, and the reload
WebSocket pushes updates. That churn is hostile to a long-lived client - an AI agent, a test runner, an MCP
session - that wants a steady connection to the same app. So in debug mode the server opens a SECOND
listener at `base + 1000` that serves the identical application with the reload signal turned off. One app,
two doors: the noisy one for the browser, the quiet one for tools.

## Boundary

This packet owns the second listener: the `base + 1000` math, the debug gate, the request tagging that
marks a connection as "AI port", and the reload suppression on that port. It does NOT own the app itself,
the reload watcher, the MCP endpoint (which is route-mounted on the MAIN port), or the separate `base + 2000`
agent/supervisor proxy port (a different construct).

## Existing implementation evidence

Parity table:

| Axis | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Second-port math | `port + 1000` (`server.py:3500`) | `port + 1000` (`Server.php:432`) | `@port + 1000` (`webserver.rb:218`) | `port + 1000` (`server.ts:1980`) |
| Default base port | 7146 | 7145 | 7147 | 7148 |
| Gate | `is_debug and not _no_ai_port` | `isDebug && !noAiPort` | `is_debug && !no_ai_port` | `isDebug && !noAiPort && aiPortInRange` |
| Opt-out env | `TINA4_NO_AI_PORT` | `TINA4_NO_AI_PORT` | `TINA4_NO_AI_PORT` | `TINA4_NO_AI_PORT` |
| Second port in use | warn + skip | warn + skip | warn + skip | warn + skip |
| Real dual-port test | NO | NO | NO | YES (`aiPortRange.test.ts`) |

- All four bind the SAME application on both ports. The second port is tagged at accept (a contextvar / a
  connection flag / a `tina4.ai_port` env key / a `_tina4AiPort` marker) and, for tagged requests, the
  reload WebSocket is refused and the dev toolbar renders with reload disabled. The banner labels it "stable
  - no hot-reload".
- The MCP endpoint is route-mounted on the MAIN port (`/__dev/mcp`) in all four - the second port is NOT a
  separate AI/MCP server, just a quiet mirror. The often-seen `base + 2000` is a different thing: an
  external agent/supervisor proxy target (and, in PHP, the MCP `resolvePort`), not this feature's listener.
- Second-port bind failure is non-fatal in all four: the server logs "port in use - skipping" and runs
  single-port. This is deliberately the OPPOSITE of the main port, which takes the port over (feature 129).

## Public surface contract

There is no API surface; the feature is a runtime behaviour. Contract: in debug mode, unless
`TINA4_NO_AI_PORT` is set, the server also listens on `base + 1000` and serves the same app there with the
reload signal suppressed; if that port is busy, it is skipped without failing the main port.

## Inputs and outputs

- Input: `TINA4_DEBUG`, `TINA4_NO_AI_PORT`, the resolved base port. Output: a second listening socket at
  `base + 1000` (or a skip warning), serving the reload-suppressed app.

## Lifecycle and operation graph

1. Resolve the base port (`TINA4_PORT` > legacy `PORT` > language default).
2. If debug and not opted out (and, in Node, the derived port is in range), bind a second listener at
   `base + 1000`.
3. Tag connections/requests on that listener; suppress the reload WebSocket and the reload toolbar for them.
4. On bind failure of the second port, warn and continue single-port. Tear the second listener down on
   shutdown.

## Configuration and precedence

- `TINA4_DEBUG` gates the feature (dev-only). `TINA4_NO_AI_PORT` opts out. The base port resolves from
  `TINA4_PORT` > legacy `PORT` (deprecated, warned) > the language default. There is NO independent
  `TINA4_AGENT_PORT` for this listener - it is always `base + 1000`.

## Failures, side effects and security

- Second port in use: warn + skip, non-fatal (all four). No takeover on the second port.
- No security surface of its own beyond the app it mirrors: the second port serves the SAME routes including
  `/__dev` - so every finding in feature 127 (the dev-admin CSRF/`.env`/mutation surface) is reachable on
  `base + 1000` too. The second port is not an additional exposure beyond the main debug port, but it is not
  a reduced one either.

## Wire and persistence contract

No persisted state. The wire contract is: `base + 1000` serves the app; a reload-WebSocket upgrade on that
port is refused; the injected toolbar carries no reload client.

## Providers and substitutability

No provider abstraction. The only knobs are the debug gate and the opt-out.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| DUALPORT-TEST-GAP | The bound `base + 1000` port has NO automated test in Python, PHP, or Ruby - every server-boot test sets `TINA4_NO_AI_PORT=true` (Python `conftest.py`, 8 Ruby specs) or tests only the toolbar helper (PHP `DualPortReloadTest`, whose docblock admits the socket behaviour is "verified live via tina4 serve"). Node's `aiPortRange.test.ts` is the ONLY real dual-port test - it binds `base + 1000`, asserts it listens, and has a negative control. | Port Node's real dual-port test to Python, PHP, and Ruby: boot with debug, assert `base + 1000` serves the app and refuses the reload WebSocket, and assert `TINA4_NO_AI_PORT` suppresses it. |
| DUALPORT-STABLE-SEMANTICS | "Stable" means only that the reload SIGNAL is suppressed. The second port serves the same in-process app, so a code hot-reload (via `/__dev/api/reload`, reachable on the second port too) IS reflected on the next request there - it is not a frozen code snapshot. A tool expecting an immutable code version on `base + 1000` will not get one. | Document precisely: the AI port is stable in CONNECTION and reload-signal, not a pinned code version. If a pinned version is wanted, that is a separate feature. |
| DUALPORT-BASE-PRECEDENCE | The base that feeds the port math is resolved inconsistently in Ruby: `resolve_bind_port` is `TINA4_PORT` > `PORT`, but the CLI `resolve_config(:port)` reads `PORT` only (ignoring `TINA4_PORT`), while `mcp_port`/supervisor use `TINA4_PORT` \|\| `PORT`. Under `tina4ruby serve` with only `TINA4_PORT` set, the main/AI ports and the supervisor port derive from different bases. Python/PHP are consistent (`TINA4_PORT` > `PORT`). | Make the base-port resolution single-sourced in Ruby (the CLI should honour `TINA4_PORT`), so all derived ports share one base. |
| DUALPORT-DEFAULT-SMELL | PHP `Server::__construct` defaults `port = 7146`, disagreeing with the documented 7145 default (`bin/tina4php`, `App::resolveBindPort`). Masked today because every real caller passes an explicit port. | Align the constructor default to 7145 (or remove the default so the port is always explicit). Cosmetic, but a trap for a future direct `new Server()`. |

## Owner decisions

- DUALPORT-DEC-01 (proposed): port Node's real dual-port test to the other three (DUALPORT-TEST-GAP) - the
  feature is behaviourally unverified in three of four languages.
- DUALPORT-DEC-02 (proposed, low): single-source the base-port resolution in Ruby (DUALPORT-BASE-PRECEDENCE)
  and align the PHP constructor default (DUALPORT-DEFAULT-SMELL); document the "stable" semantics.

## Proposed conformance fixture

A shared per-language test (port Node's): boot with `TINA4_DEBUG=true`; assert `base + 1000` accepts a
connection and serves the app; assert a reload-WebSocket upgrade on `base + 1000` is refused; assert
`TINA4_NO_AI_PORT=true` leaves only the base port; assert a busy `base + 1000` yields a warning and a
still-serving base port.

## Integration map

- Mount: inside the built-in dev server start path, gated on `TINA4_DEBUG`.
- Composes: the reload watcher / toolbar (suppressed on the second port), the app router (shared), and (only
  incidentally) the `/__dev` surface which is reachable on both ports.

## Breaking changes and migration

- None proposed. Adding the missing tests and aligning defaults are internal. If the "stable" semantics are
  documented as connection-stable (not version-pinned), that is a doc clarification, not a behaviour change.

## Implementation backlog

1. DUALPORT-DEC-01: port the real dual-port test to Python, PHP, Ruby.
2. DUALPORT-DEC-02: single-source Ruby's base port; align PHP's constructor default; document "stable".

## Porting capsule

A clean-room reimplementation needs: a `base + 1000` second listener opened only in debug and only when not
opted out; the SAME app served on it with the reload WebSocket refused and the reload toolbar suppressed
(tag the connection/request and branch on the tag); a non-fatal skip when the second port is busy; one
single-sourced base-port resolution feeding every derived port; and a real test that binds the second port
and asserts it serves the app with reload off. Do not confuse this with the `base + 2000` agent/supervisor
proxy port, and remember the MCP endpoint lives on the MAIN port.

## Audit closure checklist

- [x] Boundary and public surface complete (the second-listener behaviour x four).
- [x] Lifecycle and every producer/consumer edge complete (bind, tag, suppress, skip, teardown).
- [x] Configuration, failure, side-effect and security rules complete (gate, opt-out, skip-on-collision,
  shared `/__dev` note).
- [x] Wire/storage (the second-port contract) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (test coverage, base-precedence, default smell).
- [x] Owner ambiguities decided and recorded (DUALPORT-DEC-01/02 proposed).
- [x] Proposed conformance fixture complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
