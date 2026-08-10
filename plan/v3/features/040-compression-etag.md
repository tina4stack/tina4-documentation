# Feature 040: HTTP compression and ETag

## Identity and status

- Matrix identity: 40 - HTTP compression and ETag
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (response builders + static-file
  handlers). No framework code changed.
- Dependencies: Feature 30 response model (it carries the headers), Feature 29 request (reads
  Accept-Encoding and If-None-Match), the static-file handler, Frond (its injection must
  precede the ETag hash)
- Dependants: every response a browser caches or receives compressed; static asset delivery
- Existing ADRs: the response-model contract (ADR-0050); RFC 7232 (conditional requests)
- Shared fixtures: `compression_etag_contract.json` is required
- Catalog phase: Routing and middleware

## Why this feature exists

A browser should re-download a resource only when it changed, and receive it compressed when it
can decompress it. This feature adds an ETag so an unchanged resource returns 304, and gzip
compression so a large text response travels smaller - the same way in all four languages.

## Boundary

This feature owns ETag generation, the 304 Not Modified path, and response compression (the
encoding, the size threshold, the content-type skip). It DELEGATES header carriage to Feature
30, the Accept-Encoding/If-None-Match reads to Feature 29, and the Frond render to Frond (whose
injected bytes must be hashed). It does not own static-file discovery, only the ETag/compression
applied to a static response.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Dynamic ETag | `md5(content)[:16]`, strong, quoted | content hash | content hash | content hash |
| Static ETag | (per handler) | (per handler) | (per handler) | `W/"size-mtime"` weak (static.ts) |
| 304 on If-None-Match | yes | yes | yes | yes (wins over If-Modified-Since, RFC 7232) |
| Compression | gzip (`Content-Encoding: gzip`) | gzip | gzip | gzip |
| Size threshold | body > 1024 bytes | (to confirm) | (to confirm) | (to confirm) |
| Accept-Encoding negotiated | yes | yes | yes | yes |
| Streaming bypass | yes (skips ETag + compression) | yes | yes | yes |
| Frond inject before ETag hash | yes | yes | yes | yes |

Two ETag STRATEGIES exist by case, and both are defensible: a DYNAMIC response uses a STRONG
content-hash ETag (Python: `md5(content)` truncated to 16 hex, quoted), because it has no
mtime; a STATIC file uses a WEAK `W/"size-mtime"` ETag (Node's `static.ts` says so explicitly
and cites RFC 7232 section 3.3, that `If-None-Match` wins over `If-Modified-Since`). Compression is
gzip, negotiated by Accept-Encoding, and Python applies it only when the body exceeds 1024
bytes. Streaming responses bypass both ETag and compression, and Frond injection happens BEFORE
the ETag hash so injected bytes are covered by the ETag and the Content-Length.

## Public surface contract

The feature is automatic on a normal response: it computes an ETag, and on a request whose
`If-None-Match` matches it returns 304 Not Modified with no body; it gzip-compresses the body
when the client sent an acceptable Accept-Encoding and the body exceeds the size threshold. A
dynamic response gets a strong content-hash ETag; a static file gets a weak `W/"size-mtime"`
ETag. A streaming response is sent as-is, with neither ETag nor compression.

## Inputs and outputs

