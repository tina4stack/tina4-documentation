# Feature 043: Request ID tracking

## Identity and status

- Matrix identity: 43 - Request ID tracking
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (server request-id generation, the
  Log context, and the error-page use). No framework code changed.
- Dependencies: Feature 29 request (an incoming `X-Request-ID`), Feature 30 response (emits it),
  the Log subsystem (carries it on every line), Feature 42 error pages (shows it in production)
- Dependants: every log line, the production error page, any downstream service correlating by
  request id
- Existing ADRs: the response-model contract (ADR-0050)
- Shared fixtures: `request_id_contract.json` is required
- Catalog phase: Routing and middleware

## Why this feature exists

When something goes wrong, an operator needs to find every log line for the one request that
failed. A request id gives each request a unique tag that appears on its logs, in its response
header, and on its production error page - the same way in all four languages, and correlatable
across services.

## Boundary

This feature owns the request id: its generation, the honoring of an incoming `X-Request-ID`,
its storage in a request-scoped context, its propagation onto every log line, and its emission
in the response header. It DELEGATES the incoming header read to Feature 29, the response header
to Feature 30, the log formatting to the Log subsystem, and the production error-page display to
Feature 42.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Generation | `uuid4()[:8]` (8 hex) | `md5(uniqid())[:12]` (12 hex) | (to confirm) | (to confirm) |
| Honors incoming `X-Request-ID` | YES (`headers.get("x-request-id", ...)`) | NO (always generates) | (to confirm) | (to confirm) |
| Emits `X-Request-ID` in response | YES (`response.header("x-request-id", ...)`) | (to confirm) | (to confirm) | (to confirm) |
| On the Log context | `set_request_id` / `Log.getRequestId` | `Log::getRequestId` | yes | yes |
| In the production error page | yes (500.twig `request_id`) | yes (`request_id`) | yes | yes |
| Storage isolation | request-scoped (to confirm contextvars) | per-request | (to confirm) | (to confirm AsyncLocalStorage) |

The request id is used consistently as a Log-context value and in the production error page (the
Feature 42 tie), but the GENERATION and the INCOMING-HEADER handling diverge. Python honors an
incoming `x-request-id` (so a proxy or an upstream service can propagate a trace id) and falls
back to an 8-hex `uuid4` prefix, then emits it in the response. PHP always generates a 12-hex
`md5(uniqid())` and does not appear to read an incoming header. So the id FORMAT differs (8 vs 12
hex, uuid vs md5) and only Python currently supports cross-service correlation.

## Public surface contract

Each request gets an id: an incoming `X-Request-ID` (sanitized) if present, else a generated one.
The id is stored in a request-scoped context so every log line for that request carries it, and
it is emitted in the response `X-Request-ID` header so a client can report it. A production error
page shows the id (Feature 42). The id format is one value across the four.

## Inputs and outputs

- Input: the request's `X-Request-ID` header (optional) and a generator.
- Output: the id on the Log context, in the response `X-Request-ID` header, and in the
  production error body.
- An incoming id is honored for correlation but SANITIZED (length-capped, control characters
  stripped) before it reaches a log line or a header.
- The id is unique per request and isolated between concurrent requests.

## Lifecycle and operation graph

1. At the start of a request, the server reads `X-Request-ID`; if present and valid it is used
   (after sanitization), else a new id is generated.
2. The id is stored in a REQUEST-SCOPED context (contextvars in Python, AsyncLocalStorage in
   Node, a thread/fiber-local in Ruby, per-request state in PHP) so a concurrent request cannot
   read or overwrite it.
3. Every log line emitted during the request carries the id.
4. The response sets `X-Request-ID` to the id.
5. On a production error, the error page shows the id for log correlation (Feature 42).

## Configuration and precedence

- An incoming, valid `X-Request-ID` takes precedence over generation; otherwise the id is
  generated.
- The id format is fixed (one algorithm and length across the four).
- There is no per-request configuration beyond the incoming header.

## Failures, side effects and security

- LOG INJECTION: an incoming `X-Request-ID` is attacker-controlled, so it MUST be sanitized
  (capped to a fixed max length, control characters and newlines stripped) before it reaches a
  log line or a response header; an unsanitized id could forge log entries or split headers.
- CONCURRENCY: the id must be request-scoped, never a process global; a global would leak one
  request's id onto another's logs under concurrency, which is both a correctness and a
  confidentiality bug.
