# Feature 101: Model Context Protocol server

## Identity and status

- Matrix identity: 101 - Model Context Protocol server
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 at Python `386cd6d`, PHP `743b7469`, Ruby
  `c61250c`, Node `26be920`. Four parallel extractions + I self-verified the security core myself (the
  two-layer gate in the Python master, and the HIGH-severity MCP-02 fail-open hole). A fix task for
  MCP-02 has been spawned. No framework code changed in this audit.
- Dependencies: the dev-admin surface (the live `/__dev/mcp` mount + the gate wrappers), the router/
  core server (dispatch; `/__dev/*` serves only when `TINA4_DEBUG`), the request layer (the RAW socket
  peer), the docs/context index (102) and the live API index (103) as tools
- Dependants: AI coding tools (Claude Desktop/Code) driving the framework over MCP; the dev-admin panel
  (the REST shim)
- Existing ADRs: none specific to MCP. The two-layer gate (v3.13.40) is the security model; this audit
  proposes the first MCP ADR (ratifying the gate) + the fixture.
- Shared fixtures: NONE. `mcp_contract.json` is owed (MCP-05). The gate is proven per-framework by real
  tests, but the coverage is uneven (the very hole MCP-02 exposes is untested in Python and Node), and
  no single oracle drives all four.
- Catalog phase: Developer tooling

## Why this feature exists

An AI coding tool needs to inspect and drive a Tina4 project - query the DB, read the live API index,
search docs, run migrations - over a standard protocol. Tina4 ships a ZERO-DEPENDENCY MCP server
(hand-rolled JSON-RPC 2.0 over Streamable HTTP + legacy SSE) that exposes ~49 built-in dev tools behind
a two-layer security gate, mounted at `/__dev/mcp` in every language. It is a DEV surface: it serves
only when `TINA4_DEBUG` is on, and the gate defends the case where such a server is reachable remotely.

## Boundary

This feature owns the MCP SERVER: the `McpServer` class + `mcp_tool`/`mcp_resource` decorators, the
JSON-RPC 2.0 protocol, the transports (Streamable HTTP, legacy SSE, the browser REST shim), the two-
layer security gate (capability + authorization), the built-in dev tools, and the `/__dev/mcp` mount.
The docs/context index (102) and the live API index (103) are exposed here as tools but audited
separately.

## Existing implementation evidence

MCP is LIVE and reference-quality-hardened in all four (the "built-but-dark" memory is STALE):

| Evidence | Python (master) | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `/__dev/mcp` serves live over HTTP (not inert) | yes | yes | yes | yes (50/50 real-HTTP) |
| Hand-rolled JSON-RPC 2.0 + Streamable HTTP + SSE (no MCP SDK) | yes | yes | yes | yes |
| Capability gate (`is_enabled`: TINA4_MCP > TINA4_DEBUG) | yes | yes | yes | yes |
| Authorization gate (loopback; else REMOTE + token) | yes | yes | yes | yes |
| RAW socket peer, NEVER X-Forwarded-For | yes | yes | yes | yes |
| No token configured -> remote denied; timing-safe compare | yes | yes | yes | yes |
| `is_localhost()` informational only; 0.0.0.0 not loopback | yes | yes | yes | yes |
| Every MCP surface 404s a disallowed caller | NO (/call ungated) | yes | yes | yes |
| `database_query` SELECT/WITH-only + no-stacked | yes | yes | yes | yes |
| File tools sandboxed (parent + symlink re-check) | yes | yes | yes | yes (file_patch weaker) |
| Wire-level authz gate tested (remote-denied over HTTP) | NO | yes | yes | NO |

The protocol, the transports, the gate LOGIC, the SELECT-only DB tool and the sandboxed file tools are
at exact parity. The divergences are one HIGH-severity fail-open hole in the master (MCP-02), a shared
ungated developer API (MCP-01), a Node file-tool weakness (MCP-03), and a wire-level test gap (MCP-04).

## Public surface contract

`McpServer(path, name, version)` with `register_tool`/`register_resource` and the `mcp_tool`/
`mcp_resource` decorators; `handle_message` (JSON-RPC entry), `dispatch_http` (Streamable HTTP),
`dispatch_sse_message` + `sse_stream` (legacy SSE), and the session lifecycle (`open_session`/
`is_valid_session`/`close_session`/`negotiate_protocol_version`). The security predicates are
module-level: `is_enabled()`, `is_request_allowed(remote_ip, has_valid_token)`, `is_loopback(ip)`,
`is_localhost()` (informational). The live mount + the per-request gate wrappers live in the dev-admin
layer, NOT in `McpServer` (MCP-01). `register_routes()` is a developer self-mount API - ungated (MCP-01).

## Inputs and outputs

