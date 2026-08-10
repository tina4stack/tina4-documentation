# Feature 081: Standard-library HTTP API client

## Identity and status

- Matrix identity: 81 - Standard-library HTTP API client
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the `Api` class in each repo, plus the
  real-socket transfer tests) at Python `386cd6d`, PHP (Api.php unchanged from v3; read at `98b878e1`),
  Ruby `c61250c8`, Node `26be920`. The capability set was built Python-master-first and committed
  (per `plan/v3/api-client-gaps.md`); this audit confirms the current source and pins the remaining
  divergences. No framework code changed.
- Dependencies: the language stdlib HTTP transport (urllib / stream wrapper / Net::HTTP / node:http)
- Dependants: any app or framework subsystem making an outbound HTTP call (webhooks, OAuth, service-
  to-service, the realtime ICE/TURN fetch)
- Existing ADRs: ADR-0012 (settle a contract against real-world frameworks - the `send_request`
  rename and the Guzzle-gap set derive from it); the redirect-strip is a security fix, not an ADR
- Shared fixtures: NONE. `api_contract.json` is owed (CONTRACT-MAP records "No fixture yet"); the
  capabilities are proven per-framework by real no-mock tests, not by one shared oracle (AC-03).
- Catalog phase: HTTP client

## Why this feature exists

An application needs to call other HTTP services without a heavy dependency. The `Api` client is a
deliberate ZERO-DEPENDENCY client (Python urllib, PHP stream wrapper, Ruby Net::HTTP, Node node:http)
that GETs/POSTs, uploads and downloads, follows redirects SAFELY (never leaking a bearer token to a
different origin), retries transient failures, and can be swapped for a test transport - the same way
in every language.

## Boundary

This feature owns the `Api` client: the constructor options, the verbs (`get`/`post`/`put`/`patch`/
`delete`/`send_request`), `upload`/`download`, the auth setters, the redirect-safety, the retry, the
cookie jar, the transport seam, and the SSL policy. It DELEGATES the actual bytes to the language
stdlib transport. It is a CLIENT; the server side (routing, the request/response objects) is elsewhere.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Transport (zero-dep) | urllib | stream wrapper (no ext-curl) | Net::HTTP | node:http/https |
| Result shape | dict `{http_code, body, headers, error}` | array `{http_code, ...}` | OBJECT `.status/.body/.headers/.error` | object `{http_code, ...}` |
| `download` shape (no body) | `{http_code, headers, error, path}` | same | `.path`, body nil | same |
| Redirect cross-origin auth/cookie strip | yes | yes (follow_location=0 loop) | yes (10-hop loop) | yes (10-hop loop) |
| `send_request` unified | yes | yes | yes | yes |
| Retry opt-in (429/5xx, 4xx never) | yes | yes | yes | yes |
| Cookie jar opt-in | yes | yes | yes | yes |
| Transport seam (real-alt in own suite) | yes | yes | yes | yes |
| `upload` disk + bytes, clean error | yes | yes | yes | yes |
| `download` 64KB stream, no-file-on-error | yes | yes | yes | yes |
| SSL verify-on default | yes | yes | yes | yes |
| `auth_header` option | yes | yes | NO | yes |
| `ignore_ssl` option | yes | yes | NO (uses verify_ssl) | yes |
| `setIgnoreSsl` method | no | no | no | YES (deliberate Node-only) |
| Reads env vars | none | none | none | none |

The capability set is uniform and proven. The security-critical redirect strip is present in all four
with real two-origin socket tests. The divergences are Ruby's result shape and two missing Ruby
options; the `setIgnoreSsl` method is a deliberate Node-only asymmetry.

## Public surface contract

Constructor options (canonical, Python master): `base_url`, `auth_header`, `timeout` (30s),
`ignore_ssl`, `bearer_token`, `username`, `password`, `headers`, `verify_ssl`, `max_retries` (0),
`retry_backoff` (0.5s), `transport` (None = real network), `cookies` (False). Verbs return a result
carrying `http_code`, `body`, `headers`, `error`; `download` returns `http_code`, `headers`, `error`,
`path` (no body). `send_request(method, path, body, content_type)` is the shared generic entry point
(the `send` name was reverted because Ruby reserves `Object#send`). `upload(path, file_path=/
file_bytes+filename, field_name, extra_fields, headers)` and `download(path, dest_path)` complete the
transfer surface. `add_headers`, `set_basic_auth`, `set_bearer_token` are the mutators.

## Inputs and outputs

- A result is `{http_code, body, headers, error}` (Python dict, PHP array, Node object) or an
  `APIResponse` OBJECT exposing `.status/.body/.headers/.error` (Ruby - AC-01). `http_code`/`.status`
  is null/0 on a transport failure with `error` set.
