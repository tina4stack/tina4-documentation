# Feature 127: Development admin dashboard

## Identity and status

- Matrix identity: 127 - Development admin dashboard (`tina4_python/dev_admin/__init__.py` and siblings)
- Audit state: decision-ready
- Audit note: FOUR-language feature, a large shared surface. Measured 2026-08-11 from shipped source by four
  parallel security-forward readers, then the two highest-severity Python claims (MCP-02 branch state and
  `_api_mcp_call` gate absence, plus the v3 `.env`-read denylist) were re-verified by hand with `git`.
  Python `tina4_python/dev_admin/__init__.py` (3613 lines, branch `feature/csrf-fail-closed` HEAD `ebbab30`;
  the shipping `v3` HEAD `386cd6d` carries the SAME surface); PHP `Tina4/DevAdmin.php` (3991 lines,
  `feature/mcp-call-gate` HEAD `6faabac5`); Ruby `lib/tina4/dev_admin.rb` (2246 lines,
  `feature/mcp-call-gate` HEAD `6d5b1de`); Node `packages/core/src/devAdmin.ts` (3055 lines,
  `feature/mcp-call-gate` HEAD `27cf0f4`). Each backend also ships a large minified SPA
  (`tina4-dev-admin.min.js`) that renders the JSON the dashboard returns.
- Dependencies: `TINA4_DEBUG` (the gate), the server dispatch pipeline (the mount point), the metrics
  engine, the MCP server + `is_request_allowed` peer gate, the reload watcher, the project index, the plan
  engine, and the supervisor/agent proxy.
- Dependants: developers working with `tina4 serve` in debug mode; the reload watcher and the dev toolbar.
- Existing ADRs: none dedicated. Related: ADR-0018 (deny-by-default CORS).

- Catalog phase: developer experience (dev tooling) - SECURITY-CRITICAL

## Why this feature exists

The dev admin dashboard is the control room for `tina4 serve`. It lists routes, tails request logs and
captured errors, inspects the database and the queue, runs the metrics engine, hosts the MCP endpoint for
AI tooling, drives hot reload, and offers an editor that reads and writes project files. It exists to make
local development fast: one page, live, with everything a developer needs to see and poke while building.
Because it can read files, run SQL, install packages, and write routes, its entire security model rests on
one assumption - that it only exists when the developer turns it on.

## Boundary

This packet owns the dashboard: the route table, every `/__dev/*` handler (read-only and mutating), the
mount stage that gates the whole surface on `TINA4_DEBUG`, the injected dev toolbar, the request/error
capture, and the file editor. It composes but does NOT own the MCP server internals (feature 108 family),
the metrics engine (feature 121), the reload watcher, the project index, or the framework's CSRF/CORS
middleware. The client-side SPA bundle is rendered here but its internals are audited only where a reader
could reach them.

## Existing implementation evidence

