# Feature 107: HTML element builder

## Identity and status

- Matrix identity: 107 - Programmatic HTML element builder (build HTML in code, escape by default, avoid
  string concatenation)
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-11 at Python `HtmlElement.py` (149), PHP
  `Tina4/HtmlElement.php` (234) + `SafeString.php`, Ruby `lib/tina4/html_element.rb` (218), Node
  `packages/core/src/htmlElement.ts` (231). Escaping was checked char-by-char in each. Suites reported,
  not re-run.
- Dependencies: the language's escaping primitive (`html.escape` / `htmlspecialchars` / a hand-rolled
  gsub / hand-rolled replaces) and a `Raw`/`SafeString` trusted-markup marker.
- Dependants: application code only. No framework subsystem renders through it (error overlay, dev-admin,
  Swagger UI, and CRUD all build HTML by other means).
- Existing ADRs: none.
- Shared fixtures: NONE. `html_element_contract.json` is owed. Each language has a real, no-mock suite
  with dedicated XSS lock-ins (Python 41, PHP ~50, Ruby 33, Node 36), and the PHP/Node/Ruby test headers
  explicitly say "parity with the Python master" - but the exact escaped output differs (HTML-ESCAPE-
  OUTPUT), so no shared oracle would pass as-is.

- Catalog phase: Developer internals

## Why this feature exists

The builder lets you assemble HTML in code without string concatenation and without hand-escaping. You
create an element with a tag, attributes, and children; every attribute value and text child is escaped
by default, so a user-supplied string cannot inject markup. When you genuinely have trusted HTML, you
wrap it in `Raw` (aliased `SafeString`) to opt out. It is the safe, boring way to emit a fragment of
HTML from a route or a helper.

It is deliberately small and app-facing. The framework does not use it internally; it is a tool offered
to application developers, escape-by-default so the easy path is the safe path.

## Boundary

This packet owns the element class/builder, the `Raw`/`SafeString` marker, the escaping of attribute
values and children, the void-tag set, and the `_<tag>` helper injector in each language.