- Input: JSON-RPC 2.0 requests (initialize, tools/list, tools/call, resources/list, resources/read,
  ping) over Streamable HTTP (`POST /__dev/mcp`), legacy SSE (`GET /__dev/mcp/sse` + `POST
  /__dev/mcp/message`), or the browser REST shim (`GET /__dev/api/mcp/tools`, `POST /__dev/api/mcp/call`).
- Output: JSON-RPC results / MCP `content`; standard error codes (PARSE_ERROR, METHOD_NOT_FOUND,
  INTERNAL_ERROR; INVALID_PARAMS is defined but unused). A disallowed caller gets 404 on every surface
  EXCEPT the Python `/call` shim (MCP-02). Tools run with the project's privileges (DB, filesystem).

## Lifecycle and operation graph

1. MOUNT: at boot, when `TINA4_DEBUG` (dev), the dev-admin registrar mounts the `/__dev/mcp` routes on
   the live router - each handler wrapped by the two-layer gate (except Python `/call` - MCP-02).
2. CAPABILITY: `is_enabled()` (explicit `TINA4_MCP` wins, else `TINA4_DEBUG`) - host-independent.
3. AUTHORIZATION: `is_request_allowed(remote_ip, has_valid_token)` - loopback always; a remote caller
   needs `TINA4_MCP_REMOTE` AND a valid token (against the RAW socket peer, never X-Forwarded-For).
4. DISPATCH: the JSON-RPC method routes to a handler; `tools/call` runs the tool; `database_query` is
   SELECT/WITH-only; file tools are sandboxed to the project root.

## Configuration and precedence

- `TINA4_MCP` (capability override; explicit wins) > `TINA4_DEBUG` (fallback capability + the mount
  gate). `TINA4_MCP_REMOTE` (necessary-not-sufficient for a remote caller). `TINA4_MCP_TOKEN` >
  `TINA4_API_KEY` (no token configured -> remote denied). `TINA4_MCP_PORT` (default main+2000).
- Note (Python): `is_enabled()` is true for `TINA4_MCP=true` alone, but the `/__dev/*` mount is gated on
  `TINA4_DEBUG`, so `TINA4_MCP=true` without `TINA4_DEBUG` does NOT expose the endpoint - fails safe, but
  contradicts the "explicit TINA4_MCP wins" capability model. Worth aligning.

## Failures, side effects and security

- THE TWO-LAYER GATE is reference-quality in logic across all four: a capability layer (host-
  independent) and an authorization layer that is FAIL-CLOSED (a remote caller is denied unless
  `TINA4_MCP_REMOTE` AND a token match), sourced from the RAW socket peer with an explicit "NEVER
  X-Forwarded-For" guard (a separate XFF-aware field exists and the gate ignores it), `0.0.0.0`
  deliberately excluded from loopback (fixing the old `is_localhost` bug), and a timing-safe token
  compare. `is_localhost()` is informational only.
