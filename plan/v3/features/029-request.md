# Feature 029: HTTP request model

## Identity and status

- Matrix identity: 29 - HTTP request model
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (PHP `Request.php`, Python
  `core/request.py`, Ruby `request.rb`, Node `request.ts`). No framework code changed.
- Dependencies: the router (constructs the Request from the socket), Feature 30 response model
  (the request/response pair), the trusted-proxy rule (for the forwarded-proto/client-IP reads)
- Dependants: every route handler and middleware reads the Request; validation (Feature 19)
  reads the body; AutoCrud reads params
- Existing ADRs: ADR-0049 (canonical client IP / trusted-proxy keying) governs the
  forwarded-header reads
- Shared fixtures: `request_contract.json` is required

## Why this feature exists

Every route handler and middleware reads one Request object for the method, path, route params,
query string, headers, body, cookies and uploaded files. That object must expose the same
surface with the same semantics in all four languages, so a handler ported between them reads
the same value from the same accessor.

## Boundary

This feature owns the Request object and its accessors: `method`, `path`, `query` (query-string
params), `params` (route params), `headers` (case-insensitive), `body`, `cookies`, `files`, and
the `input(key, default)` value accessor. It DELEGATES construction to the router, the
forwarded-header/client-IP interpretation to ADR-0049, and the response to Feature 30. It does
NOT own routing itself.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `method` | yes | `readonly` | yes | yes |
| `path` | yes | `readonly` | yes | yes |
| Route params accessor | `params` (MERGED with query) | `params` (route only) | `path_params` | `params` |
| Query-string accessor | `query` (query only) | `query` (query only) | `query_string` | `query` |
| `headers` | `CaseInsensitiveDict` (+ `-`->`_`) | `CaseInsensitiveArray` | `attr_reader` | headers object |
| `body` | pre-parsed (dict/str/None) | pre-parsed (mixed) | `json_body` (on demand) | raw `Buffer` (parsed elsewhere) |
| `cookies` / `files` | yes / yes | yes / yes | yes | yes / yes |
| `input(key, default)` | yes | yes | (unconfirmed) | (unconfirmed) |
| Immutability | mutable attrs | `readonly` except `params` | attr_reader | const-scoped |

All four expose method, path, query, headers, body, cookies and files, but three semantics
diverge. First, `params`: PHP keeps route params in `params` and query params in `query`, while
Python MERGES query and route params into `params` (its docstring says so), so
`request.params["id"]` returns route-only in PHP and query-or-route in Python, and the two
disagree when a query key and a route key collide. Ruby names the route accessor `path_params`.
Second, header access is case-insensitive everywhere, but Python additionally normalizes `-` to
`_`, which the others do not. Third, the body is eagerly parsed in Python and PHP, exposed raw
as a `Buffer` in Node, and parsed on demand via `json_body` in Ruby. PHP additionally makes most
of the Request `readonly`; Python's attributes are mutable.

## Public surface contract

The Request exposes: `method` (the HTTP verb), `path` (the URL path), `query` (query-string
params), `params` (route params), `headers` (case-insensitive), `body` (the parsed request
body), `cookies`, `files` (uploads), and `input(key, default)` which returns a value by key. The
accessor names follow each language's convention; the SEMANTICS are the same: `params` is route
params, `query` is query-string params, and `input()` resolves a value with one documented
precedence.

## Inputs and outputs

- Input: the raw HTTP request from the socket (constructed by the router).
- Output: typed accessors -- `method`/`path` as strings, `query`/`params`/`cookies` as maps,
  `headers` as a case-insensitive map, `body` as the parsed body, `files` as uploaded-file
  descriptors.
- `input(key, default)` returns the value for `key` with a documented precedence (route param,
  then query, or the reverse -- pinned below) and the default when absent.
- Header lookup is case-insensitive; whether a dash is also normalized to an underscore is
  pinned below.

## Lifecycle and operation graph

1. The router parses the socket into a Request: method, path, query string, headers, cookies,
   body and any multipart files.
2. Route matching populates the route params (`params`/`path_params`).
3. A handler or middleware reads the accessors; `input(key, default)` resolves a single value.
4. The body is available parsed (by content type) through one contract; a forwarded-proto or
   client-IP read follows ADR-0049.

## Configuration and precedence

- `input(key, default)` has ONE precedence across the four (route param, then query, then
  default -- or the pinned order), so the same key resolves the same way everywhere.
- Header access is case-insensitive; the dash-to-underscore normalization is either applied in
  all four or none.
- The trusted-proxy configuration (ADR-0049) governs the forwarded-header reads.

## Failures, side effects and security

- The Request is READ-ONLY to a handler except for framework-set route params; a handler must
  not be able to mutate `method`, `headers` or `body` and have that leak to another consumer.
  PHP's `readonly` is the reference; the others match its immutability.
- A malformed body does not crash the accessor: `body` is the parsed value or a documented
  empty/None, and validation (Feature 19) reports a bad body rather than the accessor raising.
