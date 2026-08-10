# Feature 086: WSDL and SOAP

## Identity and status

- Matrix identity: 86 - WSDL and SOAP
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the WSDL/SOAP engine in each repo) at
  Python `386cd6d`, PHP `743b7469`, Ruby `c61250c`, Node `26be920`. The WSDL source on the in-flight
  `feature/csrf-fail-closed` branches is byte-identical to `v3` (verified: empty diff), so the SHAs
  above are the `v3` heads. I self-verified the security core (DOCTYPE-reject in all four), the Python
  content-type defect (WSD-01), the Python `List[T]` single-element bug (WSD-03) and the Node
  `register()` arity break (WSD-02) against source. No framework code changed.
- Dependencies: the router/core server (a WSDL service is wired into a route by the developer; there is
  no auto-mount), the auth layer (the route's own auth gates the service - WSDL adds none), the
  debug/log layer (fault masking via `TINA4_DEBUG`)
- Dependants: any app exposing a SOAP 1.1 service
- Existing ADRs: none specific to WSDL. The DTD-reject and fault-masking follow the framework security
  posture (billion-laughs/XXE defence and no-internal-state-leak), shared with GraphQL (082) and the
  XML surfaces.
- Shared fixtures: NONE. `wsdl_contract.json` is owed (no fixture, no CONTRACT-MAP row). The engine is
  proven per-framework by REAL in-process tests (Python 63, PHP 44, Ruby ~110, Node ~61 cases, all
  no-mock) but not by one shared oracle, and the HTTP-serving path is under-tested in all four.
- Catalog phase: Integrations

## Why this feature exists

An application needs to expose or interoperate with a SOAP 1.1 service without a heavy dependency.
Tina4 ships a hand-rolled, ZERO-DEPENDENCY WSDL/SOAP engine in every language: it generates the WSDL
document from a service class, parses an inbound SOAP envelope, dispatches to the operation, converts
parameters from the declared types, serializes the result back into a SOAP response, and - the security
core - rejects any DTD up front to close the XML entity-expansion and external-entity attack surface.

## Boundary

This feature owns the WSDL/SOAP ENGINE: the operation-declaration surface (a decorator/attribute/DSL
carrying a response schema), WSDL generation (types/message/portType/binding/service), SOAP request
parsing and operation dispatch, parameter type conversion, SOAP response serialization, the DTD-reject
security guard, the fault taxonomy (Client vs Server) with debug-gated masking, and the `on_request`/
`on_result` hooks. HTTP MOUNTING is IN scope but is where the frameworks diverge (see WSD-02): there is
no auto-mount in any language; the developer wires the service into a route.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Zero-dep hand-rolled (no ext-soap/lxml/nokogiri/lib) | yes (ElementTree) | yes (SimpleXML) | yes (REXML) | yes (hand-scanner) |
| Operation declaration | `@wsdl_operation` | `#[WSDLOperation]` | `wsdl_operation` DSL | `WSDLOperation` decorator |
| WSDL: all 5 sections, `urn:{Class}` tns | yes | yes | yes | yes |
| Dispatch by Body first-child local-name | yes | yes | yes | yes |
| `SOAPAction` read/validated | no (advertised only) | no | no | no |
| DTD/DOCTYPE rejected BEFORE parse -> Client fault | yes | yes | yes (x2 paths) | yes |
| Operation error -> Server fault, masked unless `TINA4_DEBUG` | yes | yes | yes | yes |
| Declared schema enforced on the response | no (advisory) | no | no | no |
| Scalar param conversion (int/float/bool) | yes | yes | DORMANT (all `:string`) | yes |
| Array/repeated-element input | broken (1 elem) | no | no | no |
| Content-type set correctly | NO (`text/html`) | yes (`text/xml`) | caller-applied | yes (`text/xml`) |
| HTTP mount helper | manual route (works) | manual route (works) | manual route (works) | `register()` BROKEN |
| `faultcode` QName-qualified (`soap:Client`) | no (bare) | no (bare) | no (bare; legacy `soap:Server`) | no (bare) |
| Real no-mock tests | 63 | 44 | ~110 | ~61 |

The SECURITY core (DTD-reject, fault masking) and the engine shape (declaration, generation, dispatch,
serialization) are at strong parity. The divergences cluster on the OUTER surface: content-type, HTTP
mounting, array input, faultcode conformance, and Ruby's dual API.

## Public surface contract

A service subclasses `WSDL`/`WSDLService`, declares operations with the language's decorator/attribute/
DSL (`@wsdl_operation(response_schema)` / `#[WSDLOperation(returnTypes)]` / `wsdl_operation(output:)` /
`WSDLOperation`), and the framework discovers them by reflection. Public methods: `handle(soap_body)`
(parse + dispatch -> SOAP response or fault string), `generate_wsdl(endpoint_url)` (the WSDL document),
and the hooks `on_request(request)` (called before the DTD guard; return ignored - validate/log only)
and `on_result(result)` (called after invocation; its return REPLACES the serialized body). There is no
auto-mount: the developer calls `handle`/`generate_wsdl` from a route. Ruby additionally ships a legacy
`WSDL::Service` builder (`add_operation(name, input_params:, output_params:, &handler)`) with different
wire output (WSD-04).

## Inputs and outputs

- Input: `GET` (or `?wsdl`) returns the WSDL document; `POST` a SOAP 1.1 envelope invokes an operation.
  The operation is the first child element of `<Body>` (local name, namespace-agnostic). Parameters are
  matched to the operation's declared inputs by element name and converted by declared type.
- Output: the WSDL XML, or a SOAP response envelope `<{op}Response>` built from the operation's returned
  map (null -> `xsi:nil`, array -> repeated elements, bool -> `true`/`false`, else an escaped scalar),
  or a SOAP `Fault`. A `Client` fault for a protocol error (DOCTYPE, malformed XML, missing/empty Body,
  unknown operation); a `Server` fault for an operation exception (masked unless `TINA4_DEBUG`).

## Lifecycle and operation graph

1. HOOK: `on_request` fires first (before any guard/parse), for validate/log side-effects; it cannot
   mutate the request or short-circuit dispatch.
2. GUARD: reject any `<!DOCTYPE>` via a raw-string regex on the body BEFORE parsing -> `Client` fault.
3. PARSE: parse the envelope (ElementTree / SimpleXML / REXML / hand-scanner); a parse error -> `Client`
   "Malformed XML".
4. LOCATE: find `<Body>`, take its first child; resolve the operation by local name; unknown -> `Client`.
5. BIND: match each declared input element by name; convert by declared type (int/float/bool/string);
   a missing element binds null.
6. INVOKE: call the operation; run `on_result` on the return; serialize the returned map.
7. FAULT: an operation exception is logged and returned as a `Server` fault (real cause only under
   `TINA4_DEBUG`).

## Configuration and precedence

- `TINA4_DEBUG` - the ONLY env var any WSDL module reads (transitively, via the debug layer). It gates
  the `Server`-fault detail: real cause when truthy, generic "Internal server error" otherwise. Default
  falsy = masked. There are NO `TINA4_WSDL_*` variables in any language.
- The WSDL endpoint URL is inferred from the request/host or passed explicitly to `generate_wsdl`;
  `targetNamespace` is `urn:{ServiceClassName}` in all four.

## Failures, side effects and security

- DTD / XXE / BILLION-LAUGHS is defended UNIFORMLY and is the reference-quality core: every language
  rejects a `<!DOCTYPE>` with a raw-string regex on the body BEFORE the parser runs (Python
  `wsdl/__init__.py:139`, PHP `WSDL.php:237`, Ruby `wsdl.rb:280` and a second guard at `:492`, Node
  `wsdl.ts:415`), returning a `Client` fault. Because a custom entity cannot be declared without a
  DOCTYPE, neither an external entity nor a recursive (billion-laughs) entity ever reaches the parser.
  The guard is LOAD-BEARING in Ruby (REXML expands internal entities) and defence-in-depth elsewhere
  (Node's hand-scanner has no entity machinery; Python's ElementTree and PHP's modern libxml resolve no
  external entities by default). This was PROVEN, not assumed: a live REXML 3.4.4 probe showed an
  external `SYSTEM` entity is NOT resolved (the reference stays literal, no file read), so the earlier
  audit's "CRITICAL file-XXE" is empirically FALSE in the one language whose parser was most suspect.
  All four ship real negative tests (the payload runs, the operation does not, no file leaks).
- FAULT MASKING is defended UNIFORMLY: an operation exception surfaces the real cause ONLY under
  `TINA4_DEBUG`; production returns a generic "Internal server error" and the real cause is logged.
  Real positive+negative tests in all four (e.g. a division-by-zero op masked in prod, leaked in debug).
- CLIENT vs SERVER is distinct: protocol errors (DOCTYPE, malformed XML, missing/empty Body, unknown
  operation) are `Client`; only an operation exception is `Server`. SHARED FOOTGUN (WSD-06): a bad-input
  conversion (non-numeric int/float) or a missing required parameter throws INSIDE the invoke and is
  caught as a `Server` fault, where a `Client` fault is semantically correct.
- CONTENT-TYPE is where Python is unsafe-by-omission (WSD-01): the Python module sets no content-type,
  so `response()` classifies the angle-bracket string as `text/html; charset=utf-8` and SOAP/WSDL ships
  as HTML - a strict SOAP client gating on `text/xml` breaks. PHP and Node set `text/xml; charset=UTF-8`
  explicitly; Ruby leaves it to the caller (documented `response.xml`).
- NO BUILT-IN AUTH: a WSDL service adds no authentication; the route's own auth gates it. The shipped
  examples are a mixed warning - Python's example is broken (subclass bug), PHP's example is a separate
  hand-rolled route using `noAuth()` + raw SQL (an injection footgun if copied).

## Wire and persistence contract

No persistence. The wire contract is SOAP 1.1: a request envelope (operation = first Body child, by
local name) and a response envelope `<{op}Response>` or a `<Fault>`. The response shape is the returned
map, NOT the declared schema (the schema is advisory - it shapes the WSDL `<types>` only). `faultcode`
is emitted BARE (`Client`/`Server`) in all four (Ruby's legacy path uses `soap:Server`), where SOAP 1.1
4.4 wants a qualified name (`soap:Client`) - WSD-05. Faults ship at HTTP 200 in Python and PHP (SOAP 1.1
prefers 500) - WSD-07. `SOAPAction` is advertised in the binding but never read on dispatch.

## Providers and substitutability

The engine is self-contained (no external SOAP/XML library in any language). A service class is the
substitution unit: any subclass with decorated operations becomes a WSDL endpoint. There is no provider
seam here (unlike the queue/cache/session clusters) - the "provider" is the app's own service class.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| WSD-01 | SECURITY/interop: Python ships SOAP and WSDL as `text/html; charset=utf-8` - the module sets no content-type, so `response()` auto-classifies the angle-bracket string as HTML (self-verified: `wsdl/__init__.py` sets none; `core/response.py:161-163`). PHP and Node set `text/xml; charset=UTF-8`; Ruby leaves it to the caller. A strict SOAP client gating on `text/xml`/`application/soap+xml` breaks against Python. | Python sets `text/xml; charset=UTF-8` on the WSDL and SOAP responses (in `handle`/`generate_wsdl` or the documented route). FIX PYTHON (do not mirror the HTML mis-typing). Ruby: set it in `handle` or keep the documented `response.xml`. |
| WSD-02 | Node WSDL does NOT serve over HTTP: nothing auto-mounts a `WSDLService`, and the provided `register()` helper is BROKEN against the framework's own Router (self-verified: `wsdl.ts:509` calls `router.addRoute("GET", url, handler)` with three positional args, but `Router.addRoute(definition)` at `router.ts:166` reads `definition.method` -> `"GET".method` is `undefined` -> TypeError; the Express-shaped `.get`/`.post` fallback is unreachable because the real Router has `addRoute`). Mirrors the inert Node GraphQL endpoint (GQL-01). Python/PHP/Ruby serve via manual route wiring that works. | Node fixes `register()` to pass a `RouteDefinition` object to `Router.addRoute` (or removes it in favour of documented manual wiring). Every language ships ONE correct, documented mount pattern and a WORKING example (fix Python's broken example; replace PHP's raw-SQL example). |
| WSD-03 | Array/repeated-element input is broken or absent everywhere: Python captures only ONE element (self-verified: `wsdl/__init__.py:190` breaks on the first matching child, then `:219` comma-splits that one element, so repeated `<Numbers>` collapse to `[1]`); PHP, Node and Ruby have NO array input at all (scalar-only). No WSDL advertises `maxOccurs`. | Pick one input-array contract (repeated elements -> list) and implement it uniformly, advertising `maxOccurs` in the generated `<types>`. |
| WSD-04 | Ruby ships TWO parallel APIs - the modern `WSDL` DSL and the legacy `WSDL::Service` builder - with DIFFERENT wire output (faultcode bare `Client`/`Server` vs hardcoded `soap:Server`; response element `<op>Response` vs `<tns:op>Response`; coercion + hooks modern-only). And Ruby's `method_added` types EVERY inferred input `:string` (`wsdl.rb:91`), so `convert_value`'s int/float/bool arms are unreachable via the DSL and the generated `<types>` always says `xsd:string` - the WSDL misrepresents the input contract. The other three have one API and derive input types from annotations. | Ruby removes/folds the legacy `Service` (one API), and infers real input types (or lets the DSL declare them) so coercion works and `<types>` is accurate. |
| WSD-05 | `faultcode` is emitted BARE (`Client`/`Server`) in all four modern paths (Ruby's legacy path uses `soap:Server`), where SOAP 1.1 4.4 requires a qualified name (`soap:Client`/`soap:Server`). A strict client may fail to classify a bare faultcode. | Emit qualified faultcodes (`soap:Client`/`soap:Server`) with the envelope prefix bound, uniformly in all four. |
| WSD-06 | SHARED FOOTGUN: a parameter conversion failure (non-numeric int/float) or a missing required parameter throws inside the invoke and is caught as a `Server` fault, where a `Client` fault is correct (it is a bad request). Confirmed Python/PHP/Node; Ruby is less exposed only because its coercion is dormant (WSD-04). | Convert parameters BEFORE invoking and classify a conversion / missing-required failure as a `Client` fault. |
| WSD-07 | Faults ship at HTTP 200 in Python and PHP (PHP: except empty-body 400), where SOAP 1.1 prefers HTTP 500 for a Fault. Node's serving path is broken (WSD-02) and Ruby's status is caller-applied, so neither controls it today. | Decide the fault HTTP status (500 for a Fault is the SOAP norm) and let the engine set it; requires `handle` to return a status, not a bare string, in Python/Ruby/Node. |
| WSD-08 | No `wsdl_contract.json`; no CONTRACT-MAP row; no ADR. The engine is proven per-framework (real no-mock tests: Python 63, PHP 44, Ruby ~110, Node ~61) but not by one oracle, and the HTTP-serving path is under-tested in all four (all tests call `handle` in-process; Ruby's specs even drive the `body` fallback, not the production `body_raw` path). | Add `wsdl_contract.json` gating generation, dispatch, type conversion, the DTD-reject, fault masking, and the mounted endpoint; add real HTTP-level coverage. |

## Owner decisions

Proposed for owner ratification. The security core and the fault-masking contract are settled parity;
the open calls are on the outer surface:

1. CONTENT-TYPE (WSD-01, interop): all four serve WSDL and SOAP as `text/xml; charset=UTF-8`. Python
   stops shipping `text/html` (fix Python). Headline correctness decision.
2. HTTP MOUNTING (WSD-02): fix Node's `register()` to the real Router contract (or drop it for documented
   manual wiring); every language ships one correct mount pattern + a working example. The WSDL analog
   of GQL-01.
3. FAULTCODE CONFORMANCE (WSD-05): emit qualified `soap:Client`/`soap:Server` in all four.
4. INPUT-ERROR CLASSIFICATION (WSD-06): a conversion / missing-required failure is a `Client` fault, not
   `Server`, in all four.
5. ARRAY INPUT (WSD-03): one repeated-element -> list contract, uniform, with `maxOccurs` advertised.
6. RUBY DUAL API (WSD-04): one API; real input typing so coercion works and `<types>` is accurate.
7. FAULT HTTP STATUS (WSD-07): decide 500-for-a-Fault; give the engine control of the status.
8. FIXTURE (WSD-08): add `wsdl_contract.json` and real HTTP-level tests.

## Proposed conformance fixture

Add `wsdl_contract.json` driving four runners against a real service over a real route (no mocks - the
suites already build real SOAP envelopes; extend them to an HTTP round-trip): `GET ?wsdl` returns a
well-formed WSDL with all five sections and `urn:{Class}` targetNamespace and `text/xml`; a valid SOAP
`POST` invokes the operation and returns `<{op}Response>` with the returned fields; a `<!DOCTYPE>`
payload (external-entity AND billion-laughs variants) returns a `Client` fault and the operation never
runs; malformed XML, a missing/empty Body and an unknown operation each return the right `Client` fault;
an operation that throws returns a `Server` fault masked to "Internal server error" and leaks the cause
only under `TINA4_DEBUG`; a bad numeric parameter returns a `Client` (not `Server`) fault; and the
faultcode is the qualified `soap:Client`/`soap:Server`. Assert the content-type (`text/xml`) and that a
mounted route actually serves - the two things every framework's tests miss today.

## Integration map

- A WSDL service is wired into a route by the developer (no auto-mount); the route's auth gates it; the
  debug layer gates fault masking via `TINA4_DEBUG`.
- `wsdl_contract.json` (owed) is the shared oracle; the DTD-reject + fault-masking contract mirrors the
  GraphQL (082) and XML-surface security posture and should be cross-referenced.
- The mount helper is the divergence point: Python/PHP/Ruby document manual wiring; Node's `register()`
  must be fixed to the Router contract (WSD-02).

## Breaking changes and migration

- WSD-01 changes Python's SOAP/WSDL content-type from `text/html` to `text/xml`: a client that somehow
  tolerated the HTML type is unaffected (XML body unchanged); a strict client starts working. Additive
  correctness; `Breaking:` only for a client that keyed on `text/html` (none should).
- WSD-05 changes the faultcode from bare `Client`/`Server` to `soap:Client`/`soap:Server`: a client
  parsing the bare code must read the qualified form. `Breaking:` for a client string-matching the bare
  faultcode.
- WSD-06 reclassifies a bad-input fault from `Server` to `Client`: a client keying on the fault class
  sees `Client` for a bad request. `Breaking:` for such a client (it was mislabelled before).
- WSD-02 (Node `register()` fix), WSD-03 (array input), WSD-04 (Ruby one API), WSD-07 (HTTP status) are
  additive or Node/Ruby-local; no conformant client breaks.

## Implementation backlog

1. Add `wsdl_contract.json` and wire four runners with real HTTP-level coverage (WSD-08).
2. Python: set `text/xml` (WSD-01, fix Python); fix the broken shipped example.
3. Node: fix `register()` to the Router contract and add HTTP-serving tests (WSD-02); replace PHP's
   raw-SQL example.
4. All four: qualified faultcodes (WSD-05); convert-before-invoke + `Client` classification (WSD-06);
   one array-input contract with `maxOccurs` (WSD-03).
5. Ruby: one API, real input typing (WSD-04). Decide the fault HTTP status (WSD-07). Run locally and on
   the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a zero-dependency SOAP 1.1 / WSDL engine: a service base class whose operations are declared
with a decorator/attribute/DSL carrying a response schema, discovered by reflection; `generate_wsdl`
building all five sections (types/message/portType/binding/service) as strings with `targetNamespace =
urn:{ClassName}`, `style="document"`, `use="literal"`; a `handle` that (1) runs `on_request`, (2)
rejects any `<!DOCTYPE>` via a raw-string regex BEFORE parsing (a `Client` fault - this closes
billion-laughs and XXE regardless of the parser), (3) parses the envelope, (4) resolves the operation
as the first `<Body>` child by local name, (5) binds and CONVERTS parameters by declared type
(int/float/bool/string, and repeated elements -> list), classifying a conversion / missing-required
failure as a `Client` fault, (6) invokes, runs `on_result`, and serializes the returned map (null ->
`xsi:nil`, arrays -> repeated, escaped scalars); an operation exception -> a `Server` fault whose detail
is the real cause only under `TINA4_DEBUG` (generic otherwise, real cause logged); qualified faultcodes
(`soap:Client`/`soap:Server`); a `text/xml; charset=UTF-8` content-type; and ONE working mount helper
that registers the service on the framework's real router. Prove the port with `wsdl_contract.json`:
generation, dispatch, conversion, DTD-reject, fault masking, content-type, and a mounted round-trip.

## Audit closure checklist

- [x] Boundary and public surface complete (engine + the HTTP-mounting divergence).
- [x] Lifecycle and every producer/consumer edge complete (hook/guard/parse/locate/bind/invoke/fault).
- [x] Configuration, failure, side-effect and security rules complete (DTD-reject, masking, content-type, auth).
- [x] Wire/storage and provider contracts complete (SOAP 1.1 request/response/Fault; the service class is the unit).
- [x] Existing-language contradictions recorded (WSD-01..08; the security core is parity, the outer surface diverges).
- [x] Owner ambiguities recorded (8 proposed; content-type and Node mounting are the keys).
- [x] Proposed shared cases and mutation witnesses complete (`wsdl_contract.json` over real routes, no mocks).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
