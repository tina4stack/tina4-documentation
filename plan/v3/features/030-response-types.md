# Feature 030: HTTP response model and representation types

## Identity and status

- Matrix identity: 30 — HTTP response model and representation types
- Audit state: decision-ready
- Audit note: Implementation is deliberately deferred
- Dependencies: Feature 29 request model, Feature 31 dispatch, Feature 33
  middleware and the ORM/DatabaseResult contracts
- Dependants: errors, authentication, CORS, rate limiting, Swagger, response
  caching, compression/ETag and application routes
- Existing ADRs: ADR-0019
- Shared fixtures: `plan/v3/fixtures/response_types_contract.json`
  version 1

- Release boundary: v3 / 3.14.0; parity-breaking corrections are permitted
- Required follow-up decision: ADR-0050, superseding the Feature 30 clauses of
  ADR-0019 rather than silently rewriting them
- Re-audit date: 2026-08-10

Feature 30 is **not complete**. Its 284 focused local/lab checks remain green,
but adversarial values produce invalid JSON, silent data loss, memory-address
strings, changed native values and uncaught exceptions. The old audit says PHP
and Ruby preserve a status selected before a type helper. Current Ruby still
resets that status to 200, and its own chaining test comments on the reset
without asserting it. That historical closure is false.

File responses are also four different resource policies. Every port reads the
whole file into memory. A directory is 404 in Python, HTTP 200 plus a false
Content-Length in PHP, and an uncaught exception in Ruby/Node. Redirect helpers
store CR/LF in Python, PHP and Ruby; Node throws only when its native transport
tries to set the field. Header names are case-sensitive collections in three
ports, so two spellings can emit two Content-Type fields.

This audit changes no framework source. It defines one buffered response model,
one strict recursive JSON conversion, exact media types/bytes, bodyless-status
rules, validated redirects, bounded file delivery and an executable formula for
the four current ports and any future Tina4 language.

The old combined file has been archived. Rate limiting now lives in
`034-rate-limiting.md`, the routes CLI in `114-cli-routes.md`, and route groups
in `031-route-groups.md`.

## Why this feature exists

An engineer should be able to return native application and Tina4 values and
receive a correct HTTP representation immediately. They should not call
`to_dict()`, pretty-print JSON differently by helper, remember that Ruby strings
inside `json()` are not quoted, guard `NaN`, strip a 204 body, sanitize a
download field or choose a language-specific file-stream API.

The response API is the last framework boundary before untrusted bytes reach a
client. Convenience that silently changes type or status misses Tina4's point.
The contract must be small, explicit where content is active, strict where a
declaration cannot work and identical enough that the same client can consume
an application after its backend language changes.

## Boundary

Feature 30 owns:

- callable/automatic response type selection;
- explicit JSON, HTML, text, XML, binary, redirect and file helpers;
- recursive native/model/query-result conversion for JSON;
- strict serialization and exact media-type/body bytes;
- status selection/preservation and body-forbidden response behavior;
- safe Location serialization;
- file classification, confinement, MIME lookup, attachment disposition,
  length and bounded delivery;
- response commit state as consumed by the finalizer;
- the request-local response instance, case-insensitive header registry and
  cookie-facing response state;
- shared executable cases and a future-language implementation formula.

It delegates:

- handler return interpretation, HEAD fallback and final socket commit to
  Feature 31;
- after hooks and guaranteed final unwind to Feature 33;
- error logging and the production 500 envelope to error handling;
- template compilation/rendering to Frond;
- streaming/SSE source semantics to the streaming feature;
- ranges, conditional requests, compression and ETag to their owning feature;
- response caching eligibility/storage to the cache feature;
- CORS, rate-limit and security fields to their middleware policies.

Feature 30 still specifies how those features compose at commit: there is one
status, one body, one case-insensitive field registry and one body-suppression
decision.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

### Standards authority