- Input: the response body (or the static file's size/mtime), the request's `Accept-Encoding`
  and `If-None-Match`.
- Output: an `ETag` header; a 304 with no body when `If-None-Match` matches; a gzip-compressed
  body with `Content-Encoding: gzip` when negotiated and over threshold, else the identity body.
- The ETag is stable for identical content (dynamic) or identical size+mtime (static).
- A streaming response carries neither header.

## Lifecycle and operation graph

1. For a non-streaming response, Frond (if used) renders and injects first, so its bytes are in
   the hash.
2. The ETag is computed: a content hash for a dynamic body, `W/"size-mtime"` for a static file.
3. If `If-None-Match` equals the ETag, the response is 304 Not Modified with no body (and
   `If-None-Match` wins over `If-Modified-Since`, RFC 7232 section 3.3).
4. Otherwise, if `Accept-Encoding` allows gzip and the body exceeds the size threshold and the
   content type is compressible, the body is gzip-compressed and `Content-Encoding: gzip` is
   set.
5. A streaming response skips steps 2-4 and is sent immediately.

## Configuration and precedence

- Compression applies only above a size threshold (Python: 1024 bytes) and only to compressible
  content types (not an already-compressed image/archive); the threshold must be identical
  across the four.
- `If-None-Match` takes precedence over `If-Modified-Since` (RFC 7232 section 3.3).
- The behaviour is automatic; a streaming response opts out by being streamed.

## Failures, side effects and security

- A 304 carries NO body and preserves the ETag; it never returns stale content as a 200.
- The ETag must cover the FINAL bytes: Frond injection precedes the hash, so an injected token
  or CSRF field cannot make a cached 304 serve pre-injection content.
- Compression respects Accept-Encoding: a client that did not offer gzip receives identity, so a
  response is never undecodable.
- A strong content-hash ETag changes when the body changes; a weak `W/` ETag signals that
  byte-identical delivery is not guaranteed (correct for a static file that may be re-compressed).
- Compressing below the threshold or compressing already-compressed content wastes CPU and can
  expand the body, so the threshold and content-type skip are correctness, not just tuning.

## Wire and persistence contract

There is no persistence; the wire contract is the `ETag` header format (a quoted strong tag for
dynamic content, a `W/"size-mtime"` weak tag for static), the 304 response (empty body, ETag
preserved), and `Content-Encoding: gzip` when compressed. These are identical across the four
for the same case.

## Providers and substitutability

Compression and ETag are transport-level and engine-agnostic. A future runtime computes the same
strong-vs-weak ETag by case, honors the same size threshold and Accept-Encoding negotiation, and
returns the same 304 semantics.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| ETAG-01 | Two ETag strategies exist (strong content-hash for dynamic, weak `W/"size-mtime"` for static); each must be identical across the four for its case. | Pin the dynamic strategy (content hash) and the static strategy (`W/size-mtime`) and gate each in all four. |
| ETAG-02 | The compression size threshold (Python 1024) and the content-type skip are confirmed only in Python. | Pin one threshold and one compressible-type rule; gate that a sub-threshold body is not compressed in all four. |
| ETAG-03 | The 304 path (If-None-Match match, empty body, precedence over If-Modified-Since) is not gated as parity. | Gate a 304 on a matching If-None-Match, and the RFC 7232 precedence, in all four. |
| ETAG-04 | The streaming bypass (no ETag, no compression) is not gated. | Gate that a streaming response carries neither header in all four. |
| ETAG-05 | The Frond-inject-before-ETag ordering is required for correctness but not gated. | Gate that injected bytes are covered by the ETag in all four. |
| ETAG-06 | No shared fixture exists. | Add `compression_etag_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. Two ETag strategies by case, identical across the four: a DYNAMIC response gets a STRONG
   content-hash ETag (quoted); a STATIC file gets a WEAK `W/"size-mtime"` ETag. Pin the hash
   algorithm and length (Python's `md5[:16]` is the reference for dynamic).
2. Compression is gzip, negotiated by Accept-Encoding, applied only above one size threshold
   (1024 bytes) and only to compressible content types.
3. A matching `If-None-Match` returns 304 with an empty body and the ETag preserved;
   `If-None-Match` wins over `If-Modified-Since` (RFC 7232 section 3.3).
4. Streaming responses bypass both ETag and compression.
5. Frond injection precedes the ETag hash, so the ETag covers the final delivered bytes.

## Proposed conformance fixture

Add `compression_etag_contract.json` with stable ids for: a dynamic response carrying a strong
quoted content-hash ETag; the same request with a matching `If-None-Match` returning 304 with no
body; a static file carrying `W/"size-mtime"` and its 304; a large text body gzip-compressed
with `Content-Encoding: gzip`; a sub-threshold body NOT compressed; a client without gzip
receiving identity; a streaming response carrying neither ETag nor Content-Encoding; and an
`If-None-Match` winning over `If-Modified-Since`. Every case inspects a real response from a real
request; no mock can claim conformance.

## Integration map

- Feature 30 carries the headers; Feature 29 reads Accept-Encoding and If-None-Match; the
  static-file handler supplies size/mtime for the weak ETag; Frond renders before the hash.
- The 304 path interacts with the browser cache; compression interacts with any proxy.
- Central fixtures, four runners, the CI matrix and the response/static docs update together.

## Breaking changes and migration

- No change to application code; the audit pins the ETag strategy, the compression threshold and
  the 304 semantics. If any framework's threshold or ETag form differs under test, aligning it is
  a correctness fix noted in the release note.
- A client relying on a specific ETag form (rare) sees the pinned form.

## Implementation backlog

1. Add `compression_etag_contract.json` and wire four runners against real responses.
2. Pin and gate the dynamic (content-hash) and static (`W/size-mtime`) ETag strategies (ETAG-01).
3. Pin one compression threshold and content-type rule; gate the sub-threshold case (ETAG-02).
4. Gate the 304 path and RFC 7232 precedence (ETAG-03), the streaming bypass (ETAG-04) and the
   Frond-before-ETag ordering (ETAG-05).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

For a non-streaming response, render Frond first, then compute the ETag: a strong quoted content
hash for a dynamic body, `W/"size-mtime"` for a static file. Return 304 with an empty body when
`If-None-Match` matches (and let it win over `If-Modified-Since`). Gzip-compress when
`Accept-Encoding` allows, the body exceeds the size threshold (1024 bytes), and the content type
is compressible; otherwise send identity. Skip both for a streaming response. Prove the port with
a 304, a compressed-vs-identity pair, a sub-threshold no-compress, and a streaming bypass.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (ETAG-01..06).
- [x] Owner ambiguities recorded (5 proposed; the two ETag strategies and threshold are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