- MCP-02 (HIGH, the master's fail-open hole): the tool-INVOCATION REST shim `POST /__dev/api/mcp/call`
  is UNGATED in Python (`dev_admin/__init__.py:2976` - self-verified: no `_mcp_request_allowed` call;
  runs `handler(**args)` for any tool). Every sibling surface (tools-list, JSON-RPC, SSE) IS gated, and
  PHP, Ruby AND Node all gate their `/call` shim. So on a `TINA4_DEBUG=true` server bound to `0.0.0.0`
  (the exact scenario the gate defends), a remote unauthenticated caller can invoke every tool -
  including `database_execute` (arbitrary SQL writes) and `file_write`. Python-master-only; a fix-Python
  (not mirror) item, with a spawned fix task.
- MCP-01 (shared footgun): the reusable `McpServer.register_routes()` custom-mount API is ungated in all
  four - the gate lives in the dev-admin layer, not the class - so a developer wiring a custom MCP
  server per the class docblock gets an unauthenticated endpoint. Dead/unused in shipped code (the
  built-in `/__dev/mcp` goes through the gated dev-admin path), but a latent secure-by-default hole.
- `database_query` is SELECT/WITH-only and rejects stacked statements (comment-stripped, leading-
  SELECT/WITH); writes go through a separate `database_execute` (itself behind the gate). File tools are
  sandboxed to the project root with a symlink re-check - except Node's `file_patch` (MCP-03), which
  uses a weaker bare-prefix check.

## Wire and persistence contract

No persistence. The wire is JSON-RPC 2.0 (protocol versions 2025-06-18 / 2025-03-26 / 2024-11-05) over
Streamable HTTP (a `Mcp-Session-Id` header issued on initialize; a notification -> 202/empty) and legacy
HTTP+SSE (an `event: endpoint` frame then queued `event: message` frames with keep-alives), plus a
browser REST shim. The tool schemas are advertised via `tools/list`; the resources half of the protocol
is implemented but no built-in resource is registered (so `resources/list` is empty).

## Providers and substitutability

No provider seam - the tools ARE the surface. An app registers its own tools/resources via the
decorators or `register_tool`. The docs/context index (102) and the live API index (103) are the two
tool families audited separately. An external MCP client (Claude Desktop/Code) is the consumer.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| MCP-02 | SECURITY (HIGH), FIX PYTHON - **FIXED 2026-08-11 on `feature/mcp-call-gate` (awaiting v3 merge; release parked)**: the tool-invocation REST shim `POST /__dev/api/mcp/call` was UNGATED in the Python master (`dev_admin/__init__.py:2976` - self-verified). It ran any tool (incl. `database_execute`, `file_write`) with no `_mcp_request_allowed` check, while every sibling surface IS gated and PHP/Ruby/Node all gate their `/call`. On a `TINA4_DEBUG=true` server bound to `0.0.0.0`, a remote unauthenticated caller could invoke every tool. Shipped on v3. Untested (no test drove `/call`; all gate tests used loopback). | DONE: Python added the sibling gate to the top of `_api_mcp_call` (`if not _mcp_request_allowed(request): return response(..., 404)`) - the ONLY framework that needed a code change (`tina4-python fe92ae9`, red-before-green: the 2 negatives failed pre-fix, pass after; 80 MCP tests green). Lock-in regression tests added to all four, each driving the REAL `/call` route with a non-loopback peer + a real SQLite row-witness ("the tool did not run"), MUTATION-PROVEN: Python `fe92ae9`, Ruby `6d5b1de` (97 green), PHP `6faabac5` (114 tests), Node `27cf0f4` (24 new, + closed the `mcpTokenOk` gap). All on `feature/mcp-call-gate` from v3; v3 untouched. |
| MCP-01 | SECURITY footgun (shared all four): the reusable `McpServer.register_routes()`/`registerRoutes()` developer self-mount API mounts routes with `noAuth()` and NO `is_request_allowed` gate - the two-layer gate lives in the dev-admin layer, not the class. A developer wiring a custom MCP server per the class docblock exposes an unauthenticated endpoint. Dead/unused in shipped code, so the built-in endpoint is safe. | Fold the two-layer gate into `dispatch_http`/`register_routes` (so the reusable class is safe by construction), OR remove the dead `register_routes` API and document that custom mounts must gate. All four. |
| MCP-03 | Node file-tool weakness: `file_patch` (`mcp.ts:1878`) uses a bare `resolved.startsWith(projectRoot)` instead of the hardened `safePath` (parent-containment + symlink re-check) the other Node file tools and all Python/PHP/Ruby file tools use. It accepts a `<root>-evil` sibling and skips the symlink re-check. | Node routes `file_patch` through `safePath`, matching the other file tools and the other frameworks. |
| MCP-04 | Test coverage: the authorization gate (remote-denied / token-required / XFF-ignored) was unit-proven but NOT driven end-to-end over the wire in Python and Node - their endpoint tests only toggled the CAPABILITY gate from loopback, and Node's token check had no test at all. PHP and Ruby DID have the wire-level negatives (real remote peer + spoofed-XFF -> 404). This gap is exactly why MCP-02 survived in Python. | **CLOSED for `/call` 2026-08-11 (feature/mcp-call-gate)**: all four now drive the `/call` surface end-to-end with a non-loopback peer (no-token -> 404 + tool-did-not-run; valid Bearer -> 200 + tool-ran; spoofed `X-Forwarded-For: 127.0.0.1` -> 404) against a real DB row-witness; Node's previously-untested `mcpTokenOk` path is now covered (`27cf0f4`). REMAINING: extend the same wire-level negatives to the other Python/Node surfaces (tools-list, JSON-RPC, SSE), which still only toggle the capability gate from loopback. |
| MCP-05 | No `mcp_contract.json`; no CONTRACT-MAP row; no ADR. The gate is proven per-framework but unevenly, and no single oracle drives all four - and the security stakes are high. | Add `mcp_contract.json` gating the two-layer contract (capability, loopback-allowed, remote-denied-without-token, token-required, XFF-ignored, every-surface-404-incl-/call), the SELECT-only DB tool, and the file sandbox; add the first MCP ADR ratifying the gate. |

Minor (recorded so they are not re-raised): stale tool-count docstrings ("24 tools" vs ~49) in Python/
Ruby; `INVALID_PARAMS` defined but never emitted; dead exports (`register_routes`/`write_claude_config`/
`mcp_port`); the resources half implemented with no built-in resource. None are security-relevant.

## Owner decisions

The gate LOGIC and the two-layer model are settled parity. The open calls are the security fixes and
the fixture:

1. MCP-02 (SECURITY, HIGH): Python gates `/call` (fix task spawned); regression test in all four.
2. MCP-01 (SECURITY): gate the reusable `register_routes` (or remove it) in all four.
3. MCP-03: Node hardens `file_patch`.
4. MCP-04: Python + Node add wire-level authz-gate negatives.
5. MCP-05 + ADR: add `mcp_contract.json` and the first MCP ADR.

## Proposed conformance fixture

Add `mcp_contract.json` driving four runners against a real HTTP server (no mocks - PHP/Ruby/Node already
do this): a disabled server 404s even a loopback caller; an enabled server allows loopback; a REMOTE
peer is 404'd without a token AND with a wrong token, and allowed only with `TINA4_MCP_REMOTE` + a valid
token; a spoofed `X-Forwarded-For: 127.0.0.1` is IGNORED (raw peer governs); EVERY surface - tools-list,
`/call`, JSON-RPC, SSE - enforces this (the MCP-02 witness: a remote unauthenticated `POST /call` invoking
`database_execute` is 404'd and the write does not happen); `database_query` rejects UPDATE/DELETE/DROP
and stacked statements; and a file tool rejects a `../` traversal and a symlink escape. The `/call`
remote-denied case is the load-bearing witness.

## Integration map

- Mounted by the dev-admin layer on the live router when `TINA4_DEBUG`; gated by the two-layer predicates;
  the RAW socket peer comes from the request layer.
- The docs/context index (102) and the live API index (103) are exposed as tools here.
- `mcp_contract.json` (owed) is the shared oracle; the MCP-02 fix + regression is tracked as a spawned
  task; MCP-01 is a shared architectural fix.

## Breaking changes and migration

- MCP-02 (Python gates `/call`) changes a currently-fail-open surface to fail-closed: a remote caller
  that relied on the ungated `/call` (there should be none - it was a hole) now needs a token. This is a
  security fix, not a feature break; `Breaking:` only for a caller exploiting the hole.
- MCP-01 (gating `register_routes`) makes a custom-mounted MCP server require the gate: a developer who
  mounted an intentionally-open MCP endpoint via `register_routes` must now supply the peer/token - the
  correct default. Gate on the owner decision (gate vs remove).
- MCP-03/MCP-04/MCP-05 are additive (a hardened sandbox, tests, a fixture).

## Implementation backlog

1. MCP-02: Python gates `_api_mcp_call`; red-before-green regression in all four (spawned task).
2. MCP-01: gate or remove `register_routes` in all four.
3. MCP-03: Node hardens `file_patch`; MCP-04: Python + Node add wire-level gate negatives.
4. MCP-05: add `mcp_contract.json` + the first MCP ADR; run on the lab, flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit (the MCP-02 fix ships on its own branch).

## Porting capsule

Implement a zero-dependency MCP server: a `McpServer` with `register_tool`/`register_resource` and
`mcp_tool`/`mcp_resource` decorators; hand-rolled JSON-RPC 2.0 (initialize/tools/resources/ping, standard
error codes) over Streamable HTTP (issue an `Mcp-Session-Id` on initialize) and legacy SSE. Gate EVERY
mounted surface - INCLUDING the tool-invocation shim - with a two-layer check: a capability gate
(`TINA4_MCP` > `TINA4_DEBUG`, host-independent) and an authorization gate (loopback always; a remote
caller needs `TINA4_MCP_REMOTE` AND a token matching `TINA4_MCP_TOKEN`/`TINA4_API_KEY` via Bearer/
X-MCP-Token/X-Api-Key, timing-safe), sourced from the RAW socket peer (NEVER X-Forwarded-For), with
`0.0.0.0` excluded from loopback. Put the gate where the reusable server can enforce it, not only in the
dev-admin mount. Make `database_query` SELECT/WITH-only (reject stacked statements; a separate gated
`database_execute` for writes) and sandbox file tools to the project root (parent-containment + symlink
re-check). Prove it with `mcp_contract.json`: the every-surface-404 gate (incl. `/call`), the SELECT-only
guard, and the sandbox.

## Audit closure checklist

- [x] Boundary and public surface complete (the MCP server; docs/API-index tools are 102/103).
- [x] Lifecycle and every producer/consumer edge complete (mount/capability/authorization/dispatch).
- [x] Configuration, failure, side-effect and security rules complete (two-layer gate, MCP-02 fail-open, SELECT-only, sandbox).
- [x] Wire/storage and provider contracts complete (JSON-RPC 2.0 + Streamable HTTP + SSE; tools are the surface).
- [x] Existing-language contradictions recorded (MCP-01..05; live+hardened parity except the master's /call hole).
- [x] Owner ambiguities recorded (5; the /call gate and the reusable-class gate are the security keys).
- [x] Proposed shared cases and mutation witnesses complete (`mcp_contract.json`, real HTTP, the /call remote-denied witness).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