- `download` writes the body to disk and returns `path` (null on error, and no file is written);
  `upload` accepts a disk path or in-memory bytes and returns a clean error result on a missing file
  (never raising).
- A redirect result reflects the FINAL hop; the `Authorization` and `Cookie` headers are dropped when
  the hop crosses origin.

## Lifecycle and operation graph

1. BUILD: the constructor stores the options (no env reads); auth setters mutate the default headers.
2. REQUEST: a verb builds the URL and headers (adding the cookie jar's `Cookie` if enabled), then
   dispatches through the transport seam (if injected) or the real stdlib transport.
3. REDIRECT: a 3xx is followed MANUALLY up to ~10 hops; on a cross-origin hop the `Authorization` and
   `Cookie` headers are stripped before the next request; 301/302/303 downgrade a non-GET to GET.
4. RETRY: a transport error or a 429/5xx is retried up to `max_retries` with exponential backoff; a
   4xx (except 429) returns at once.
5. RESULT: the response is parsed and returned as the result shape; `Set-Cookie` is stored if the jar
   is enabled.

## Configuration and precedence

Everything is constructor/setter driven; NO framework reads an environment variable for the `Api`
client in any language (a deliberate design - a webhook's timeout or a target's SSL policy belongs to
the caller, not a global env). `ignore_ssl` wins over `verify_ssl` when both are set; `verify_ssl`
defaults to on.

## Failures, side effects and security

- CROSS-ORIGIN TOKEN LEAK (the security core): a redirect to a DIFFERENT origin (scheme/host/port)
  drops the `Authorization` and `Cookie` headers, so a bearer token or a session cookie never reaches
  a host the caller did not authenticate to; same-origin redirects keep them. This is UNIFORM in all
  four and PROVEN by real two-origin socket tests. It is a SECURITY FIX: PHP's stream wrapper was
  empirically forwarding both headers cross-origin before the manual-redirect-loop fix (the historical
  leak), and the other three followed Python's lead. This belongs in the release notes as a security
  fix (AC-04).
- REDIRECTS are BOUNDED (~10 hops) so a redirect loop cannot spin forever.
- RETRY is opt-in and never retries a 4xx (except 429), so a non-idempotent request is not silently
  re-sent unless the caller opts in.
- THE TRANSPORT SEAM is for APPLICATION unit tests; Tina4's own suite NEVER injects a canned fake (the
  seam tests inject a transport that performs REAL socket I/O) - the no-mock rule holds.
- SSL verification is ON by default; disabling it is an explicit opt-in.
- `upload`/`download` fail gracefully (a missing file or a download error returns a clean result, never
  raises and never leaves a half-written file).

## Wire and persistence contract

There is no persistence. The cookie jar is per-instance and in-memory (not written to disk). The wire
contract is the result shape (`http_code`/`body`/`headers`/`error`, plus `path` for download) - which
Ruby exposes as an object with `.status` rather than an `http_code` field (AC-01).

## Providers and substitutability

The transport is pluggable via the `transport` seam (a callable `(method, url, headers, body,
timeout) -> result`), defaulting to the real stdlib transport. This lets an application unit-test code
that calls an `Api` without the network, without Tina4 shipping a mock.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| AC-01 | Ruby returns an `APIResponse` OBJECT exposing `.status`; Python (dict), PHP (array) and Node (object) expose `http_code`. Ruby is the field-name outlier (`.status` vs `http_code`), and `http_code` in Ruby is only an accepted transport-seam INPUT key. | Ruby's result exposes `http_code` as the primary reader (rename `.status`, per the no-aliases rule) so the cross-language result field name matches. An idiomatic object is fine; the FIELD NAME must be `http_code`. |
| AC-02 | Ruby lacks the `auth_header` and `ignore_ssl` constructor options that Python/PHP/Node have (Ruby offers `verify_ssl` and `bearer_token`/`username`). | Add `auth_header` and `ignore_ssl` to Ruby's constructor (mapping `ignore_ssl` onto the existing `verify_ssl` logic) so the option surface matches the other three. |
| AC-03 | There is NO `api_contract.json`; the capabilities are proven per-framework by real no-mock tests but not by one shared oracle. | Add `api_contract.json` (or an executable cross-language contract) so the result shape, redirect strip, retry, cookie jar, upload/download and transport seam are gated identically in all four. |
| AC-04 | The redirect cross-origin auth/cookie strip is a SECURITY FIX (PHP was leaking) and Ruby's `upload()` was renamed (`file_path:` keyword), but no release note records either. | Add release notes: the redirect security fix (all four, PHP was leaking) and the breaking Ruby `upload()` signature change. |
| AC-05 | Over an INJECTED transport seam, `download` buffers the body rather than streaming (Ruby, Node) - the real network path streams; the seam path cannot. | Document the seam-download buffering, or stream through the seam; low-severity (the seam is a test aid). |