- Forwarded headers (`X-Forwarded-Proto`, client IP) are trusted only per ADR-0049, never
  blindly, so a spoofed header cannot elevate a request.
- File uploads expose size and type so a handler can bound them; the request does not load an
  unbounded upload into memory silently.

## Wire and persistence contract

There is no persistence; the wire input is the HTTP request and the contract is the accessor
SEMANTICS: `params` is route params, `query` is query-string params, `headers` is
case-insensitive, and `body` is parsed by content type. The same raw request yields the same
accessor values in all four.

## Providers and substitutability

The Request is transport-level and engine-agnostic. A future runtime constructs the same
surface from its own server, with the same `params`/`query` split, the same case-insensitive
headers and the same `input()` precedence.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| REQ-01 | `params` diverges: PHP is route-only (query in `query`), Python MERGES query+route into `params`. `request.params["id"]` disagrees when a query key and a route key collide. | Pin `params` = route params only, `query` = query-string params, in all four; a merged view is `input()` with a documented precedence. |
| REQ-02 | The route-params accessor is spelled `params` (Python/PHP/Node) vs `path_params` (Ruby). | One spelling per language convention, one SEMANTIC; gate that route params read the same. |
| REQ-03 | Header access is case-insensitive everywhere, but Python also normalizes `-` to `_`; the others do not. | Pin one header normalization rule (case-insensitive; dash-to-underscore in all four or none). |
| REQ-04 | The body is pre-parsed (Python/PHP), raw `Buffer` (Node), or on-demand `json_body` (Ruby). A handler reading `body` gets different things. | Pin one body contract: parsed by content type through the same accessor in all four. |
| REQ-05 | `input(key, default)` is confirmed in Python/PHP; its presence and precedence in Ruby/Node is unconfirmed. | Provide `input(key, default)` with one precedence in all four. |
| REQ-06 | Request immutability diverges (PHP `readonly`, Python mutable). | Make the Request read-only to a handler (except framework-set route params) in all four. |
| REQ-07 | No shared fixture exists. | Add `request_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. `params` is ROUTE params only and `query` is query-string params, in all four (Python stops
   merging). A merged lookup is `input(key, default)` with a documented precedence (route param,
   then query, then default).
2. Headers are case-insensitive; pin the dash-to-underscore rule one way for all four
   (recommend case-insensitive only, no dash normalization, to match HTTP header conventions).
3. The body is parsed by content type through one accessor in all four; the raw bytes remain
   available for a handler that needs them.
4. `input(key, default)` exists in all four with the same precedence.
5. The Request is read-only to a handler except framework-set route params (PHP `readonly` is
   the reference); a handler cannot mutate `method`/`headers`/`body` for another consumer.
6. Forwarded-header and client-IP reads follow ADR-0049; nothing is trusted blindly.

## Proposed conformance fixture

Add `request_contract.json` with stable ids for: `method`/`path` reads; `query` vs `params`
with a colliding key (proving route-only params and query-only query); `input(key, default)`
precedence and the default on absence; case-insensitive header lookup (and the pinned
dash-rule); a parsed body by content type (JSON, form, empty); cookies and a multipart file
upload with size/type; and an attempt to mutate `method`/`headers` failing. Every case uses a
real HTTP request over a real socket; no mock request can claim conformance (the audit already
converted mock requests to real ones in the test suites).

## Integration map

- The router constructs the Request and populates route params; middleware and handlers read
  it; Feature 30 is the paired response; Feature 19 validates the body.
- ADR-0049 governs the forwarded-proto and client-IP reads.
- Central fixtures, four runners, the CI matrix, release notes and the routing/request docs
  update together.

## Breaking changes and migration

- Python's `params` stops merging query params; a handler that read a query value from `params`
  reads it from `query` or `input()` instead. `Breaking:` entry with the migration.
- Ruby's route accessor and the body contract align; a handler using `json_body` keeps a parsed
  body through the unified accessor.
- Making the Request read-only is breaking for any handler that mutated it (rare, and the
  mutation never safely propagated anyway).

## Implementation backlog

1. Add `request_contract.json` and wire four runners against real sockets.
2. Pin `params`=route / `query`=query and stop Python's merge (REQ-01); gate the colliding-key
   case.
3. Unify the header normalization (REQ-03), the body contract (REQ-04) and `input()` (REQ-05).
4. Make the Request read-only except route params (REQ-06).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Construct a Request exposing `method`, `path`, `query` (query-string params), `params` (route
params, NOT merged with query), case-insensitive `headers`, a `body` parsed by content type,
`cookies`, `files`, and `input(key, default)` with a documented precedence. Make it read-only to
a handler except framework-set route params. Read forwarded headers only per ADR-0049. Prove the
port against real HTTP requests, especially the query-vs-route colliding-key case and the
case-insensitive header lookup.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (REQ-01..07).
- [x] Owner ambiguities recorded (6 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