Security-axis parity table (the questions that decide the feature's safety):

| Axis | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Module | `dev_admin/__init__.py` | `Tina4/DevAdmin.php` | `lib/tina4/dev_admin.rb` | `packages/core/src/devAdmin.ts` |
| Mount | `_stage_dev_admin` pre-match (`server.py:2149`) | `DevAdmin::register()` at `App.php:599` | `dev_routes` stage (`dispatch_pipeline.rb:181`) | `DevAdmin.register` at `server.ts:1774` |
| Gate | `TINA4_DEBUG` (`is_truthy`) | `TINA4_DEBUG` / `isDevelopment()` | `TINA4_DEBUG` (`enabled?`) | `TINA4_DEBUG` (`isEnabled()`) |
| Reachable in prod (gate off)? | NO (404) | NO (404) | NO (404) | NO (404) |
| CSRF on mutations | NONE | NONE | NONE | NONE |
| `.env` readable via file endpoint | YES | YES | YES | YES |
| Injected-toolbar path escaped | NO (raw) | YES (`htmlspecialchars`) | n/a (static shell) | NO (raw) |
| DB URL redacted in status/system | YES | YES | YES | NO (raw) |
| MCP `mcp/call` gated | NO (this branch + v3) | YES | YES | YES |
| Default bind | `0.0.0.0` | `0.0.0.0` | `0.0.0.0` | `0.0.0.0` |

- The gate is the one strong control, and it is genuinely strong in all four: the entire route surface
  exists only when `TINA4_DEBUG` is truthy. Python mounts a single pre-match dispatch stage that returns
  `None` (falls through to a normal 404) when the gate is off; the parity `register()` that would push
  routes into the router is dead code (never called). PHP calls `DevAdmin::register()` only inside
  `if ($this->isDevelopment())`. Ruby self-gates in `handle_request` (`return nil unless enabled?`). Node
  mounts only inside `if (DevAdmin.isEnabled())`. Verified: with the gate off, no `/__dev` route is
  reachable in any language.
- Inside the gate, the surface is large and powerful: arbitrary SQL, arbitrary in-project file write (which
  becomes code execution once the written file is a route and the reload endpoint re-imports it), file
  delete, dependency install (subprocess), migrations/seeds, a test runner, and an agent proxy. None of
  these carry a second per-request check - except the MCP subset.
- The MCP endpoint (`/__dev/mcp` + `/__dev/api/mcp/*`) is the ONLY part with a real per-request gate:
  `is_request_allowed(peer, token_ok)` - loopback allowed, remote only with `TINA4_MCP_REMOTE` + a valid
  timing-safe token, using the raw socket peer (never X-Forwarded-For). This is correct and well-tested.
  The "built-but-dark" note from an earlier memory is STALE: the endpoint is fully wired in all four.

## Public surface contract

`GET/POST /__dev/*` - a JSON API plus an SPA shell at `/__dev`. Read-only endpoints report state (routes,
requests, errors, queue, tables, metrics, files, git, MCP tools). Mutating endpoints change state (reload,
clear, seed, migrate, test, file save/rename/delete, deps install, connections save, SQL query, MCP call,
scaffold). The entire surface is contractually dev-only: it does not exist unless `TINA4_DEBUG` is truthy.

## Inputs and outputs

- Input: HTTP requests to `/__dev/*` (bodies parsed as JSON and, in several backends, as form-encoded /
  multipart), plus `TINA4_DEBUG` and the MCP env. Output: JSON payloads, the SPA shell, hot-reload
  broadcasts, and - for the mutating routes - real side effects on the filesystem, the database, installed
  packages, and running subprocesses.

## Lifecycle and operation graph

1. A request arrives. The dispatch pipeline reaches the dev-admin stage.
2. Gate: if `TINA4_DEBUG` is off, the stage yields and the request falls through to normal routing (404 for
   `/__dev`). If on, the dashboard handles it.
3. The handler runs. Read-only handlers return JSON. Mutating handlers act (write a file, run SQL, install a
   package, spawn a subprocess) and return JSON. The MCP handlers additionally check the peer/token gate.
4. Separately, in debug mode, a toolbar-inject stage appends an HTML toolbar to every `text/html` response,
   and a capture stage records the request for the inspector.

## Configuration and precedence

- `TINA4_DEBUG` is the sole gate for the whole surface (truthy set `true/1/yes/on`). The MCP subset adds
  `TINA4_MCP` (capability), `TINA4_MCP_REMOTE` (allow non-loopback), and `TINA4_MCP_TOKEN` (fallback
  `TINA4_API_KEY`, the remote bearer). There is NO admin token, NO dev-admin bind-address, and NO dev-admin
  port variable in any backend - the dashboard rides the main server's bind, which defaults to `0.0.0.0`.

## Failures, side effects and security

The gate holds (dev-only by absence, all four), so this is NOT a production-reachable surface. Within the
development scope, however, the surface is high-risk, and the risk is real, not theoretical - it matches the
well-known "local dev server" threat class. Two attack paths:

- DRIVE-BY CSRF (the primary threat). A developer runs `tina4 serve` with `TINA4_DEBUG=true` and, in the
  same browser, visits any web page. That page can `POST` cross-origin to `http://localhost:<port>/__dev/*`.
  Because the mutation routes have NO CSRF, Origin, Sec-Fetch, or same-origin check (all four), and the body
  parsers accept no-preflight content-types (form-encoded / `text/plain`), the request is acted on. Writing
  `src/routes/x.<ext>` then calling the reload endpoint executes attacker code on the developer's machine;
  `/query` runs arbitrary SQL; `/deps/install` runs a package's install hooks. Deny-by-default CORS does not
  help - CORS blocks cross-origin READS, not SENDS.
- REACHABLE-INTERFACE EXPOSURE. The default bind is `0.0.0.0`. A `TINA4_DEBUG=true` box on a shared network,
  a container, or WSL exposes the entire unauthenticated mutation + RCE + secret surface to any network
  peer. The loopback/token gate that protects the MCP subset was NOT applied to the REST routes.

Specific security findings are enumerated in the register below (DEVADMIN-CSRF, DEVADMIN-ENV-READ,
DEVADMIN-BIND, DEVADMIN-MCP-CALL, DEVADMIN-XSS-TOOLBAR, DEVADMIN-TEST-GAPS).

What is genuinely well-handled (credit, all four unless noted): the `TINA4_DEBUG` gate is one clean choke
point; there is NO full-environment dump anywhere; the DB URL is redacted in `status`/`system` (Python, PHP,
Ruby; Node returns it raw); the request inspector stores no `Authorization`/`Cookie` headers; the MCP subset
is correctly gated (loopback-or-token, XFF-proof raw peer, timing-safe compare) with real end-to-end tests
including a blocked-write assertion; there is NO OS-command injection (subprocess calls use argument arrays /
`escapeshellarg` / `Shellwords.escape`, never a shell string); and CORS is deny-by-default.

## Wire and persistence contract

The dashboard has no persisted state of its own beyond in-memory logs and the file-backed error tracker. Its
wire contract is the `/__dev/*` JSON API consumed by the SPA. The mutating routes' "persistence" is their
side effects: files written under the project root, rows written to the app DB, packages installed, and
`.env` edits (connections save, grounding token).

## Providers and substitutability

No provider abstraction; the dashboard is a fixed set of handlers. The only pluggable pieces it composes are
the metrics engine (native), the MCP server (tool registry), and the supervisor/agent proxy (an external
process). The substitution axis is the language backend; the surface is intentionally near-identical across
the four.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| DEVADMIN-CSRF | No CSRF / Origin / Sec-Fetch / same-origin check on any mutation route, in ALL FOUR. The body parsers accept no-preflight content-types (form-encoded / `text/plain`), so a cross-origin `POST` from any page a developer visits reaches `/query`, `/file/save`, `/deps/install` etc. and is acted on -> drive-by RCE on the dev machine. Python's `feature/csrf-fail-closed` work does NOT cover this: `CsrfMiddleware` is a post-match route middleware, but the dev-admin stage is pre-match and short-circuits before it runs. | Add a fail-closed same-origin gate to the dev-admin mutation surface in all four: reject a request whose `Sec-Fetch-Site` is `cross-site` (or whose `Origin` is not same-origin), or require a per-session dev token that the SPA sends and a cross-origin page cannot read. Stop acting on no-preflight cross-origin bodies. This is the single highest-value fix. |
| DEVADMIN-ENV-READ | The file-read / file-raw / file-list endpoints return `.env` verbatim in all four - no dotfile denylist, and Ruby/Node explicitly UN-hide `.env` in the listing. `GET /__dev/api/file?path=.env` returns `TINA4_SECRET`, the DB password, and `TINA4_MCP_TOKEN`/`TINA4_API_KEY` in cleartext, nullifying the DB-URL redaction elsewhere - and the leaked MCP token then unlocks REMOTE MCP. | Add a dotfile/secret denylist to the file endpoints (never serve `.env`, `.env.*`, `.git/`, key material), in all four. Redact or refuse rather than return raw. |
| DEVADMIN-BIND | The default bind is `0.0.0.0` with no localhost restriction and no admin token; the dashboard's security rests entirely on `TINA4_DEBUG` being off in production and on a trusted network otherwise. The loopback/token gate that protects MCP was not applied to the REST routes. | Bind the dev server to localhost by default (or refuse the mutation routes on a non-loopback peer, reusing the MCP `is_request_allowed` loopback check for the REST surface). Defense-in-depth so a debug-on reachable box is not a network-exposed RCE. |
| DEVADMIN-MCP-CALL | The `mcp/call` tool-execution gate (MCP-02) is branch-divergent. It is PRESENT on `feature/mcp-call-gate` (PHP `6faabac5`, Ruby `6d5b1de`, Node `27cf0f4` - all gated) but ABSENT on Python `feature/csrf-fail-closed@ebbab30` AND on the shipping `v3@386cd6d` (verified by `git`: `fe92ae9` is not an ancestor; `_api_mcp_call:2976` has no `_mcp_request_allowed` while its four siblings do). So the SHIPPING branch currently exposes an ungated `mcp/call` - a remote unauth caller on a `0.0.0.0` debug box can invoke `database_execute`/`file_write`. | Merge the MCP-02 gate to v3 (it exists, it is real-tested on the sibling branch). Ensure the merge that becomes v3 carries BOTH the MCP-02 gate and the dev-admin CSRF/`.env`/bind fixes - they currently live on two divergent unmerged branches. |
| DEVADMIN-XSS-TOOLBAR | The injected dev toolbar interpolates the raw request path into HTML with NO escaping in Python (`render_dev_toolbar:2178`) and Node (`renderToolbarHtml:2888`), and is injected into every `text/html` response including 404s. A crafted path reflects `<script>` that runs in the dev-server origin, which can then hit every ungated `/__dev` mutation route (chains into DEVADMIN-CSRF). PHP escapes it (`htmlspecialchars`); Ruby's toolbar is a static shell with client-side `Q()` escaping. | Escape the request path (and method) in the injected toolbar in Python and Node, matching PHP. |
| DEVADMIN-TEST-GAPS | The one strong control (the gate) is NOT behaviorally locked, and the dangerous routes are the least tested, in all four. No behavioral "prod -> 404" test (only structural stage-list / route-dict inspection); no CSRF test; no XSS-escaping test; the `.env`-read leak is untested; and the primary dev-admin test in Python and Node drives handlers through MOCK req/resp objects that BYPASS the gate and the router. The destructive routes (`/query`, `/file/save`, `/deps/install`, `/execute`, `/migrate`) have ~zero real route-level coverage. | Add real-dispatch conformance tests (no mocked req/resp): behavioral prod-404, CSRF-rejected, `.env`-read-denied, loopback-only, toolbar-escaping, and mcp/call-gated. See the fixture below. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** Owner call: BIND THE DEV SERVER TO LOCALHOST BY DEFAULT (DEVADMIN-DEC-02). The full security package DEVADMIN-DEC-01/03/04/05/06 is ratified as fixes (fail-closed same-origin gate, `.env`/dotfile denylist, toolbar escaping py+node, merge the MCP-02 gate to v3, real-dispatch conformance tests). See [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) (Batch 5). Next phase: implementation in all four with real (no-mock) tests.

- DEVADMIN-DEC-01 (proposed): implement the fail-closed same-origin gate on the dev-admin mutation surface in
  all four (DEVADMIN-CSRF). This is the highest-value fix and the one that closes drive-by RCE.
- DEVADMIN-DEC-02 (proposed): bind the dev server to localhost by default, or refuse mutation routes on a
  non-loopback peer (DEVADMIN-BIND), reusing the MCP loopback check.
- DEVADMIN-DEC-03 (proposed): add a dotfile/secret denylist to the file endpoints (DEVADMIN-ENV-READ).
- DEVADMIN-DEC-04 (proposed): escape the toolbar path in Python and Node (DEVADMIN-XSS-TOOLBAR).
- DEVADMIN-DEC-05 (proposed): merge BOTH the MCP-02 gate and the dev-admin fixes to v3; the shipping branch
  currently ships an ungated `mcp/call` (DEVADMIN-MCP-CALL).
- DEVADMIN-DEC-06 (proposed): add the real-dispatch conformance tests (DEVADMIN-TEST-GAPS).

These are a coherent security work-package. They do not change the dashboard's purpose or its dev-only
nature; they close the gap between "dev-only" and "safe on a dev machine that also browses the web".

## Proposed conformance fixture

A shared, per-language fixture driving the REAL dispatch (not mocked req/resp):

1. Behavioral prod-404: with `TINA4_DEBUG` off, `POST /__dev/api/file/save` and `GET /__dev` return 404
   through the real server. (Today only the MCP subset has this, and only in some backends.)
2. CSRF rejected: with `TINA4_DEBUG` on, a cross-site `POST` (Origin/Sec-Fetch-Site = cross-site, or no dev
   token) to `/__dev/api/file/save` is rejected and writes nothing. (After DEVADMIN-DEC-01.)
3. `.env` read denied: `GET /__dev/api/file?path=.env` (and `/file/raw`, and the listing) refuses or redacts,
   never returning `TINA4_SECRET`. (After DEVADMIN-DEC-03.)
4. Loopback-only mutations: a non-loopback peer hitting `/__dev/api/query` is refused. (After
   DEVADMIN-DEC-02.)
5. Toolbar escaping: a request path containing `<script>` is HTML-escaped in the injected toolbar. (After
   DEVADMIN-DEC-04, Python + Node.)
6. `mcp/call` gated: a remote unauthenticated `mcp/call` returns 404 AND the tool does not run (assert the
   DB write did not happen) - the existing PHP/Ruby/Node `McpSecurity` pattern, ported to Python and merged
   to v3. (After DEVADMIN-DEC-05.)

## Integration map

- Mount: the dispatch pipeline dev stage (`server.py:2141` / `App.php:599` / `dispatch_pipeline.rb:181` /
  `server.ts:1774`), gated on `TINA4_DEBUG`.
- Composes: the metrics engine (feature 121), the MCP server + `is_request_allowed` gate, the reload watcher
  (`/__dev/api/reload` + the `/__dev_reload` WebSocket), the project index, the plan engine, the dev mailbox,
  and the supervisor/agent proxy (framework port + 2000).
- Related middleware it does NOT reach: `CsrfMiddleware` (post-match, so it never sees `/__dev`) and
  `CorsMiddleware` (deny-by-default, blocks reads not sends).

## Breaking changes and migration

- The CSRF gate (DEVADMIN-DEC-01) and the loopback restriction (DEVADMIN-DEC-02) change how tools reach the
  dashboard: a tool that POSTs to `/__dev` cross-origin, or from a non-loopback host, will need the dev token
  or a loopback connection. Document it; it affects only dev workflows. The `.env` denylist and the toolbar
  escaping are security fixes with no legitimate-use migration. Merging MCP-02 to v3 closes a hole; no
  migration.

## Implementation backlog

1. DEVADMIN-DEC-01: fail-closed same-origin CSRF gate on the mutation surface, all four, with the
   CSRF-rejected conformance test.
2. DEVADMIN-DEC-03: `.env`/dotfile denylist on the file endpoints, all four, with the read-denied test.
3. DEVADMIN-DEC-05: merge the MCP-02 gate to v3 (and carry the dev-admin fixes into the same v3 merge).
4. DEVADMIN-DEC-02: localhost-default bind or non-loopback refusal for mutations, all four, with the
   loopback-only test.
5. DEVADMIN-DEC-04: escape the toolbar path in Python and Node, with the escaping test.
6. DEVADMIN-DEC-06: the behavioral prod-404 test and real-dispatch coverage for the destructive routes, all
   four.

## Porting capsule

The dev admin dashboard is a large shared four-language surface. A clean-room reimplementation needs: a
single dev-only mount gate on `TINA4_DEBUG` that makes the whole surface ABSENT (404) in production (all four
do this well - keep it); a fail-closed same-origin/dev-token check on every mutating route so a cross-origin
page cannot drive it; a localhost-default bind (or a non-loopback refusal) so a debug box is not
network-exposed; a file editor with a dotfile/secret denylist that never serves `.env`; an injected toolbar
that HTML-escapes the request path; the MCP endpoint gated by the loopback-or-token `is_request_allowed`
check (raw peer, XFF-proof, timing-safe token) with that same check extended to the REST mutation routes;
DB-URL redaction and no full-environment dump; subprocess calls via argument arrays only (never a shell
string); and real-dispatch conformance tests that lock the gate, the CSRF rejection, the `.env` denial, and
the mcp/call gate. The lesson: a dev tool that can write files, run SQL, and install packages must assume the
developer also browses the web - "dev-only" is not "safe".

## Audit closure checklist

- [x] Boundary and public surface complete (the mount gate + the read-only/mutating route split x four).
- [x] Lifecycle and every producer/consumer edge complete (dispatch mount, toolbar/inspector stages,
  composed subsystems).
- [x] Configuration, failure, side-effect and security rules complete (gate SOLID; CSRF/`.env`/bind/toolbar/
  mcp-call findings recorded and, for the two most severe Python claims, hand-verified).
- [x] Wire/storage (the `/__dev` JSON API + the mutating side effects) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (toolbar escaping, DB-URL redaction, mcp/call branch
  divergence, client-side escaping).
- [x] Owner ambiguities decided and recorded (DEVADMIN-DEC-01..06 proposed as one security work-package).
- [x] Proposed conformance fixture (prod-404, CSRF, `.env`, loopback, toolbar, mcp/call) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered (CSRF and `.env` first).
- [x] Porting capsule sufficient.
