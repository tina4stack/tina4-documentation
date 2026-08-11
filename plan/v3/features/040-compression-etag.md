# Feature 40: HTTP compression and ETag

## Identity and status

- Matrix identity: 40 - HTTP compression and ETag
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language source (correcting a prior-session doc that
  asserted gzip + a dynamic content-hash ETag in ALL FOUR - the source shows both are PYTHON-ONLY).
  Python `core/response.py:474` `build_headers` + `core/server.py:2813` conditional path (`ebbab30`); PHP
  `Tina4/StaticFiles.php:153` (static ETag only) (`6faabac5`); Ruby `lib/tina4/rack_app.rb:237` (static ETag
  only) (`6d5b1de`); Node `packages/core/src/static.ts:62` (static ETag only) (`27cf0f4`).
- Dependencies: the response builder, the static-file handler (41), the request headers.
- Dependants: every response (compression); conditional GET / caching clients.
- Existing ADRs: none dedicated.

- Catalog phase: Routing and middleware

## Why this feature exists

A response should compress on the wire when the client accepts it, and a cacheable response should carry a
validator (ETag / Last-Modified) so a client can revalidate with a cheap 304 instead of re-downloading. The
audit question is parity: is this the SAME feature in all four? It is not. Compression and the dynamic ETag
live only in Python; the other three ship a static-file conditional-GET handler whose ETag format agrees in
none of the four.

## Existing implementation evidence

This is NOT a four-language feature. Measured:

- COMPRESSION - PYTHON ONLY. `response.py:474-486` gzip-compresses when `len(content) > 1024` AND `"gzip" in
  Accept-Encoding` AND the content type is compressible (`text/`, `application/json`, `application/xml`,
  `application/javascript`, `image/svg`; `response.py:522-528`), `compresslevel=6`, sets
  `Content-Encoding: gzip` + `Vary: Accept-Encoding`. On by default, no env toggle. PHP/Ruby/Node have NO
  compression primitive anywhere (`gzencode`/`Zlib`/`zlib`/`createGzip` absent from all three trees).
- DYNAMIC ETAG - PYTHON ONLY. `response.py:488-491` sets a STRONG quoted md5 tag `"<hex16>"` on every 200
  with content, via the single `build_headers` path (`server.py:2816`), so a Python static file also gets
  this strong content-hash tag. Conditional GET (304) on a DYNAMIC response exists only in Python
  (`server.py:2813-2826`). PHP/Ruby/Node put NO ETag on a dynamic response and can never 304 one.
- STATIC ETAG - all four, but the FORMAT diverges four ways: Python strong md5 `"<hex16>"` (content hash);
  PHP `W/"<mtime_dec>-<size_dec>"` (`StaticFiles.php:153`); Ruby `W/"<mtime_hex>-<size_hex>"`
  (`rack_app.rb:237`); Node `W/"<size_dec>-<mtimeMs>"` (`static.ts:62`, reversed order + fractional ms).
- The If-None-Match-over-If-Modified-Since precedence (RFC 9110) IS correct wherever a conditional path
  exists (all four static handlers + Python dynamic).

## Public surface contract

Transparent: a handler returns content; the framework (in Python) may compress it and attach an ETag, and
answers a matching conditional request with 304. In PHP/Ruby/Node only static files carry a validator. There
is no public API and no env var.

## Inputs and outputs

- Input: the response body + `Accept-Encoding`/`If-None-Match`/`If-Modified-Since` request headers.
- Output (Python): possibly gzip-compressed body + `Content-Encoding`/`Vary`, a strong ETag, and a 304 on a
  match. Output (PHP/Ruby/Node): an uncompressed body; a weak static ETag only for static files.

## Lifecycle and operation graph

1. Python: build response -> (Frond/feedback injection) -> gzip if eligible -> md5 ETag over the FINAL
   (compressed) bytes -> if `If-None-Match` matches, send 304.
2. PHP/Ruby/Node dynamic: build response -> send (no compression, no ETag).
3. PHP/Ruby/Node static: stat the file -> weak `W/"..."` ETag + Last-Modified -> 304 on a match.

## Configuration and precedence

- No env var in any language. Python compression is unconditional-on (no disable). The conditional-GET
  precedence is INM over IMS wherever implemented.

## Failures, side effects and security

- Compressing a response changes its bytes and its ETag (Python hashes the COMPRESSED body, so identity vs
  gzip carry different validators for the same resource - see the register). No security surface of its own;
  a `Vary: Accept-Encoding` is correctly set so a shared cache does not serve gzip to an identity-only client.
- A 304 must carry the validator so an intermediary cache can refresh freshness; Python's 304 does not (see
  the register).

## Wire and persistence contract

The wire outputs: (Python) `Content-Encoding: gzip` + `Vary` when compressed, a strong quoted ETag, a 304
with an empty body; (all four static) a weak `W/"..."` ETag + `Last-Modified` and a 304. No persisted state.
The ETag format is NOT uniform across the four (see the register).

## Providers and substitutability

