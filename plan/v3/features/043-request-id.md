# Feature 43: Request ID (correlation id)

## Identity and status

- Matrix identity: 43 - Request ID / correlation id
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language source (correcting a prior-session doc that treated
  the log-context + error-page use as a working four-language convergence - it is NOT; the feature is wired
  end-to-end ONLY in Python, process-scoped in PHP, and DORMANT in Ruby/Node). Python `core/server.py:2559` +
  `debug/__init__.py:115` (`ebbab30`); PHP `Tina4/App.php:304,1700` + `Tina4/Log.php:43` (`6faabac5`); Ruby
  `lib/tina4/log.rb:246` (defined, never called) (`6d5b1de`); Node `packages/core/src/server.ts:1843` +
  `logger.ts:237` (setter never called) (`27cf0f4`).
- Dependencies: the logger, the response builder, the error-page renderer.
- Dependants: log correlation; cross-service tracing; the production error page.
- Existing ADRs: none dedicated.

- Catalog phase: Routing and middleware

## Why this feature exists

A per-request correlation id ties a request's log lines together and lets a client (or a downstream service)
reference one request. The audit question is whether this works in all four. It does not: only Python
generates a per-request id, honours an inbound header, emits a response header, and threads it into logs and
the error page. PHP has one id per PROCESS; Ruby and Node have the API but never call it in the request path,
so their logs never carry an id.

## Existing implementation evidence

- PYTHON - full feature, with two live defects. `server.py:2559` `request_id =
  request.headers.get("x-request-id", str(uuid.uuid4())[:8])` (honours inbound, else an 8-hex uuid4 prefix);
  `:2564` `response.header("x-request-id", request_id)` (emits it); `:2560` `set_request_id(...)`; logs carry
  it (`debug/__init__.py:570,588`); the 500 page shows the SAME id (`server.py:604` -> `500.twig:33`).
  DEFECTS: the inbound value is used UNSANITIZED; storage is `threading.local` (`debug/__init__.py:115`) under
  an asyncio event loop, so concurrent requests share one slot (no isolation). See the register.
- PHP - one id per PROCESS. `App.php:304` `Log::setRequestId($this->generateRequestId())` runs in the
  constructor; `App.php:1702` `substr(bin2hex(random_bytes(8)), 0, 16)` (16 hex). Under the persistent
  built-in server every request in the process shares that one id. Honours no inbound header, emits no
  response header. The prod 500 page uses a SEPARATE fresh `md5(uniqid())[:12]` (`Router.php:833`) that does
  not match the log id - and this throwaway is the formula the prior doc mis-cited as PHP's generation.
- RUBY - DORMANT. `set_request_id` is defined (`log.rb:246`) but never called outside specs; the request path
  never sets an id, so logs never carry one. The only per-request id is a throwaway `SecureRandom.hex(6)` for
  the 500 page (`rack_app.rb:699`); the dev toolbar shows `-`.
- NODE - cosmetic only. `server.ts:1843` `Date.now().toString(36)` per request (a base36 ms clock,
  collision-prone) used ONLY by the dev toolbar; a separate one for the 500 page (`server.ts:1304`). Never on
  logs (`Log.setRequestId` never called; `logger.ts:372`), never on the wire, never honours inbound.

## Public surface contract

Intended: every request has an id (inbound `x-request-id` honoured, else generated), echoed in the response
`x-request-id`, attached to every log line, and shown on the error page. Today this contract holds only in
Python (with defects).

## Inputs and outputs

- Input: an optional inbound `x-request-id`. Output (Python): the id in the response header, the log lines,
  and the error page. Output (PHP): a process-constant id in logs only. Output (Ruby/Node): none in practice.

## Lifecycle and operation graph

1. (Python) per request: read `x-request-id` or generate -> store -> emit response header -> log lines use it
   -> error page uses it. 2. (PHP) once per process: generate -> store -> logs use it. 3. (Ruby/Node) no
   request-path wiring.

## Configuration and precedence

- No env var, no configurable header name, in any language. The header is hardcoded `x-request-id`
  (Python only).

## Failures, side effects and security

- SECURITY (Python): the inbound `x-request-id` is reflected UNSANITIZED into a response header and log lines
  (`server.py:2559,2564`, `debug/__init__.py:589`) - a header/log-injection vector (an attacker sets the
  header). See the register.
- CORRECTNESS (Python): `threading.local` under asyncio does not isolate concurrent requests - one request's
  id can overwrite another's, so a log line or response can carry the WRONG id under load.
- The error-page id is disconnected from the log id in PHP/Ruby/Node (a user cannot correlate it to logs).

## Wire and persistence contract

The only wire output is Python's `x-request-id` response header. No persisted state. There is NO cross-language
wire contract today (three of four emit nothing).

## Providers and substitutability