- The id is opaque and non-sensitive; it must not encode user identity or a secret.
- Generation must not collide within a realistic window (a uuid or a sufficiently long random
  hash), so two concurrent requests get distinct ids.

## Wire and persistence contract

There is no persistence; the wire contract is the response `X-Request-ID` header and the id's
appearance on every log line and on the production error page. The id format (one algorithm and
length) is identical across the four, and an incoming id round-trips (sanitized) so a caller sees
the id it sent.

## Providers and substitutability

Request-id tracking is transport-level and engine-agnostic. A future runtime honors an incoming
`X-Request-ID` (sanitized), generates the same id format otherwise, stores it request-scoped,
propagates it to logs, and emits it in the response.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| RID-01 | The id format diverges (Python `uuid4()[:8]`, PHP `md5(uniqid())[:12]`). | Pin ONE format and length across the four (recommend a uuid or a fixed-length random hex). |
| RID-02 | Only Python honors an incoming `X-Request-ID`; PHP always generates. Cross-service correlation works in one language. | Decide and unify: honor an incoming `X-Request-ID` (sanitized) in all four, else generate. |
| RID-03 | An incoming id is attacker-controlled; sanitization (length cap, control-char strip) is not proven. | Gate that an incoming id with a newline or over-length is sanitized before it reaches a log line or header, in all four. |
| RID-04 | The request-scoped storage (contextvars/AsyncLocalStorage/thread-local) is not proven isolated under concurrency. | Gate that two concurrent requests get distinct ids with no cross-leak, in all four. |
| RID-05 | Response emission (`X-Request-ID`) and log propagation are converged in intent but not gated. | Gate that the id appears in the response header and on a log line, in all four. |
| RID-06 | No shared fixture exists. | Add `request_id_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. One id format across the four (a uuid or a fixed-length random hex); pin the algorithm and
   length so log tooling parses one shape.
2. An incoming `X-Request-ID` is honored in all four for cross-service correlation, SANITIZED
   first (length-capped, control characters and newlines stripped); otherwise the id is
   generated.
3. The id is stored REQUEST-SCOPED (contextvars/AsyncLocalStorage/thread-local/per-request),
   never a process global, so concurrent requests never cross-leak.
4. The id is emitted in the response `X-Request-ID` header and appears on every log line for the
   request.
5. The production error page shows the id (Feature 42); the id is opaque and encodes no secret
   or identity.

## Proposed conformance fixture

Add `request_id_contract.json` with stable ids for: a request without `X-Request-ID` getting a
generated id in the response header and on a log line; a request WITH a valid `X-Request-ID`
having it honored and round-tripped; an incoming id with a newline or over-length being
SANITIZED (no log-line split, no header injection); two CONCURRENT requests getting distinct ids
with no cross-leak; and a production error page carrying the id. Every case runs a real request
through the real server and inspects real log output; no mock can claim conformance (the
concurrency isolation must be proven with real concurrent requests).

## Integration map

- Feature 29 reads the incoming header; Feature 30 emits it; the Log subsystem carries it;
  Feature 42 displays it on the production error page.
- Downstream services correlate by the emitted `X-Request-ID`; a proxy may set it upstream.
- Central fixtures, four runners, the CI matrix and the logging/observability docs update
  together.

## Breaking changes and migration

- Unifying the id format changes the shape a log parser sees; state it in the release note.
- Honoring an incoming `X-Request-ID` where a language ignored it enables correlation; it is
  additive but changes the emitted id when a caller supplies one.
- Sanitizing an incoming id is a security fix, not a breaking change for a well-behaved caller.

## Implementation backlog

1. Add `request_id_contract.json` and wire four runners against real requests and log output.
2. Pin the id format (RID-01) and unify incoming-header honoring with sanitization (RID-02,
   RID-03) in all four.
3. Gate request-scoped isolation under concurrency (RID-04) and response/log propagation
   (RID-05).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

At request start, read `X-Request-ID`; if present, sanitize it (cap length, strip control
characters and newlines) and use it; otherwise generate the pinned id format. Store it in a
request-scoped context (contextvars/AsyncLocalStorage/thread-local/per-request), never a global.
Carry it on every log line for the request, emit it in the response `X-Request-ID` header, and
show it on the production error page. Prove the port with a generated-id round-trip, an incoming
sanitized id, two concurrent requests with distinct ids, and the id on a log line.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (RID-01..06).
- [x] Owner ambiguities recorded (5 proposed; format, incoming-header and concurrency are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
