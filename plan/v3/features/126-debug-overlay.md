# Feature 126: Development error overlay (rich page in dev, safe page in prod)

## Identity and status

- Matrix identity: 126 - Development error overlay (`tina4_python/debug/error_overlay.py` and siblings)
- Audit state: decision-ready
- Audit note: FOUR-language feature, a shared port (near-identical structure in all four). Measured
  2026-08-11 from shipped source by four parallel per-language readers. Python
  `tina4_python/debug/error_overlay.py` (279 lines, branch `feature/csrf-fail-closed` HEAD `ebbab30`);
  PHP `Tina4/ErrorOverlay.php` (390 lines, `feature/mcp-call-gate` HEAD `6faabac5`); Ruby
  `lib/tina4/error_overlay.rb` (282 lines, `feature/mcp-call-gate`); Node
  `packages/core/src/errorOverlay.ts` (318 lines, `feature/mcp-call-gate` HEAD `27cf0f46`).
- Dependencies: the per-language HTML-escape primitive, `linecache`/`File.readlines`/`file()`/`readFileSync`
  for source context, and `TINA4_DEBUG` (the dev gate). The production page depends on the framework's
  `500.twig` template renderer.
- Dependants: every unhandled route-handler exception in development; the server's 500 path.
- Existing ADRs: none dedicated.

- Catalog phase: developer experience (dev tooling)

## Why this feature exists

When a route handler throws in development, the error overlay turns a blank 500 into a page a developer
can act on: the exception type and message, the full stack, a seven-line source window around each frame
with the failing line marked, the request details, and the environment. In production the same 500 shows
a generic page and nothing else. The overlay is the dev half of a two-faced error path: rich when you are
building, silent when you ship. The security of the feature rests on that gate holding and on every
attacker-influenced string being escaped before it reaches HTML.

## Boundary

This packet owns the overlay module in each language: `render_error_overlay` (the rich dev page),
`render_production_error` (the generic page), `is_debug_mode` (the `TINA4_DEBUG` predicate), and the
private helpers (escape, source read, frame format, table). It does NOT own the server's dispatch
try/catch that CALLS the overlay (that is the router/server packet), nor the `500.twig` template that the
real production path renders, nor the `TINA4_DEBUG`-based detail suppression in GraphQL/WSDL (which reuse
`is_debug_mode` but are separate features).

## Existing implementation evidence

Four-language parity table (public surface + the security-critical axes):

| Axis | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Module | `debug/error_overlay.py` | `Tina4/ErrorOverlay.php` | `lib/tina4/error_overlay.rb` | `packages/core/src/errorOverlay.ts` |
| Rich dev page | `render_error_overlay` :147 | `renderErrorOverlay` :52 | `render_error_overlay` :41 | `renderErrorOverlay` :186 |
| Generic page | `render_production_error` :243 | `renderProductionError` :207 | `render_production_error` :124 | `renderProductionError` :279 |
| Gate predicate | `is_debug_mode` :267 | `isDebugMode` :254 | `is_debug_mode` :166 | `isDebugMode` :316 |
| Escape (all 5 chars) | `html.escape` :54 | `htmlspecialchars` ENT_QUOTES :262 | hand-rolled `esc` :172 | `esc` regex :49 |
| Source window | linecache, 7 lines | `@file`, 7 lines | `File.readlines`, 7 lines | `readFileSync`, 7 lines |
| Sole overlay caller | `server.py:1961` | `Router.php:815` | `rack_app.rb:692` | `server.ts:1296` |
| Overlay gate uses module `is_debug_mode`? | NO (server recomputes) | YES (`Router.php:813`) | NO (`dev_mode?`) | NO (`isDevMode`) |

- The rich page shows, in all four: exception type + message (escaped), the full stack, a seven-line
  source window per frame (`CONTEXT_LINES = 7`) with the failing line highlighted, a Request Details
  table, and a fixed six/seven-row Environment table (framework, version, language version, platform,
  `TINA4_DEBUG`, `TINA4_LOG_LEVEL`). The Environment table reads only those named vars - it does NOT dump
  the whole environment in any language.
- The generic page (`render_production_error`) shows only the status code, a generic message, fixed copy,
  an optional escaped path, and a Go-Home link - no stack, source, message, or environment.
- The real production 500 path does NOT call `render_production_error` (see PROD-DEAD below): it renders
  `errors/500.twig` with `error_message` set to the empty string, with a CWE-209 comment, falling back to
  a generic JSON body.

## Public surface contract

Three public functions per language, identical shape: `render_error_overlay(exception, request=nil)`
returns the rich dev HTML; `render_production_error(status_code=500, message="Internal Server Error",
path="")` returns the generic HTML; `is_debug_mode()` returns whether `TINA4_DEBUG` is truthy. The
overlay is NOT self-gating - each function always renders its page; the CALLER (the server dispatch)
decides which to call based on the dev gate.