Transport/logging-level. A future runtime should implement one per-request id contract (inbound honoured +
response header + log correlation + consistent error-page id), request-scoped (contextvars / AsyncLocalStorage
/ fiber-local), with the inbound value sanitized.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| RID-PY-ONLY | The full request-id feature (honour inbound + emit response header + log correlation + error-page) exists ONLY in Python (`server.py:2559-2566`). PHP is process-scoped (no wire I/O); Ruby and Node are DORMANT - `set_request_id`/`setRequestId` are defined but NEVER called in the request path, so their logs never carry an id. The prior doc's "used consistently as a Log-context value and in the production error page" is unfounded for PHP/Ruby/Node. | Decide scope (RID-DEC-01): build the feature (per-request id, honour inbound, emit response header, log correlation) in PHP/Ruby/Node, or document it as Python-only and stop claiming parity. |
| RID-PY-INJECTION | SECURITY, Python: the inbound `x-request-id` is used UNSANITIZED (`server.py:2559`) straight into a response header (`:2564`) and log lines (`debug/__init__.py:589`) - an attacker-controlled header/log-injection vector (CR/LF, control chars, unbounded length). RID-03 in the prior doc was hypothetical; it is live. | Sanitize the inbound id (allow-list charset, cap length, strip CR/LF) or regenerate; never reflect a raw header. |
| RID-PY-NO-ISOLATION | Python stores the id in `threading.local` (`debug/__init__.py:115`), but dispatch is async (one OS thread runs all coroutines), so a second concurrent request's `set_request_id` overwrites the first's - the first's later log lines and response carry the WRONG id. RID-04 was hypothetical; it is live under load. | Store the request id in a `contextvars.ContextVar` (async-safe), not `threading.local`. |
| RID-PHP-PROCESS-SCOPED | PHP generates one id per PROCESS (`App.php:304` in the constructor), not per request - under the built-in server every request shares it (useless for correlation). It honours no inbound header and emits no response header. And the prod-error-page id (`Router.php:833` `md5(uniqid())[:12]`) is a fresh throwaway disconnected from the log id (and is the wrong path the prior doc cited as PHP's generation). | Generate the id per request, honour inbound, emit the response header, and use the ONE id on the error page (with RID-DEC-01). |
| RID-DORMANT-RUBY-NODE | Ruby and Node have the log-context API but never call it in the request path (`log.rb:246` / `logger.ts:372` setters have no request-path caller), so `get_request_id` is nil during real requests and logs carry no id. The only per-request id is a throwaway for the 500 page. | Wire the request path to set the id (with RID-DEC-01). |
| RID-ERRORPAGE-DISCONNECT | The prod error-page `request_id` is a freshly-generated throwaway in PHP/Ruby/Node (`Router.php:833`, `rack_app.rb:699`, `server.ts:1304`), NOT correlatable with the log context or any response header - so a user reporting the error-page id cannot be matched to logs. Only Python is consistent (same id everywhere). | Render the ONE request id on the error page in all four. |
| RID-NO-FIXTURE | No shared request-id/correlation fixture exists. | Add it once RID-DEC-01 sets the scope. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- RID-DEC-01 (proposed, THE call): decide the feature's scope. A per-request correlation id (honour inbound,
  emit response header, log correlation, consistent error-page id) is fully wired only in Python. Either build
  it in PHP/Ruby/Node (PHP needs per-request generation; Ruby/Node need the request path to actually call the
  setter), or document it as Python-only and correct the matrix/contract. The prior doc mis-stated it as
  working in all four.
- RID-DEC-02 (proposed, SECURITY + correctness, do regardless): in Python, SANITIZE the inbound
  `x-request-id` (RID-PY-INJECTION) and move storage to `contextvars` for concurrent isolation
  (RID-PY-NO-ISOLATION). Both are live defects today, not hypotheticals.

## Proposed conformance fixture

A shared fixture (real requests): a request WITHOUT `x-request-id` gets a generated id echoed in the response
header AND present in its log lines AND on its error page - the same id in all three (once RID-DEC-01 lands);
an inbound `x-request-id` is honoured but SANITIZED (a CR/LF or over-long value is rejected/trimmed, not
reflected - catches RID-PY-INJECTION); two concurrent requests keep DISTINCT ids in their logs/responses
(catches RID-PY-NO-ISOLATION).

## Integration map

- Consumers: the logger (correlation), the response builder (header), the error page. Composes: dispatch.

## Breaking changes and migration

- Building the feature in PHP/Ruby/Node adds a response header + log field a client did not previously see -
  additive, note it. Sanitizing the inbound id changes what a crafted header produces (a security fix).
  Moving Python to contextvars is a correctness fix.

## Porting capsule

A request id needs: per-REQUEST generation (never per-process - the PHP bug), honouring an inbound
`x-request-id` but SANITIZED (allow-list charset, cap length, strip CR/LF - never reflect a raw header),
request-SCOPED storage (contextvars / AsyncLocalStorage / fiber-local, never a process/thread global under an
async or threaded server), the SAME id echoed in the response header, threaded into every log line, and shown
on the error page. Prove it with a generated-id round-trip, an inbound-id sanitization, and two concurrent
requests keeping distinct ids.

## Audit closure checklist

- [x] Boundary and public surface complete (per-language wiring x four).
- [x] Lifecycle and producer/consumer edges complete (generate -> store -> emit -> log -> error page).
- [x] Configuration (none), failure and SECURITY (injection, no-isolation) rules complete.
- [x] Wire (Python-only response header) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (Python-only full; PHP process-scoped; Ruby/Node dormant) -
  correcting the prior convergence claim.
- [x] Owner ambiguities decided (RID-DEC-01 scope, RID-DEC-02 security).
- [x] Conformance fixture (round-trip + sanitization + concurrency) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