It does NOT own: the template engine Frond (which has its own, separate `SafeString`); the error overlay
and dev-admin HTML (built by other means); the application code that consumes the builder. The `Raw` /
`SafeString` marker is shared in spirit with Frond's raw-output concept but is a distinct type in every
language (Ruby aliases Frond's class; the others define their own).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Class name | `HTMLElement` | `HtmlElement` | `Tina4::HtmlElement` | `HtmlElement` |
| Builder mechanism | `__call__` (class) | `__invoke` (class) | `call` (class) | callable factory `htmlElement()` |
| Render | `str(el)` (`__str__`) | `(string)$el` (`__toString`) | `to_s` | `toString()` |
| Escaper | `html.escape(quote=True)` | `htmlspecialchars(ENT_QUOTES, UTF-8)` | hand-rolled gsub | `escapeAttr` + `escapeText` (context-specific) |
| Escapes single-quote | yes (`&#x27;`) | yes (`&#039;`) | yes (`&#x27;`) | no (attrs double-quoted, so safe) |
| Children escaped by default | yes | yes | yes | yes |
| Void tag set | 14 (identical) | 14 (identical) | 14 (identical) | 14 (identical) |
| Focused tests | 41 real | ~50 real | 33 real | 36 real |

## Public surface contract

The shared surface: construct `Element(tag, attrs, children)`; a builder call that adds attributes (a
map arg) and children (a list arg is spread, anything else is appended) and returns a NEW element
(immutable in all four); a render to string; a `Raw` / `SafeString` marker for trusted markup; and an
`add_html_helpers` injector that installs `_<tag>` factory helpers (over a ~110-tag list) into a caller
namespace. Void tags render with no closing tag and no self-closing slash (HTML5 style); their children
are ignored. Boolean attributes render as a bare name when true and are omitted when false/null.

The surface diverges in spelling: the builder is `__call__` (Python), `__invoke` (PHP), `call` (Ruby),
or a callable closure returned by `htmlElement()` (Node, the one non-class builder); render is
`__str__` / `__toString` / `to_s` / `toString`. The class name is `HTMLElement` in Python and
`HtmlElement` elsewhere (HTML-NAMING). All are immutable builders.

## Inputs and outputs

- Construct / build input: a tag string, an attributes map, and children (elements, strings, numbers,
  `Raw`). Output: an element that renders to an HTML string.
- Render output: the HTML string. Attribute values and text children are escaped; `Raw`/`SafeString`
  children and nested elements are emitted as-is (no double-escape).
- The EXACT escaped output differs across languages (HTML-ESCAPE-OUTPUT): Python, PHP, and Ruby escape
  all five of `& < > " '` in both attribute values and text; Node escapes `& " < >` in attribute values
  and `& < >` in text (no quote-escaping in text, no single-quote in attributes). All are secure; the
  bytes differ.
- A nullish child renders differently (HTML-NULLCHILD): literal `None` (Python) / `null`/`undefined`
  (Node) versus empty string (Ruby, PHP).

## Lifecycle and operation graph

1. Construct an element or call a helper.
2. The builder call classifies each argument: a map merges into attributes, a list spreads into
   children, anything else appends as one child; it returns a new element.
3. Render walks attributes (escaping values, emitting boolean-true as a bare name, omitting false/null)
   then children (nested elements self-render, `Raw` emits unescaped, everything else is escaped).
4. A void tag short-circuits after the attributes with `>` and no children.

There is no persistence, no configuration, and no framework lifecycle involvement.

## Configuration and precedence

The builder reads NO environment variables in any language. Escaping is unconditional (never gated on a
debug flag). There is nothing to configure.

## Failures, side effects and security

- Escape-by-default is the security contract, and it holds in all four: attribute values (double-quoted)
  and text children are escaped so a user string cannot inject markup or break out of an attribute. The
  single-quote is covered where it matters (Python/PHP/Ruby escape it; Node relies on double-quoting, so
  a `'` in a value is inert). No XSS hole on the value or text axis in any language.
- HTML-KEY (universal, low risk): attribute NAMES/keys are NOT escaped in any of the four, and tag names
  are not validated (only lowercased). Attribute names and tags are developer-controlled in idiomatic
  use, but code that derives an attribute name or tag from user input has an injection vector. Untested
  everywhere.
- `Raw`/`SafeString` is an intentional opt-out: wrapping a string emits it unescaped. That is the
  designed escape hatch, and the ordering (check `Raw` before the generic escape) is correct in all four
  (important because `Raw` subclasses the string type in Python/Ruby).
- Nullish children are not dropped in Python (`None`) or Node (`null`/`undefined`); they render as literal
  text. Ruby and PHP render them as empty. This is a correctness/parity wart, not a security issue.
- No other side effects: the builder touches no filesystem, network, or global state.

## Wire and persistence contract

The output is an HTML string; there is no persisted format. The escaping approach determines the exact
bytes and is NOT uniform (HTML-ESCAPE-OUTPUT). The void-tag set (14 tags) and the boolean-attribute
rules (true -> bare name, false/null -> omitted) are identical across the four.

## Providers and substitutability

There is no external provider. Each builder is self-contained over the language's escaping primitive.
The `Raw`/`SafeString` marker is the only substitution seam (trusted vs untrusted markup). No dependency
is added in any language.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| HTML-ESCAPE-OUTPUT | The exact escaped output differs. Python, PHP, and Ruby escape all five `& < > " '` in both attribute values and text; Node uses context-specific escapers (`& " < >` in attributes, `& < >` in text). All are secure and render identically in a browser, but the byte output differs, so a single conformance fixture cannot pass all four. | OWNER DECISION (HTML-DEC-01). Recommendation: pick one canonical escaping for the fixture. Node's context-aware approach is technically more correct (it does not over-escape quotes in text or single-quotes in double-quoted attributes), but the uniform 5-char escape matches 3-of-4 and is simpler to specify. Ratify one and align the others; either way it is a byte-output change, not a security change. |
| HTML-NULLCHILD | A nullish child renders as literal `None` (Python) / `null` or `undefined` (Node), but as empty string in Ruby and PHP. | FIX Python and Node to DROP a nullish child (render nothing), matching Ruby and PHP. Add a nullish-child regression in all four. |
| HTML-KEY | Attribute NAMES/keys are not escaped, and tag names are not validated, in ANY language (only values are escaped). Low risk (developer-controlled), untested everywhere. | OWNER DECISION (HTML-DEC-03, low priority): either escape/validate attribute names and tag names (reject a name with whitespace or an angle bracket/quote) in all four, or ratify that names and tags are developer-controlled and out of the escape contract. Recommendation: validate names/tags cheaply (reject the dangerous characters) since it closes the last unescaped path. |
| HTML-KWARGS | Python only: `add_html_helpers` installs a lambda that forwards `**kwargs` to `_make_element`, which accepts no keyword arguments, so `_div(id="x")` (or the reserved-word workaround `_label(for_="x")`) raises `TypeError`. The kwargs path is dead and untested; only dict-attr calls work. | FIX Python: either make `_make_element` accept and fold `**kwargs` into attributes (with the trailing-underscore reserved-word convention), or drop `**kwargs` from the lambda so the signature does not promise what it cannot do. Add a helper-with-kwargs test. |
| HTML-NAMING | The class is `HTMLElement` in Python but `HtmlElement` in PHP, Ruby, and Node. | Low priority. Align on one casing (the 3-of-4 `HtmlElement`) or document the Python alias; a Python alias `HtmlElement = HTMLElement` avoids a breaking rename. |
| HTML-FIXTURE | No `html_element_contract.json`, no CONTRACT-MAP row, no ADR. Four real suites with parity-intent headers but demonstrably different output (HTML-ESCAPE-OUTPUT, HTML-NULLCHILD). | Add `html_element_contract.json` once HTML-DEC-01/02 fix the output, and the first HTML-builder ADR. |

## Owner decisions

- HTML-DEC-01 (proposed): ratify one canonical escaping (context-aware or uniform 5-char) so the output
  is byte-identical; align the others.
- HTML-DEC-02 (proposed): drop nullish children uniformly (fix Python and Node).
- HTML-DEC-03 (proposed, low priority): validate/escape attribute names and tag names, or ratify them as
  out of the escape contract.
- HTML-DEC-04 (proposed): fix the Python `add_html_helpers` kwargs path.

## Proposed conformance fixture

`html_element_contract.json` - the same construct/render cases per language, asserting the ratified
canonical output (no mocks; pure construct-then-render):

- Basic render, nesting, multiple children, empty element.
- Void tags (br, img, input, hr, meta, link) render with no closing tag and no slash; children ignored.
- Boolean attribute true -> bare name; false/null -> omitted.
- Attribute value escaping incl. a `"` and a `<` (and a `'`, per HTML-DEC-01).
- Text child escaping incl. `<script>` -> entity (asserts no live tag), per the ratified output.
- `Raw`/`SafeString` child renders unescaped; nested element does not double-escape.
- Nullish child (HTML-NULLCHILD witness): renders nothing (fails on current Python and Node).
- Helper `_div`, `_br`, and (per HTML-DEC-04) `_div` with an attribute passed the idiomatic way.
- Immutable builder: a builder call returns a new element and does not mutate the original.
- Attribute-name safety (HTML-KEY witness, per HTML-DEC-03): a hostile attribute name is rejected or
  escaped.

## Integration map

- Exports: each language exports the element class/builder, `Raw`/`SafeString`, and `add_html_helpers`
  (Ruby also an `HtmlHelpers` mixin; Node also the `htmlElement` factory).
- Framework use: NONE. No internal subsystem renders through the builder - uniform across all four and
  intentional.
- CLI / startup / request lifecycle: no involvement.
- Documentation: the CLAUDE.md HTML-builder sections advertise "XSS-safe by default", which is true for
  attribute values and text but not attribute names (HTML-KEY); note that boundary.

## Breaking changes and migration

- HTML-DEC-01 (canonical escaping): whichever way it resolves changes the exact output for at least one
  language; any test asserting exact escaped strings would update. No behavioural (browser-rendered or
  security) change. Document the one-line note.
- HTML-NULLCHILD: Python and Node stop emitting `None`/`null` for a nullish child. Only code that relied
  on that literal (none should) is affected.
- HTML-KWARGS: additive (kwargs start working) or a signature cleanup - non-breaking either way.
- No persistence migration.

## Implementation backlog

Dependency-ordered:

1. Settle HTML-DEC-01 (canonical escaping) and write the first HTML-builder ADR (escaping, nullish
   children, name-safety, the Raw contract).
2. Align the output: apply the ratified escaping, drop nullish children (Python, Node), fix the Python
   kwargs helper, and add the Python `HtmlElement` alias.
3. Author `html_element_contract.json` and a runner per language; flip owed to proven; add the
   CONTRACT-MAP row.
4. Low priority: validate/escape attribute names and tag names per HTML-DEC-03.

## Porting capsule

A clean-room implementation needs: an immutable element of `{tag (lowercased), attrs, children}`; a
builder call that merges a map arg into attributes, spreads a list arg into children, and appends
anything else, returning a new element; a render that escapes attribute values (double-quoted) and text
children per the ratified canonical escaping, emits a boolean-true attribute as a bare name and omits
false/null, drops nullish children, and emits nested elements and `Raw`/`SafeString` unescaped (checking
`Raw` before the generic escape); the 14-tag void set (render `>` and stop); and an `add_html_helpers`
injector installing `_<tag>` factories over the ~110-tag list. Attribute names and tags should be
validated or escaped. This packet is sufficient for a clean-room implementation once HTML-DEC-01/02 are
settled.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