## Inputs and outputs

- Input: a thrown exception (type, message, stack/backtrace, and the source files the frames name), an
  optional request object (method, url, path, ip, headers, params, query, body), and `TINA4_DEBUG` /
  `TINA4_LOG_LEVEL`.
- Output: an HTML string - the rich overlay in dev, the generic page in prod. No side effects beyond
  reading the source files the stack frames name.

## Lifecycle and operation graph

1. A route handler throws; the server dispatch catches it (`server.py:2319` / `Router.php:782` /
   `rack_app.rb:141` / `server.ts:1900`).
2. The dispatch logs the error server-side (never in the response body - the CWE-209 guard), then checks
   the dev gate (`TINA4_DEBUG` truthy).
3. Dev: call `render_error_overlay(error, request)` and return it with a 500. Prod: render `500.twig`
   with an empty `error_message` (NOT `render_production_error`).
4. Inside the overlay: escape the type/message, walk every frame, read a seven-line source window per
   frame, build the request and environment tables, assemble the page.

## Configuration and precedence

- `TINA4_DEBUG` (truthy set `true/1/yes/on`, case-insensitive) is the gate; default off, so the overlay
  is dev-only. `TINA4_LOG_LEVEL` is read for the Environment row only (default `ERROR` in Python/Node/Ruby,
  `INFO` in PHP - a minor cross-language default inconsistency). No other configuration; the overlay takes
  no flags.

## Failures, side effects and security

- ESCAPING (SECURE, all four): every attacker-influenceable string - the exception message, every source
  line, frame filenames, and all request/environment table keys and values - is HTML-escaped for all five
  characters (`& < > " '`). Python `html.escape`, PHP `htmlspecialchars(ENT_QUOTES | ENT_SUBSTITUTE)`,
  Node a five-replace `esc`, and Ruby a hand-rolled `esc` that escapes the single quote to `&#39;` -
  deliberately STRONGER than `CGI.escapeHTML` (which leaves `'`), so Ruby dodged the classic single-quote
  gap. Each language ships an XSS regression test (a `<script>` payload in the message, asserted absent
  and entity-encoded present). No XSS hole was found in any language.
- PRODUCTION (SECURE, all four): the real production 500 leaks nothing - the wired path renders `500.twig`
  with an empty `error_message` and falls back to a generic JSON body; the exception detail stays in the
  server log only. Ruby additionally has a real wired-path conformance test (`router_error_event_spec.rb`)
  that drives the actual dispatch in production mode and forbids `.rb:` / backtrace strings in the body -
  the pattern the other three lack.
- OVERLAY-SENSITIVE (dev-only exposure, all four): the dev overlay renders request BODY and PARAMS
  verbatim (escaped), so a POST body containing a password is displayed. In Python, Node, and Ruby the
  Request table also renders request HEADERS, so an `Authorization: Bearer ...` or `Cookie:` header on the
  failing request is shown in cleartext (escaped). PHP alone does NOT show headers on the wired path - the
  router passes headers as a `CaseInsensitiveArray` object and the overlay only expands arrays, an
  ACCIDENTAL dodge, not a deliberate redaction (PHP still shows body/params). This is gated behind
  `TINA4_DEBUG`, so it is a dev-tool behaviour, not a production leak - but any operator who runs
  `TINA4_DEBUG=true` on a shared or staging box exposes bearer tokens, cookies, and submitted passwords on
  any 500. There is no redaction list in any language.
- OVERLAY-SELF-THROW (robustness, all four): the dev-overlay render has no top-level guard, and the caller
  invokes it from INSIDE the dispatch catch/rescue with no inner guard - so if the overlay itself throws
  (a malformed frame, a source-read edge), it double-faults out of the dispatch instead of degrading to
  the safe page. Ruby is the clearest: its production branch is guarded (`rescue "500 Internal Server
  Error"`) but its dev branch is not.
- OVERLAY-NO-FRAME-CAP (robustness, all four): no cap on frame count. A deep or recursive stack does one
  source-file read per frame and produces an unbounded HTML page (a `RecursionError`-class stack yields a
  huge response). No truncation anywhere.
- Source read (a NOTE, not a hole, all four): the overlay reads the file each stack frame names, with no
  project-root confinement, so it can read framework/vendor/stdlib files that appear in the stack. The
  frame paths come from the runtime stack, NOT from user input, so there is no attacker-driven path
  traversal; each read is guarded (is-file / is-readable / try-catch). PHP's `DatabaseCredentialLeakTest`
  confirms the trace consumers read only file/line/class/type/function, never the trace ARGS, so exception
  argument values do not leak.

## Wire and persistence contract