The `setIgnoreSsl` method is NOT a defect - it is a deliberate, documented Node-only asymmetry
(ratified). No env-var read in any framework is deliberate parity, not a gap.

## Owner decisions

Proposed for owner ratification:

1. RUBY RESULT FIELD NAME (AC-01): Ruby's result exposes `http_code` (rename `.status`), matching the
   three-majority and Python master; an idiomatic object wrapper is fine, but the field name is the
   cross-language contract.
2. RUBY OPTION SURFACE (AC-02): add `auth_header` and `ignore_ssl` to Ruby's constructor so the option
   set matches the other three (map `ignore_ssl` onto `verify_ssl`).
3. SHARED FIXTURE (AC-03): add `api_contract.json` so the client contract is one oracle, not four
   per-framework test suites.
4. RELEASE NOTES (AC-04): record the redirect security fix (all four; PHP was leaking) and the breaking
   Ruby `upload()` rename.

`send_request` (unified 2026-08-07) and the `setIgnoreSsl` Node-only asymmetry are already ratified -
no re-decision.

## Proposed conformance fixture

Add `api_contract.json` driving four runners against REAL local servers (no doubles - as the existing
per-framework transfer tests already do): a verb returns `{http_code, body, headers, error}` (Ruby's
object exposes `http_code`); a cross-origin 302 drops `Authorization` AND `Cookie`, a same-origin 302
keeps them; a 4xx is not retried and a 429/5xx is (opt-in); the cookie jar replays `Set-Cookie` and
does nothing when off; `upload` posts real bytes from disk and from memory and errors cleanly on a
missing file; `download` streams a multi-MB body to disk and writes no file on an error; and the
transport seam fully replaces the network with a REAL alternate transport.

## Integration map

- The realtime ICE/TURN fetch, webhooks, and any service-to-service call use this client.
- `api_contract.json` (owed) is the shared oracle; the per-framework transfer tests already prove the
  capabilities.
- The `Api` docs in each CLAUDE.md and the book chapter describe the surface; they must record the
  redirect security behaviour and the Ruby signature change (AC-04).

## Breaking changes and migration

- AC-01 renames Ruby's result reader from `.status` to `.http_code`: a Ruby app reading `resp.status`
  updates to `resp.http_code`. `Breaking:` for Ruby.
- AC-02 adds options to Ruby (additive) - no break.
- The Ruby `upload()` `file_path:` keyword rename already landed (breaking); it needs the release note
  (AC-04).

## Implementation backlog

1. Add `api_contract.json` and wire four runners against real servers (AC-03).
2. Ruby: expose `http_code` on the result (AC-01); add `auth_header`/`ignore_ssl` options (AC-02).
3. Write the release notes for the redirect security fix and the Ruby signature change (AC-04).
4. Document (or fix) the seam-download buffering (AC-05).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a zero-dependency HTTP client on the language stdlib transport. Constructor options:
`base_url`, `auth_header`, `timeout` (30s), `ignore_ssl`, `bearer_token`, `username`/`password`,
`headers`, `verify_ssl`, `max_retries` (0), `retry_backoff` (0.5s), `transport` (None=real), `cookies`
(False) - and NO env reads. Verbs return `{http_code, body, headers, error}` (an idiomatic object is
fine but the field is `http_code`); `download` returns `path` (no body). Follow redirects MANUALLY up
to ~10 hops, stripping `Authorization` and `Cookie` on any cross-origin hop (the security rule). Retry
transport errors and 429/5xx (never other 4xx) with exponential backoff. Provide `upload` (disk or
bytes, clean error on a missing file), a 64KB streaming `download` (no file on error), an opt-in cookie
jar, an injectable transport seam (never a mock in the framework's own suite), and verify-on SSL.
Prove the port with `api_contract.json`: result shape, cross-origin strip, retry, cookie jar,
upload/download, transport seam - all over real sockets.

## Audit closure checklist

- [x] Boundary and public surface complete (options, verbs, upload/download, seam, redirect).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (cross-origin strip, retry, SSL).
- [x] Wire/storage and provider contracts complete (result shape, transport seam).
- [x] Existing-language contradictions recorded (AC-01..05; the redirect strip is UNIFORM + proven).
- [x] Owner ambiguities recorded (4 proposed; the Ruby result field name and the shared fixture are key).
- [x] Proposed shared cases and mutation witnesses complete (`api_contract.json` over real servers).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