Transport-level. A future runtime should implement ONE agreed compression + ETag contract rather than the
current Python-only-plus-three-static-variants split.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CE-COMPRESSION-PY-ONLY | The prior doc claimed gzip compression in ALL FOUR ("gzip | gzip | gzip | gzip"); GROUND TRUTH: response gzip compression exists ONLY in Python (`response.py:483-486`). PHP/Ruby/Node have NO compression primitive anywhere in their trees. The doc's PHP/Ruby/Node compression cells were fabricated. | Decide the feature's real scope (CE-DEC-01): either implement gzip (Accept-Encoding-gated, size + content-type thresholded) in PHP/Ruby/Node, or document compression as a Python-only optimization and stop asserting parity. |
| CE-DYNAMIC-ETAG-PY-ONLY | The prior doc claimed a dynamic "content hash" ETag in all four; GROUND TRUTH: a dynamic content-hash ETag (and conditional-GET/304 on a dynamic response) exists ONLY in Python (`response.py:488-491`, `server.py:2813-2826`). PHP/Ruby/Node attach NO ETag to a dynamic response and never 304 one. | Same scope decision (CE-DEC-01): port the dynamic ETag + 304 to the other three, or document Python-only. |
| CE-STATIC-ETAG-DIVERGENCE | The static-file ETag format diverges FOUR ways (the doc's "identical across the four" is false): Python strong md5 `"<hex16>"`; PHP `W/"mtime-size"` decimal; Ruby `W/"mtime-size"` hex; Node `W/"size-mtimeMs"` (reversed order, fractional ms). A client caching a static file behind a reverse proxy sees a different validator per backend language. | Pin ONE static ETag format (weak `W/"<size>-<mtime>"` with agreed encoding) across the four (CE-DEC-02). |
| CE-PY-304-DROPS-VALIDATORS | Python's 304 (both dynamic and static paths) sends `headers: []` (`server.py:2824`), DROPPING the ETag and Last-Modified on the 304 - contradicting the prior doc's own claim (line 91 "A 304 carries NO body and preserves the ETag") and RFC 9110 (a 304 SHOULD carry the validator). PHP/Ruby/Node static 304 DO preserve them (`StaticFiles.php:163`, `rack_app.rb:249`, `static.ts:71`). | Echo ETag + Last-Modified on Python's 304 (CE-DEC-02). |
| CE-INM-SEMANTICS-DIVERGE | If-None-Match matching diverges: Python does an EXACT full-string compare (no `W/` strip, no comma-list, no `*`; `server.py:2823`); PHP/Ruby/Node do RFC-7232 weak comparison with comma-lists and `*` (`StaticFiles.php:227`, `rack_app.rb:262`, `static.ts:131`). A client sending `W/`-prefixed, multiple, or `*` INM revalidates differently against Python. | Unify INM matching on the RFC-7232 weak-comparison + list + `*` semantics in Python (CE-DEC-02). |
| CE-ETAG-OVER-COMPRESSED | Python hashes the ETag over the COMPRESSED body (`response.py:483-490`), so the same resource served gzip vs identity carries DIFFERENT ETags. Defensible per RFC (an ETag identifies a representation) but undocumented and it interacts badly with a cache keyed on the URL only. | Document that the ETag is per-representation (or hash the identity body + rely on `Vary`); decide with CE-DEC-01. |
| CE-NO-FIXTURE | No shared `compression_etag_contract.json` exists; nothing gates any of the above. | Add the fixture once CE-DEC-01 sets the scope. |

## Owner decisions

- CE-DEC-01 (proposed, THE call): decide the feature's true scope. Compression + a dynamic ETag + dynamic
  conditional-GET are Python-only today. Either (a) implement them in PHP/Ruby/Node to make this a real
  four-language feature, or (b) document them as Python-only and rewrite the matrix/contract to stop claiming
  parity. The prior doc mis-stated reality as if (a) were already true.
- CE-DEC-02 (proposed): regardless of CE-DEC-01, pin ONE static-file ETag format across the four
  (CE-STATIC-ETAG-DIVERGENCE), fix Python's 304 to preserve the validators (CE-PY-304-DROPS-VALIDATORS), and
  unify INM matching semantics (CE-INM-SEMANTICS-DIVERGE).

## Proposed conformance fixture

A shared fixture (real server): a compressible >1KB body returns gzip WITH `Vary` when the client sends
`Accept-Encoding: gzip`, identity otherwise (once compression exists in all four); a cacheable response
carries an ETag; a matching `If-None-Match` returns 304 WITH the ETag preserved and an empty body; a
`W/`-prefixed / comma-list / `*` INM matches per RFC-7232; the static ETag format is identical across the
four for the same file.

## Integration map

- Consumers: every response (compression), caching/CDN clients (ETag/304). Composes: the response builder,
  the static-file handler (41).

## Breaking changes and migration

- Implementing compression/ETag in PHP/Ruby/Node (if CE-DEC-01 chooses parity) adds headers a client did not
  previously see - additive but note it. Changing the static ETag format changes cache keys (a one-time
  revalidation storm) - document it. Fixing Python's 304 to preserve validators is a correctness fix.

## Porting capsule

A new language must match whatever CE-DEC-01 decides. If parity: gzip when the body exceeds a size threshold
AND `Accept-Encoding` offers gzip AND the content type is compressible, set `Content-Encoding` + `Vary`;
attach a strong ETag to a cacheable response; answer a matching `If-None-Match` with a 304 that PRESERVES the
ETag + Last-Modified and an empty body; use RFC-7232 weak comparison (strip `W/`, split the comma-list,
honour `*`) with INM taking precedence over IMS. Use ONE static-ETag format across all languages. Do not
claim compression/ETag parity while three of four languages ship neither (the prior doc's error).

## Audit closure checklist

- [x] Boundary and public surface complete (compression + dynamic ETag Python-only; static ETag x four).
- [x] Lifecycle and producer/consumer edges complete (compress -> hash -> 304).
- [x] Configuration (none), failure (304-drops-validators) and security (Vary) rules complete.
- [x] Wire (Content-Encoding/Vary/ETag/304) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (Python-only compression + dynamic ETag; 4-way static
  divergence) - correcting the prior fabricated cells.
- [x] Owner ambiguities decided (CE-DEC-01 scope, CE-DEC-02 unify).
- [x] Conformance fixture (compression + 304 + static-ETag parity) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