No persisted state. The contract is the HTML each function emits: the rich page's sections (Exception,
Stack Trace, Request Details, Environment) and the generic page's minimal body (status, message, path,
Go-Home). The production wire contract is `500.twig` with an empty `error_message` plus the generic JSON
fallback.

## Providers and substitutability

No provider abstraction; the escape primitive, the source reader, and the templates are hardcoded per
language. The only substitution axis is dev-vs-production, selected by the caller via the gate.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| OVERLAY-PROD-DEAD | `render_production_error` / `renderProductionError` is defined, documented as THE production entry, and unit-tested for no-leak in all four - but is NEVER invoked by runtime code. The real production 500 renders `500.twig`. So the production-no-leak UNIT test proves nothing about the live path (it exercises a dead sibling). | Decide the function's fate (delete-and-retest is proposed - see OVERLAY-DEC-01). Whichever way, add a real wired-path production-no-leak conformance test in all four (copy Ruby's `router_error_event_spec.rb`), and fix the module docstrings that point production callers at the dead function. |
| OVERLAY-SENSITIVE | The dev overlay renders request body/params (password-in-body) in all four, and Authorization/Cookie headers in Python/Node/Ruby (PHP hides headers only by an object-not-array accident). Dev-gated, but a real secret exposure on a shared/staging `TINA4_DEBUG=true` box. | Add a redaction deny-list applied even in dev: mask `Authorization`, `Cookie`, `Set-Cookie`, and any body/param key matching `password|token|secret|key|authorization`. Make PHP's header hiding deliberate (redact, do not rely on the array quirk). Parity across all four. |
| OVERLAY-SELF-THROW | The dev-overlay call site sits inside the dispatch catch/rescue with no inner guard, so an overlay-render throw double-faults out (the dev path can crash the crash handler). | Wrap the dev-overlay render in a try/catch at the call site (or inside the function); on failure fall back to the generic production page, so a 500 is always served. All four. |
| OVERLAY-NO-FRAME-CAP | No frame cap: a deep/recursive stack does one file read per frame and emits an unbounded page. | Cap the rendered frames (for example the top 50) and note the truncation in the page. All four. |
| OVERLAY-GATE-DRIFT | The module exports `is_debug_mode`, but the overlay gate in Python, Node, and Ruby recomputes `is_truthy(TINA4_DEBUG)` via a separate server-local function (`is_dev` / `isDevMode` / `dev_mode?`). PHP alone calls `ErrorOverlay::isDebugMode()` directly. Two sources of truth in three of four. | Have the server call the module's `is_debug_mode()` for the overlay gate (PHP's wiring is the model), so the gate has one definition. Low risk (same result today). |
| OVERLAY-TESTS-SUSPECT | Node's `errorOverlay.test.ts` is co-located in `packages/core/src`, not under the repo `test/` dir the runner scans - it may not be collected by `run-all.ts` (unverified). Ruby's `error_overlay_spec.rb:72` asserts the overlay contains `TINA4_DEBUG_LEVEL`, a string the code never emits (it emits `Set TINA4_DEBUG=false in production.`) - an apparent failing-or-unrun spec. Ruby also has four dead `error_overlay_*` helpers in `template.rb:118-145` (never called). | Confirm the Node test is collected by the runner (move it under `test/` or add it to the manifest if not). Fix or remove the stale Ruby `TINA4_DEBUG_LEVEL` assertion and confirm the spec runs green. Delete the dead `template.rb` helpers. |
| OVERLAY-DOC | Minor doc drift: Python's docstring claims "syntax-highlighted" (there is no tokenizer - all code is one color) and its usage example passes a non-existent `request_info` kwarg (would `TypeError`); PHP's CLAUDE.md stub omits the third `$path` parameter; Node's docstring illustrates a `renderProductionError` wiring the framework does not use. | Correct the docstrings/CLAUDE.md to match the real signatures and behaviour (First Principle: docs match code). Bundle with the OVERLAY-PROD-DEAD doc fix. |

## Owner decisions

- OVERLAY-DEC-01 (proposed): DELETE `render_production_error` in all four and its misleading docstring +
  dead-path unit test, since the production path is the `500.twig` renderer and the dead function only
  invites the false belief that the no-leak test covers production. Replace it with a wired-path
  production-no-leak conformance test in all four (Ruby already has one to copy). Rationale: less code,
  no dead surface, and a test that actually guards the live contract. (Alternative, if the owner prefers
  a reusable helper: WIRE `render_production_error` as the fallback the dispatch calls when no template
  resolves - but that adds a code path where the template already suffices.)
- OVERLAY-DEC-02 (proposed): redact sensitive request data (Authorization/Cookie/Set-Cookie headers and
  password-like body/param keys) in the dev overlay across all four (OVERLAY-SENSITIVE).