RFC 8259 defines JSON values, forbids NaN and Infinity, requires UTF-8 for open
ecosystems and registers `application/json` with no parameters. Tina4 therefore
uses bare `application/json`, no BOM, finite numbers and strict generation. See
[RFC 8259](https://www.rfc-editor.org/rfc/rfc8259.html).

RFC 9110 defines response content semantics. A response to HEAD and a response
with status 1xx, 204 or 304 has no content; 205 also forbids generated content.
Tina4 applies this once during finalization. See
[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html).

RFC 9110 also makes field names case-insensitive and restricts duplicate field
lines unless the field supports list combination. Content-Type and Location are
singletons; Set-Cookie is the deliberate multi-line exception. This is why a
case-sensitive language map/list is not the response-field contract.

RFC 6266 defines Content-Disposition and its `filename`/`filename*` parameters.
The filename is advisory, path segments are unsafe, and `filename*` carries a
UTF-8 encoded name. Tina4 emits an ASCII fallback plus `filename*` when needed.
See [RFC 6266](https://www.rfc-editor.org/rfc/rfc6266.html).

### Audited implementation evidence

Audited local staging heads were Python `29feeab`, PHP `c75c7b0e`, Ruby
`ea3aa88` and Node `813b50b`. Their only known local staging addition is the
approved Feature 1 fixture runner. The serialized Linux lab cloned public `v3`
heads Python `12cc44b`, PHP `46f9642`, Ruby `25ac783` and Node `96a5050`, then
ran as root through `/root/tina4-lab/with-lab-lock.sh`.

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Main response | `core/response.py` | `Tina4/Response.php` | `lib/tina4/response.rb` | `core/src/response.ts` |
| Storage before commit | buffered | buffered, but `send()` performs I/O | buffered Rack state | writes native response immediately |
| JSON media type | bare | bare | adds charset | bare |
| JSON whitespace | compact | pretty in `json`, compact in callable | compact | compact |
| Unicode | ASCII escapes | direct UTF-8 | direct UTF-8 | direct UTF-8 |
| Plain callable string | text, markup sniffed as HTML | text, markup sniffed as HTML | always HTML in `call`; dispatcher sniffs | text, markup sniffed as HTML |
| Null automatic return | inconsistent with callable 200 | callable 200 empty | dispatcher 204, callable 200 | callable 200 empty |
| Nested model conversion | incomplete | incomplete | incomplete, hard class check | incomplete |
| Status helper with omitted status | preserves | preserves | resets to 200 | preserves |
| Header identity | case-sensitive list | case-sensitive map | case-sensitive map | native case-insensitive registry |
| File delivery | reads all bytes | reads all bytes | reads all bytes | reads all bytes synchronously |
| Shared fixture/runner | none | none | none | none |

Focused suites passed locally and on the lab:

| Python | PHP | Ruby | Node |
| --- | --- | --- | --- |
| 38 passed | 67 tests / 126 assertions | 64 examples | 115 assertions |

Those green totals prove the old language-local characterization. The lab's
adversarial cases produced:

| Input | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| JSON Unicode `cafe` with accented e | emits `\u00e9` | UTF-8, pretty | UTF-8, compact | UTF-8, compact |
| JSON NaN | emits invalid `NaN` | empty body, 200 | throws | silently changes to `null` |
| Unsupported object | stringifies | empty/object data loss | memory-address string | throws for BigInt |
| Nested model in map | memory-address string | `{}` | not normalized | not normalized |
| `json("hello")` | valid quoted JSON | valid quoted JSON | invalid unquoted `hello` | valid quoted JSON |
| callable plain string | text | text | HTML | text |
| `json({x:1}, 204)` builder | keeps body | keeps body | keeps body | native Node suppresses on wire |
| redirect containing CR/LF | stored | stored | stored | native field setter throws |
| `/tmp` passed to `file()` | 404 | 200, empty, false length | throws EISDIR | throws EISDIR |

Python's nested-model body included a process memory address, making bytes
nondeterministic as well as semantically wrong. PHP reported the directory's
entry-storage size as Content-Length while `file_get_contents` failed, then
returned an empty HTTP 200 body. These are measured outcomes, not source-only
predictions.

The current auto-serialization suites use duck-typed fake models/results in
Python, PHP and Node. Ruby uses a real ORM subclass but does not persist/load it
through a real database. None proves that a real loaded ORM model and a real
DatabaseResult cross the normal application wire unchanged.

The organization issue sweep found PHP issue 118 (large-response truncation,
closed), PHP issue 173 (`toDict()` deprecation conflict, closed), PHP issue 184
(Frond `json_encode` silent-empty behavior, closed) and book issues 73/88 about
response documentation. No open issue tracks the Feature 30 re-audit contract.

### Shared executable contract

Create `plan/v3/fixtures/response_types_contract.json` with:

- schema version, feature number and canonical media types;
- automatic selection for null, bool, finite/safe numbers, strings, markup-like
  strings, bytes, maps/lists and unsupported values;
- explicit helper/status preservation cases;
- compact Unicode/escaping/key-order JSON bytes;
- top-level scalars and recursive ORM/DatabaseResult/application-protocol data;
- NaN/infinities, unsafe integers, unsupported types, non-string keys and
  direct/indirect cycles with normalized error class/path;
- case-insensitive header replacement and Set-Cookie multiplicity;
- HEAD, 204, 205 and 304 selected-versus-wire cases;
- redirect status/relative/absolute/Unicode/control cases;
- real temp-file, missing, directory, FIFO, root escape, symlink and attachment
  filename vectors;
- shared MIME extension table;
- exact normalized runner report schema.

Each language runner emits:

```json
{
  "feature": 30,
  "schema_version": 1,
  "language": "another-language",
  "passed": 0,
  "failed": 0,
  "cases": []
}
```

Thin runners exercise production normalization/builder/file-selection code.
Separate integration suites boot the normal app and use TCP sockets to prove:

- handler automatic return selection;
- middleware/final header and status ownership;
- exact wire bytes and serialization-error 500;
- GET/HEAD and 204/205/304 behavior;
- redirects with a real HTTP parser;
- a large file streams under a fixed memory ceiling with slow-client
  backpressure/disconnect cleanup;
- real ORM rows and real DatabaseResult values from SQLite plus one server DB;
- Docker/lab behavior on the supported production adapter.

No fake Response/ServerResponse or testing-only output bypass can satisfy a
wire case. A temporary filesystem is real evidence for file selection; an
injected chunk-size/slow reader may control timing but cannot replace the real
file or transport.

## Public surface contract

Every language exposes the same neutral operations on one request-local response
builder. Method names follow each language's conventions (snake_case in Python and
Ruby, camelCase in PHP and Node); behavior, media types and result state do not vary.

| Neutral operation | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Set status | `status(code)` | `status($code)` | `status(code)` | `status(code)` |
| Replace header | `header(name, value)` | `header($name, $value)` | `header(name, value)` | `header(name, value)` |
| Append header | `add_header(name, value)` | `add_header($name, $value)` | `add_header(name, value)` | `addHeader(name, value)` |
| Set cookie | `cookie(name, value, options)` | `cookie(...)` | `cookie(...)` | `cookie(...)` |
| JSON | `json(data, status?)` | `json($data, $status?)` | `json(data, status:)` | `json(data, status?)` |
| HTML | `html(content, status?)` | `html($content, $status?)` | `html(content, status:)` | `html(content, status?)` |
| Text | `text(content, status?)` | `text($content, $status?)` | `text(content, status:)` | `text(content, status?)` |
| XML | `xml(content, status?)` | `xml($content, $status?)` | `xml(content, status:)` | `xml(content, status?)` |
| Binary | `binary(bytes, status?, type?)` | `binary(...)` | `binary(...)` | `binary(...)` |
| Error | `error(code, message, status=400)` | `error($code, $message, $status=400)` | `error(code, message, status=400)` | `error(code, message, status?)` |
| Redirect | `redirect(url, status=302)` | `redirect($url, $status=302)` | `redirect(url, status:)` | `redirect(url, status?)` |
| File | `file(path, status?, content_type?, download?, filename?, root?)` | same canonical arguments | same | same |
| Automatic send | `send(data?, status?, content_type?)` | `send(...)` | `send(...)` | `send(...)` |
| Template | `render(template, data, status?)` | `render(...)` | `render(...)` | `render(...)` |
| Stream | `stream(source, content_type?)` | `stream(...)` | `stream(...)` | `stream(...)` |
| Inspect | status/header/body readers | `getStatusCode`/`getHeaders`/`getBody` | reader methods | readers |

`render` binds Frond and is specified by the template feature; `stream` opens the
streaming feature. Both mutate and return the same builder. A port may keep a native
constructor, but portable examples and fixtures use these operations.

The current surface diverges and must converge before 3.14. `file()` today has four
different argument lists (Python `file(path, download_name, root)`, PHP
`file(path, contentType, download, root)`, Ruby `file(path, content_type:, download:,
root:)`, and no `status`/`filename` on some), so the canonical six-argument form above
is the target. `binary()` is new where a port only reached octet-stream through `send`.
Ruby's `csv()`, `add_cors_headers()`, the `call` path and `auto_detect` are not the
portable contract: CSV is `text`/`file` with an attachment, and cross-origin headers
belong to Feature 34. PHP's `withHeaders()` folds into `add_header`/`header`, and its
large accessor set stays as inspection only. Node's helpers currently write to the
transport; they must buffer (owner decision 1) and return the builder like the others.

## Inputs and outputs

### Automatic type selection

The normal handler-return/callable decision is ordered:

| Native value | Result |
| --- | --- |
| Response builder | use it unchanged |
| null / no return | status 204, no representation |
| map/object, list/tuple, ORM, DatabaseResult | strict JSON |
| boolean or finite safe number | strict JSON scalar |
| Unicode string | UTF-8 text/plain |
| byte string/buffer | application/octet-stream |
| file helper result | file representation |
| anything else | typed serialization error -> normal production 500 |

There is no markup sniff. `"<h1>name</h1>"` is text unless the engineer calls
`html()`. There is no integer-as-status shortcut; call `status(404)` or return a
response with 404. Explicit methods always win over automatic selection.

Automatic null means 204. Explicit `json(null)` means HTTP 200 with body `null`.
This distinction lets an engineer return JSON null intentionally without making
an omitted handler result look like a JSON document.

### Explicit representation helpers

| Helper | Media type | Input/bytes |
| --- | --- | --- |
| `json(value, status?)` | `application/json` | strict normalized compact UTF-8 JSON |
| `html(value, status?)` | `text/html; charset=utf-8` | Unicode string encoded UTF-8; no implicit escaping |
| `text(value, status?)` | `text/plain; charset=utf-8` | Unicode string encoded UTF-8 |
| `xml(value, status?)` | `application/xml; charset=utf-8` | Unicode string encoded UTF-8; helper does not parse/repair XML |
| `binary(bytes, status?, content_type?)` | supplied validated type or octet-stream | bytes unchanged |
| `error(code, message, status=400)` | `application/json` | canonical error object below |

The error helper emits compact keys in this order:

```json
{"error":true,"code":"VALIDATION_FAILED","message":"Email is required","status":400}
```

Content is native Unicode/bytes. Passing an object to HTML/text/XML does not
call its string conversion; it is a type error. JSON-like structured data with
an explicit non-JSON content type is also a type error. Use the correct helper
so the media type cannot lie about the body.

## Lifecycle and operation graph

Each request receives one buffered response builder. The path is:

```text
new response (status 200, empty registry, no representation, committed=false)
  -> handler runs; return value or explicit helper selects representation state
  -> automatic selection maps a native return to a representation, or a helper sets it
  -> strict conversion/validation runs now; a failure raises before any bytes exist
  -> Feature 33 after hooks unwind and may replace status/fields/representation
  -> Feature 31 finalizer computes representation metadata (type, length, validators)
  -> bodyless rules apply once (HEAD, 204, 205, 304)
  -> delegated composers add their fields (Feature 34 CORS, rate-limit, security)
  -> transport commits exactly once; committed=true
  -> a file/stream representation streams bounded chunks, closing on end/error/disconnect
```

Producers of response state are the handler return, the explicit helpers, `send`,
`render` and framework middleware. Every producer mutates the same builder and returns
it; none writes to the socket. Inspection (`to_sql`-equivalent status/header/body
readers) never commits. There is no retry or rollback: a conversion or validation
error becomes the normal production 500 before commit, and a post-commit mutation or
second commit raises `ResponseAlreadyCommitted`. The builder is request-local and is
never shared across concurrent requests.

## Configuration and precedence

Response types has no environment variables or project files of its own. Its only
precedence rules are local to a request:

1. **Selection.** An explicit helper always wins over automatic selection. `json(x)`
   is JSON even when `x` is a string; a bare handler return uses the automatic table.
2. **Status.** A status passed to a helper wins over a chained `status(code)`, which
   wins over the default 200. An omitted helper status preserves the current status;
   it never resets to 200. Valid final status is an integer 200 through 599.
3. **Content type.** An explicit `content_type` on `binary`/`send` wins; otherwise the
   helper's fixed media type applies; a file uses its validated type or the shared MIME
   table, then `application/octet-stream`.
4. **Fields.** A singleton header set later replaces the earlier one case-insensitively;
   `Set-Cookie` accumulates. Delegated composers (Feature 34 CORS, rate limiting,
   security, compression) add their fields at finalization and own those names.

Template rendering reads Frond's own configuration (template directory, cache) through
the template feature; response caching timing belongs to the cache feature. Response
types stores none of it and reads no cache at selection time.

## Failures, side effects and security

### Logging and failure behavior

Serialization, invalid status/location and bad explicit media-type calls are
application errors. They flow through the standard error boundary before
commit. Logs include request ID, error class and bounded structural path; never
the full body/model/file name when it may be sensitive.

Missing/not-regular file is an ordinary 404. Root/path traversal is 403 and may
produce a sampled security diagnostic. A file open/read error after selection
must not crash the worker. Before commit it becomes the normal 500; after a
partial stream commit the transport closes the stream/socket and logs once.

No helper prints/writes directly, so PHP testing mode is unnecessary and Node
does not leave Content-Type selected after JSON generation threw.

## Wire and persistence contract

### JSON normalization and bytes

Normalize recursively before generation:

1. null, boolean, string and finite number are terminal JSON values;
2. integer must be inside the interoperable safe range;
3. list/tuple normalizes every item in order;
4. map/object requires string keys and normalizes every value in insertion
   order;
5. Tina4 ORM uses its canonical response-data method, then recurses;
6. DatabaseResult uses its canonical record list, then recurses;
7. a documented application JSON protocol (`to_dict`, `toDict`, `to_h` or the
   language's Tina4 interface) may produce a value, then recurses;
8. revisiting a container/object identity is a cycle error;
9. every unsupported value is an error, never `str()`/`toString()`/`{}`.

The future-language implementation should expose one internal
`to_response_data` protocol even when public idiomatic aliases differ. ORM and
DatabaseResult implement/register that protocol without creating a package
cycle. The response layer must not recognize a real Tina4 type by copying a
duck-shaped fake into its tests.

Canonical JSON generation:

- UTF-8, no BOM;
- `application/json` exactly;
- compact commas/colons, no optional whitespace/newline;
- direct Unicode characters, with only required JSON escaping;
- insertion order preserved, not alphabetically sorted;
- slash not escaped;
- NaN and both infinities rejected;
- negative zero follows the language-neutral fixture spelling;
- serialization completes before response state changes or any bytes commit.

A conversion/generation failure raises `ResponseSerializationError` with a
bounded path such as `$.users[2].balance`; logs may include the type/path but
not the value. Dispatch converts it through the normal production 500 contract.
It never sends a partial/empty 200.

### Bodyless finalization

The finalizer first computes the selected representation metadata, then applies
request/status body rules:

- HEAD: run the same handler/final policies as GET, preserve would-be
  Content-Type, Content-Length, validators and other fields, send zero content;
- 204 and 205: discard representation and Content-Type/Content-Length;
- 304: discard representation; keep only allowed validator/cache metadata and
  omit Content-Length for Tina4 parity;
- every other 200-599 status: commit the selected representation normally.

No early middleware/framework response bypasses this step. Logging records the
wire body length (zero for HEAD/bodyless) and may separately record selected
representation length for diagnostics.

### Redirect contract

`redirect(location, status=302)`:

- accepts only 301, 302, 303, 307 or 308;
- accepts one non-empty absolute or relative URI-reference;
- rejects CR, LF, NUL, other controls, surrounding whitespace and invalid URI
  syntax before modifying response state;
- percent-encodes non-ASCII URI components to one ASCII Location value;
- sets the selected status and one Location field;
- selects no body and no Content-Type;
- preserves unrelated safe fields/cookies.

Tina4 does not guess 301/303/307 from the request method. The engineer selects
redirect semantics explicitly; the default remains the familiar 302.

### File and attachment contract

Canonical surface (with idiomatic argument syntax per language):

```text
file(path, status=200, content_type=null, download=false,
     filename=null, root=null)
```

Rules:

1. Reject any caller path containing an exact `..` segment with 403 before
   opening it. This retains the traversal fix.
2. If `root` is supplied, resolve the candidate and symlinks and require the
   final opened regular file to remain within root. Escape is 403.
3. If root is absent, a relative/absolute path selected by trusted application
   code remains allowed per ADR-0012. This is not a static-files helper.
4. Open once, then verify the opened target is a readable regular file. Missing,
   unreadable, directory, FIFO, socket or device returns 404 `File not found`.
5. Do not load the file. Record an open file representation, length and stable
   metadata; the transport streams bounded chunks with backpressure and closes
   the handle on success, error, disconnect or shutdown.
6. Determine Content-Type from an explicit validated media type or the shared
   extension table. Unknown is `application/octet-stream`.
7. Set Content-Length from the opened regular file, not a pre-open path stat.
8. `download=false` emits no Content-Disposition. `download=true` emits
   attachment with basename unless `filename` is supplied.
9. Filename override must be one basename with no separator/control. Emit a
   quoted escaped ASCII fallback; add RFC 5987 UTF-8 `filename*` when needed.
10. HEAD follows the same open/metadata path and sends no file bytes.

The shared MIME table covers at least html, css, js, json, xml, txt, csv, pdf,
zip, common images/audio/video and web fonts. Fixture cases own exact spellings;
the operating system MIME database cannot decide parity.

Ranges/conditional validators/compression are delegated, but they consume the
file representation without forcing it into memory. Compression must not make
Content-Length lie.

## Providers and substitutability

Response types has no swappable storage backend the way the database, cache or session
features do. Its substitutable units are the representation producers and the consumers
that compose at commit.

- **Representation producers** (JSON, HTML, text, XML, binary, redirect, file, template)
  must emit byte-identical output for the same input in every language. The
  `to_response_data` protocol is the substitution seam: real ORM models, `DatabaseResult`
  and a documented application protocol register against it, and the JSON producer
  recurses through it without knowing the concrete type. A port swaps its JSON library
  but not the normalized bytes.
- **Commit consumers** (Feature 31 finalizer, Feature 33 unwind, Feature 34 CORS, rate
  limiting, security headers, compression/ETag, response caching) consume the buffered
  state through the one status/one body/one case-insensitive field registry. Any of them
  may be present or absent; none may bypass finalization or write bytes early.

Deliberate capability exceptions, recorded so a port does not treat them as defects:
`stream` and Server-Sent Events commit on their first chunk, so the bodyless and
after-mutation rules that assume a buffered body do not apply to a committed stream;
the streaming feature documents what remains legal. A compatibility raw-transport
accessor may exist for advanced use, but normal dispatch commits once through the
finalizer. Template rendering delegates its whole engine to Frond; response types only
guarantees the rendered bytes reach commit as an HTML representation.

## Contradictions and defects

### Defect register

| ID | Severity | Ports | Finding |
| --- | --- | --- | --- |
| H12-01 | release blocker | Ruby | An omitted status in `json`/`html`/`text` resets a chained status to 200. The old audit says fixed; current code and its own non-asserting test say otherwise. |
| H12-02 | release blocker | all | Unsupported/cyclic/non-finite JSON has four failure policies: stringify, empty 200, changed value or exception. Invalid data can look successful. |
| H12-03 | release blocker | Ruby/Node | Ruby `json("hello")` emits invalid unquoted JSON. Node `json(undefined)` emits an empty 200 body labelled JSON. |
| H12-04 | parity defect | Python/PHP/Ruby | Exact JSON bytes differ through ASCII escaping, pretty printing and the Ruby charset parameter. One endpoint changes bytes by entry point in PHP. |
| H12-05 | framework principle | all | Real ORM/DatabaseResult conversion is shallow/inconsistent. Nested Tina4 values require developer conversion or silently lose data, contrary to the immediate-native-value principle. |
| H12-06 | security/DX | all | Automatic `<...>` string sniffing upgrades data to active HTML; Ruby's callable upgrades every string. Content type depends on user bytes instead of the developer's explicit helper. |
| H12-07 | parity defect | all | Null, boolean, number and bare handler returns do not share one automatic type/status contract; Ruby treats an integer handler result as a status code. |
| H12-08 | protocol defect | Python/PHP/Ruby | Helpers can build content for 204/205/304. Suppression depends on whichever transport path is used, and early paths can bypass it. |
| H12-09 | protocol/security | Python/PHP/Ruby | Case-sensitive field storage permits duplicate singleton fields such as `Content-Type` with different casing. |
| H12-10 | security | Python/PHP/Ruby | Redirect accepts CR/LF into Location state. Node rejects only because its native transport throws after application code has selected the response. |
| H12-11 | release blocker | PHP/Ruby/Node | A directory passed to `file()` becomes a false 200 or uncaught exception instead of a stable not-regular response. Special files are not uniformly rejected. |
| H12-12 | operational | all | `file()` reads the complete file into process memory (Node synchronously), so concurrent large downloads can exhaust/block a worker. |
| H12-13 | parity/security | all | MIME maps, custom download-name surface and Content-Disposition escaping differ. Python can place an unvalidated caller-supplied filename into a header. |
| H12-14 | architecture | PHP/Node/all | Response commit ownership differs. PHP `send()` and every Node helper can perform transport I/O before after-middleware/final policy has completed. |
| H12-15 | validation | all | Status and redirect helpers accept invalid status values until a runtime/transport reacts. There is no shared typed response-construction error. |
| H12-16 | test architecture | all | No shared fixture exists; 3/4 model suites use stand-ins, PHP testing mode suppresses the actual send path, and exact invalid-value/bodyless/file behavior is absent. |
| H12-17 | documentation | central | Historical and master material claims status/media/file parity that current source contradicts, and the old bundle hid Features 30, 114 and 31 under one filename. |

## Owner decisions

### Decisions proposed for owner review

The audit recommends these decisions as one contract:

1. The response builder is buffered. Helpers select representation state and
   return the same response object; they do not write to the socket. Feature 31's
   finalizer commits once after Feature 33 unwinds.
2. An omitted helper status preserves the response's current status. Every new
   response starts at 200. Explicit status must be an integer from 200 through
   599; application helpers cannot create an informational response.
3. Automatic structured data, booleans and finite numbers become JSON. A string
   is always `text/plain`; HTML requires explicit `html()`. Bytes become
   `application/octet-stream`. Null/no return becomes 204. This removes markup
   sniffing and Ruby's integer-as-status behavior.
4. JSON is strict, compact UTF-8 with `Content-Type: application/json` and no
   charset parameter. Unicode is emitted directly. NaN/Infinity, cycles,
   unsupported objects, non-string map keys and unsafe integers fail before
   commit; nothing stringifies or returns empty HTTP 200.
5. Tina4 ORM models, DatabaseResult values and documented application
   JSON-conversion protocols normalize recursively at any nesting depth. The
   engineer never manually maps a framework value just to return it.
6. HEAD and 204/205/304 never carry content. HEAD preserves the representation
   metadata a GET would have sent. The bodyless status rules live in the one
   finalizer, not in each helper.
7. Redirect accepts only 301, 302, 303, 307 or 308 and a valid non-empty URI
   reference with no control character. Default is 302; body and Content-Type
   are empty.
8. `file()` accepts only a readable regular file, preserves the approved
   unrooted absolute-path behavior from ADR-0012, applies confinement when a
   root is supplied, and streams with backpressure instead of loading the file.
9. Attachment names are generated by the framework from a safe basename and
   RFC 6266 `filename`/`filename*` fields. User input never enters a header
   without validation/encoding.
10. One central data fixture plus thin runners owns parity. Real application
    sockets separately prove finalization, HEAD/bodyless behavior, large files
    and serialization errors.

The safe-integer rule is the only cross-language range restriction proposed:
JSON integers outside `-(2^53-1)` through `2^53-1` cannot round-trip through
JavaScript without loss. An engineer who needs a larger identifier returns it
as a string or gives the model field a string JSON representation. Silent
precision loss is not a convenience feature.

## Proposed conformance fixture

`plan/v3/fixtures/response_types_contract.json` (version 1) holds the case groups
listed under Shared executable contract above: automatic selection, explicit helpers and
status preservation, exact JSON bytes, recursive ORM/`DatabaseResult`/protocol data,
invalid-value errors, case-insensitive fields and Set-Cookie, HEAD/204/205/304, redirect
status/URI/control vectors, and file directory/special/traversal/symlink/MIME/disposition
cases. Every case records normalized values, not language spelling, and stores ordered
maps as key-value arrays so object-key reordering cannot hide a defect.

The fixture is considered wired only when these mutation witnesses are proven red:

- a returned string is served as `text/html` (markup sniffing restored);
- `NaN`/Infinity, a cycle or an unsupported value serializes to a value or an empty 200
  instead of a pre-commit error;
- an unsafe integer is emitted as a JSON number instead of failing;
- a nested ORM/`DatabaseResult` value is left unconverted or stringified;
- an omitted helper status resets a chained status to 200;
- a helper writes to the socket before the finalizer runs;
- a 204/205/304 or HEAD response carries a body;
- `Content-Type` is stored twice under different casing;
- a redirect keeps a CR/LF in its Location;
- `file()` returns 200 for a directory, or loads the whole file into memory;
- a caller-supplied download filename reaches the header without validation.

A witness that only asserts a fake `Response`/`ServerResponse` shape does not count; the
wire, bodyless, ORM and file witnesses run through the real transport, a real loaded ORM
model and a real temporary filesystem.

## Integration map

Implementation must update these consumers together:

| Consumer | Required integration |
| --- | --- |
| Feature 31 dispatch | interpret a handler return through automatic selection; own HEAD fallback and the single final socket commit |
| Feature 33 middleware | run after hooks on the buffered builder before commit; never let an early return bypass finalization |
| error handling | convert a serialization/validation/file error to the production 500 before commit; never send a partial 200 |
| Feature 34 CORS / rate limiting / security | add their fields to allowed and error responses at finalization through the one field registry |
| compression / ETag / ranges | consume the file/representation without forcing it into memory; must not make Content-Length lie |
| response caching | store only an eligible committed representation; a 429/500/`no-store` is never cached |
| Frond templates | `render` produces an HTML representation; response types owns only that the bytes reach commit |
| Swagger | describe declared response media types from the helper contract, not sniffed types |
| Feature 39 shutdown | file/stream cleanup registers with disconnect and shutdown so no descriptor leaks |
| package exports | export the response builder and helpers; a native constructor stays optional |
| scaffolders / docs / AI reference | show only the neutral helpers and the automatic table; never markup sniffing or integer-as-status |
| central fixture + four runners | load `response_types_contract.json`, execute every case, report the hash |

No CLI command or environment variable owns response-type configuration. The only
startup dependency is Frond initialization for `render`.

## Breaking changes and migration

These are permitted 3.14 corrections. Release notes and startup diagnostics must give
each one an actionable instruction:

- **Returned strings are `text/plain`, not sniffed HTML.** A handler that returned
  markup and relied on auto-HTML must call `html(...)` explicitly. (Ruby also stops
  upgrading every callable string to HTML.)
- **Strict JSON.** `NaN`/Infinity, cycles, unsupported objects, non-string map keys and
  integers outside +/-(2^53-1) now raise before commit instead of emitting invalid or
  empty JSON. Return an out-of-range id as a string.
- **Buffered commit.** Node helpers and PHP `send()` no longer write to the socket; they
  set state and the finalizer commits once. Code that read the wire immediately after a
  helper must move to the response readers or the after-commit point.
- **Status preservation.** Ruby stops resetting a chained status to 200 when a helper
  status is omitted.
- **One `file()` signature.** Callers adopt `file(path, status?, content_type?,
  download?, filename?, root?)`; a directory or special file is now a 404, traversal is
  403, and large files stream instead of loading into memory.
- **Validated redirects and fields.** A redirect with a control character, an invalid
  status, or a header name/value with CR/LF/NUL now fails at construction. Duplicate
  singleton headers (mixed casing) collapse to one.
- **Ruby surface trim.** `csv()` becomes `text`/`file` with an attachment; response-level
  `add_cors_headers` is removed in favor of Feature 34.
- **Automatic null is 204.** A handler returning nothing yields 204; use `json(null)` for
  an intentional JSON `null` body.

Migration notes must show each language's native `DatabaseResult`/model access and the
explicit helper replacements. No compatibility mode is required before 3.14.0.

## Implementation backlog

### Implementation work by current port

| Port | Required change |
| --- | --- |
| Python | Use direct UTF-8 strict JSON (`allow_nan=false`, no `default=str`); recurse through maps/models/results; remove markup sniffing; validate fields/redirects/status; make bodyless finalization universal; replace header list singleton duplicates; stream open regular files. |
| PHP | Throw on every `json_encode` error and remove pretty mode; recurse real values; reject directories/special files; validate redirect/fields/status; make `send()` a builder alias rather than output; stream from an opened handle; lowercase canonical charset spellings. |
| Ruby | Preserve status when helper status omitted; quote JSON strings; remove callable/dispatcher HTML and integer-status inference; recurse values; use bare JSON media type; validate fields/redirects/status; turn file errors into stable selection and stream the handle. |
| Node | Buffer response state instead of ending the native response in helpers; reject NaN/undefined/BigInt/unsafe values consistently; recurse real values; remove markup sniffing; validate before state mutation; reject non-regular files cleanly and stream asynchronously with backpressure. |

All four replace fake auto-serialization inputs with real ORM/DatabaseResult
integration while retaining fixture-level custom-protocol cases.

## Porting capsule

### Implementation formula for another language

1. Implement a request-local buffered response state and a case-insensitive
   header registry. Keep transport I/O out of all helpers.
2. Implement status/media/field validation and typed construction errors.
3. Implement recursive `to_response_data` normalization with cycle/path
   tracking. Register real ORM and DatabaseResult adapters.
4. Implement strict compact UTF-8 JSON generation and exact explicit helpers.
5. Implement the automatic selection table; strings never activate HTML.
6. Implement validated redirect selection without committing.
7. Implement regular-file selection as an open descriptor/handle with shared
   MIME/disposition rules; never read the complete file.
8. Connect the builder to Feature 31's one finalizer after Feature 33 unwind.
   Apply HEAD/bodyless rules there, then commit once.
9. Register file/stream cleanup with disconnect and Feature 39 shutdown paths.
10. Run the shared fixture, real ORM/result integration, real sockets, large
    file/backpressure cases and the serialized Linux/Docker lab.

An engineer implementing only from this document, ADR-0050 and the fixture
must not need to read another language's Response class.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities recorded (10 proposed; the three genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### Canonical response state

Every request receives one response builder with:

```text
status: integer = 200
headers: case-insensitive singleton/multivalue registry
representation: none | buffered bytes | file descriptor | stream source
content_type: optional validated media type
committed: boolean = false
```

All public helpers mutate this state and return the same builder. They do not
write headers/body, close the socket or produce a language transport tuple.
`send(data, status?, content_type?)` is an alias for automatic selection, not a
transport operation. A compatibility transport accessor may exist for advanced
use, but normal framework dispatch commits once and owns finalization.

After commit, a mutation or second commit raises a typed
`ResponseAlreadyCommitted` error. Before commit, singleton headers replace
case-insensitively. Set-Cookie retains ordered multiple field values. A field
name/value containing CR, LF, NUL or invalid grammar is rejected immediately.

An optional status means preserve current state. It never means reset to 200:

```text
r.status(201).json({"id": 1})  -> 201
r.json({"id": 1}, 202)         -> 202
new Response().json({"id": 1}) -> 200
```

Valid application final statuses are 200 through 599. Informational responses
are a transport concern. Invalid type/range raises `InvalidResponseStatus`
before any commit.

### Acceptance bar

Feature 30 may move from decision-ready to final only when:

- ADR-0050 is accepted/indexed and ADR-0019 points to the supersession;
- the owner settles automatic strings/scalars, safe integers and the buffered
  commit model;
- `response_types_contract.json` and four thin runners pass;
- exact allowed JSON/media/body bytes match every port;
- every invalid JSON value fails before commit through the same error class;
- real nested ORM/DatabaseResult values need no application conversion;
- status chaining and automatic null/scalar behavior match;
- case-insensitive singleton field behavior and Set-Cookie multiplicity pass;
- real sockets prove HEAD and 204/205/304 carry no content;
- redirect controls/status/URI cases pass before transport;
- file directory/special/traversal/symlink/disposition/MIME cases match;
- a concurrent large-file lab run stays inside the agreed memory bound and
  closes descriptors on disconnect;
- normal middleware/finalization runs on every response/error path;
- local, serialized Linux root and Docker production-adapter suites pass;
- documentation describes only the ratified surface;
- another language can implement the feature from the central contract without
  reading a sibling port.

### Audit conclusion

Feature 30 has recognizable helpers in all four languages, but names are not
parity. Current implementations can label invalid/empty bytes as successful
JSON, change native values, reset an error status, activate HTML from returned
text, accept header controls, lie about a directory and load an arbitrary file
into worker memory. Language-local green tests protect those differences.

The 3.14 repair is one response transaction: native value to strict recursive
representation, validated status/fields, buffered middleware-visible state and
one standards-aware commit. A shared fixture makes that transaction portable;
the file/transport tests prove it remains safe when bytes become large or bad.