- OVERLAY-DEC-03 (proposed): guard the dev-overlay render and cap the frame count in all four
  (OVERLAY-SELF-THROW + OVERLAY-NO-FRAME-CAP), so a broken overlay or a recursive stack still yields a
  bounded, safe 500.
- OVERLAY-DEC-04 (proposed, low priority): unify the gate on the module's `is_debug_mode()`
  (OVERLAY-GATE-DRIFT), fix the suspect tests (OVERLAY-TESTS-SUSPECT), and correct the docs (OVERLAY-DOC).

## Proposed conformance fixture

A shared, per-language fixture covering the contract and the findings:

1. XSS: a `<script>` exception message is entity-encoded, not present raw (positive lock-in exists in all
   four; keep it).
2. Wired-path production no-leak: drive the REAL dispatch in production mode (`TINA4_DEBUG` off) with a
   handler that throws `secret marker in the message`, and assert the 500 body contains neither the
   message, nor `.rb:` / traceback / source markers (Ruby's `router_error_event_spec.rb` is the template;
   port it to the other three). This replaces the dead-function unit test as the real guarantee.
3. Redaction (after OVERLAY-DEC-02): a request carrying `Authorization: Bearer sekret` and a body
   `{"password": "hunter2"}` renders the overlay with those values masked, in dev.
4. Frame cap (after OVERLAY-DEC-03): a 5000-deep recursive stack renders a bounded page (frame count
   capped, truncation noted) rather than an unbounded one.
5. Self-throw fallback (after OVERLAY-DEC-03): if the overlay render raises, the dispatch still returns a
   generic 500, not a double-fault.
6. Gate: `is_debug_mode()` returns true/false across the truthy/falsey matrix (exists in all four; keep).

## Integration map

- Sole overlay caller: the server dispatch catch/rescue - `server.py:1961` (`_handle_route_error`),
  `Router.php:815`, `rack_app.rb:692` (`handle_500`), `server.ts:1296` (`renderDispatchError`).
- Production 500: the `500.twig` template renderer (`_render_error_page` / `Router::renderError` /
  `Template.render_error` / `renderErrorPage`), NOT `render_production_error`.
- Shared gate consumer: GraphQL and WSDL reuse `is_debug_mode()` to suppress error detail in production
  (`graphql/__init__.py:730`, `wsdl/__init__.py:200`, and the PHP/Ruby/Node equivalents) - a separate
  feature that depends on the same predicate.

## Breaking changes and migration

- Deleting `render_production_error` (OVERLAY-DEC-01) removes a public function; since nothing in the
  framework calls it, the only risk is an app that imported it directly - document the removal and point
  such callers at the template path. Redaction (OVERLAY-DEC-02) changes the dev overlay's rendered
  content (secrets masked) - a security improvement, not a contract break. The frame cap changes very-deep
  stacks' output - document it.

## Implementation backlog

1. Add the wired-path production-no-leak conformance test in Python/PHP/Node (port Ruby's), then resolve
   `render_production_error` per OVERLAY-DEC-01 (delete + doc fix).
2. Add sensitive-data redaction to the dev overlay in all four (OVERLAY-DEC-02) with the redaction test.
3. Guard the dev-overlay render + cap frames in all four (OVERLAY-DEC-03) with the two robustness tests.
4. Unify the gate, fix the suspect Ruby/Node tests, delete the dead `template.rb` helpers, and correct the
   docstrings/CLAUDE.md (OVERLAY-DEC-04).

## Porting capsule

The error overlay is a shared four-language port with near-identical structure. A clean-room
reimplementation needs: a `render_error_overlay(exception, request)` that escapes EVERY dynamic string
for all five HTML characters (message, source lines, filenames, table cells) before output; a seven-line
source window per frame read from the file the frame names (guarded, no attacker input); a Request table
that REDACTS Authorization/Cookie/password-like fields even in dev; a fixed Environment table that reads
only named vars (never the whole environment); a frame cap; and a top-level guard so a render failure
falls back to the generic page. The production 500 must be a generic template with the exception detail
kept server-side only (CWE-209), and it must be covered by a test that drives the REAL dispatch in
production mode - not a unit test of an unwired helper. Gate everything on one `is_debug_mode()`
definition.

## Audit closure checklist

- [x] Boundary and public surface complete (three functions x four languages).
- [x] Lifecycle and every producer/consumer edge complete (dispatch caller, template prod path, shared
  gate consumers).
- [x] Configuration, failure, side-effect and security rules complete (escaping SECURE, prod SECURE,
  dev sensitive-data + robustness findings recorded).
- [x] Wire/storage (HTML contract, `500.twig`) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (PHP gate + header-dodge, Ruby wired-path test +
  suspect spec, Node test-collection).
- [x] Owner ambiguities decided and recorded (OVERLAY-DEC-01..04 proposed).
- [x] Proposed conformance fixture (wired-path no-leak, redaction, frame cap, self-throw) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
