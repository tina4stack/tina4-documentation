# Feature 057: Frond auto-escaping

## Identity and status

- Matrix identity: 57 - Frond auto-escaping
- Audit state: decision-ready
- Audit note: probed by execution 2026-07-28 with a live XSS payload; prose completed from that
  evidence 2026-08-10. Audited out of matrix order deliberately (it is a security control and the
  highest-risk part of the ADR-0009 split). No framework code changed.
- Dependencies: Feature 51 runtime (applies escaping on output), Feature 52 filters (`e`/`escape`/
  `js_escape`/`url_encode`/`css_escape`/`raw`/`safe`), Feature 49 parser
- Dependants: every `{{ x }}` in every template; the XSS defense of every Frond-rendered page
- Existing ADRs: ADR-0009 (removable Frond folder - escaping is its highest-risk piece); ADR-0005;
  the snake_case-filter-names rule (Feature 52)
- Shared fixtures: escaping cases added to `frond_expression_corpus.txt` BEFORE the ADR-0009 split
- Catalog phase: Frond template engine

## Why this feature exists

User data rendered into a page can carry a script. Auto-escaping neutralizes it: `{{ x }}` HTML-
escapes by default, so a `<script>` in a variable becomes inert text, and a template cannot be an
XSS vector unless the author EXPLICITLY opts out with `|raw`/`|safe`. This is the control that
prevents XSS, and it must behave identically in all four.

## Boundary

This feature owns escape-by-default, the explicit `|raw`/`|safe` opt-out, and the escape filters
and their mode argument (`|e`/`|escape` with `'js'`/`'url'`/`'css'`, plus `js_escape`/`url_encode`/
`css_escape`). It DELEGATES the filter registry to Feature 52, the apply-on-output to Feature 51,
and pipe parsing to Feature 49. It is the security control the ADR-0009 split must not break.

## Existing implementation evidence

| Evidence (probed with a live XSS payload) | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `{{ x }}` HTML-escapes by default | yes | BYTE-IDENTICAL | identical | identical |
| `|raw`/`|safe` opt-out (explicit) | yes | identical | identical | identical |
| Quotes/ampersands/angle brackets escaped | yes | identical | identical | identical |
| `|e('js')`/`('url')`/`('css')` mode arg | ACCEPTED, SILENTLY IGNORED (returns HTML escaping) | same | same | same |
| `js_escape` / `url_encode` filters exist | yes | yes | yes | yes |
| `css_escape` filter | MISSING | MISSING | MISSING | MISSING |

The best result in the whole audit: HTML escape-by-default is BYTE-IDENTICAL across all four -
`<script>alert(1)</script>` becomes `&lt;script&gt;...`, `He said "hi" & <b>` covers quotes and
ampersands too, and `|raw`/`|safe` opt out explicitly. Four independent implementations, zero
divergence, on the control that prevents XSS. The finding is the MODE ARGUMENT: the matrix
advertises html/js/css/url contexts, but `|e('js')`/`('url')`/`('css')` are accepted and SILENTLY
IGNORED - every context returns HTML escaping (documented in Python CLAUDE.md as "ignored, not an
error"). The real js/url capability exists under other names (`js_escape`, `url_encode`), and
`css_escape` does not exist at all.

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 3, row 6. **Planning only.**

**Status: CLOSED.** All four probed by execution with a live XSS payload.

Audited out of matrix order, deliberately: this is a **security control**, and
Features 48-50 flagged it as the highest-risk part of the ADR-0009 folder split. Knowing its
current state matters before anyone moves the code that decides what gets escaped.

### Note on the ADR-0009 split

Features 48-50 identified auto-escaping as the highest-risk part of the folder split.
This row's finding refines that: HTML escaping is provably identical across four
engines *today*, so the corpus can capture it exactly and the split becomes verifiable
rather than hoped-for. **Add the escaping corpus cases before the split, not after** -
that single sequencing choice removes most of the risk the split carries.

## Public surface contract

`{{ x }}` HTML-escapes by default. `{{ x|raw }}` and `{{ x|safe }}` render verbatim (the explicit,
only opt-out). `{{ x|e }}`/`{{ x|escape }}` escape HTML; a mode argument (`|e('js')`/`('url')`/
`('css')`) must produce CONTEXT-CORRECT output or raise, never silently HTML-escape.
`{{ x|js_escape }}`, `{{ x|url_encode }}` and (to be added) `{{ x|css_escape }}` do the
context-specific escaping. Filter names are snake_case, identical across four.

## Inputs and outputs

- Input: a value interpolated in `{{ }}`, and any escape filter/mode.
- Output: the HTML-escaped value by default; the verbatim value only under `|raw`/`|safe`; the
  context-escaped value under `js_escape`/`url_encode`/`css_escape` (or `|e('mode')` once modes
  are honest).
- The full character set is escaped (angle brackets, quotes, ampersands), not just `<`/`>`.
- A mode argument NEVER silently produces weaker (HTML) escaping than requested.

## Lifecycle and operation graph

1. The runtime resolves `{{ x }}` (Feature 51) and, unless the pipe is `raw`/`safe`, HTML-escapes
   the value before writing it.
2. An explicit `js_escape`/`url_encode`/`css_escape` applies the context escaping.
3. A mode argument on `|e`/`|escape` resolves to the right context escaper (resolution a) or a
   named error (resolution b) - never a silent HTML fallback.
4. The escaped bytes are written; the compiled and interpreted paths escape identically (Feature
   50).

## Configuration and precedence

- Escape-by-default is ON; the only way to render raw is the explicit `|raw`/`|safe`.
- A mode argument's resolution (implement modes vs reject loudly) is the owner decision below.
- Filter names are snake_case (Feature 52); the escape filters are `e`/`escape`/`js_escape`/
  `url_encode`/`css_escape`/`raw`/`safe`.

## Failures, side effects and security

- THE HAZARD (the reason this row exists): a mode argument (`|e('js')`) is accepted and SILENTLY
  HTML-escapes instead of JS-escaping. This is the one shape a security control must NEVER have -
  it accepts a request for STRONGER protection and quietly provides WEAKER. A developer writing
  `<script>var n='{{ userInput|e('js') }}'</script>` believes they have JS-context escaping and
  has HTML escaping, which does not neutralize a backslash, a newline, or a `</script>` sequence.
- HTML escape-by-default is correct and byte-identical; the ONLY change is to lock it with corpus
  cases so the ADR-0009 split cannot break it. Corpus BEFORE code, before the split.
- `|raw`/`|safe` is the only escape opt-out and is explicit; no other filter disables escaping.
- `css_escape` does not exist; the matrix claims a CSS context that is absent.

## Wire and persistence contract

There is no persistence; the contract is the ESCAPED OUTPUT, byte-identical across the four for
the HTML corpus (the strongest parity in the audit). A mode argument's output is context-correct
or the render errors; it is never silently HTML-escaped.

## Providers and substitutability

Escaping is pure string transformation and engine-agnostic. A future runtime escapes HTML by
default byte-identically, opts out only via `|raw`/`|safe`, and either implements the modes or
rejects a mode argument - never silently downgrades.

## Contradictions and defects

### The good news, and it is the best result in the audit

**HTML escaping is byte-identical in all four frameworks.** Same payload
(`<script>alert(1)</script>`) and the same quote/ampersand case through each engine:

| case | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| `{{ x }}` | `&lt;script&gt;alert(1)&lt;/script&gt;` | identical | identical | identical |
| `{{ x\|raw }}` | `<script>alert(1)</script>` | identical | identical | identical |
| `{{ x\|safe }}` | `<script>alert(1)</script>` | identical | identical | identical |
| `{{ x\|e }}` | `&lt;script&gt;alert(1)&lt;/script&gt;` | identical | identical | identical |
| `He said "hi" & <b>` | `He said &quot;hi&quot; &amp;amp; &lt;b&gt;` | identical | identical | identical |

Escape-by-default works. The `raw` / `safe` opt-out works and is explicit. Quotes and
ampersands are covered, not just angle brackets. Four independent implementations,
zero divergence, on the control that prevents XSS.

That is worth stating plainly because most of this audit has been findings: **this one
is correct, and it is correct in the way that matters most.**

### The finding: three of the four advertised contexts do not work as advertised

The matrix row is "Auto-escaping (**html / js / css / url**)". Only HTML behaves that
way. Verified with a payload that is harmless in HTML and dangerous inside a JavaScript
string literal (`x';alert(1);//`):

```
|e (no mode)    'x&#x27;;alert(1);//'
|e('js')        'x&#x27;;alert(1);//'      <- identical to no mode
|escape('js')   'x&#x27;;alert(1);//'      <- identical
|e('url')       'x&#x27;;alert(1);//'      <- identical
|e('css')       'x&#x27;;alert(1);//'      <- identical
```

**The mode argument is accepted and silently ignored.** Every context returns HTML
escaping. No error, no warning.

`tina4-python/CLAUDE.md` already documents this - "a mode arg like `|e('js')` is
**ignored** by Frond (not an error)" - so it is known. What the matrix does not
acknowledge is that this makes three of its four advertised contexts untrue.

**Why it is a security issue and not a cosmetic one.** HTML escaping does not make a
value safe inside a `<script>` block. A developer writing

```html
<script>var name = '{{ userInput|e('js') }}';</script>
```

is using what looks like Twig's context-escaping syntax, believes they have JS-context
escaping, and has HTML escaping. HTML escaping does not neutralise backslashes,
newlines, line separators, or a `</script>` sequence the way JS escaping must. The
failure is silent, and the syntax actively signals safety.

**The capability exists under other names.** The registry does contain:

```
js_escape      url_encode      escape      raw      safe
```

So `{{ v|js_escape }}` and `{{ v|url_encode }}` are real. What does not exist is
**CSS escaping** - there is no `css_escape` in the registry at all. So the matrix's
four contexts are really: html (works, and is excellent), js (works under a different
name), url (works under a different name), css (**does not exist**).

### Verdict: UNIFORM on HTML, GAP on the rest

Decided on **correctness**, and it splits two ways.

**HTML escaping: UNIFORM.** Nothing to change, and it should be locked with corpus
cases before the ADR-0009 split moves any of that code. This is the row's most
important output.

**Mode argument and CSS: GAP.** Category 4 - nothing runtime-related prevents any
framework from either implementing the mode or rejecting it.

### Risks

- **Resolution (b) is breaking** for any template using `|e('js')` - though those
  templates are *already* getting HTML escaping, so the breakage reveals a latent
  problem rather than creating one. That is an argument for (b) being safer than it
  looks.
- **Resolution (a) must not weaken HTML escaping** while adding modes. The corpus
  cases from step 1 are what make that check automatic.
- **Do not reorder steps 1 and 4.** Adding escaping corpus cases after touching
  escaping code means the safety net arrives after the risk.

## Owner decisions

Proposed for owner ratification:

1. HTML escape-by-default is UNIFORM and correct; LOCK it with escaping corpus cases (the XSS
   payload, quotes/ampersands, the `raw`/`safe` opt-out, a JS payload) BEFORE the ADR-0009 split
   moves any escaping code. This single sequencing choice removes most of the split's risk.
2. Resolve the mode argument (the security hazard): either (a) IMPLEMENT the modes (`|e('js')`->
   `js_escape`, `|e('url')`->`url_encode`, `|e('css')`->a new `css_escape`) so the Twig-shaped
   syntax is actually correct, or (b) REJECT the argument with a named error pointing at the right
   filter, and drop the html/js/css/url claim. Recommendation (a). The status quo - silently
   HTML-escaping a JS-context request - is not acceptable.
3. Add `css_escape` in all four regardless of (a)/(b); the matrix claims it and it does not exist.
4. Escape filter names stay snake_case (`js_escape`, `url_encode`, `css_escape`), identical in all
   four (Feature 52).
5. HTML escaping itself is NOT touched (it is correct); the only change is corpus coverage so the
   split cannot break it.

## Proposed conformance fixture

### Tests to write

Pure string rendering. No I/O, no DB - the cheapest tests in the programme and they
guard the most valuable behaviour.

| pair | positive | negative |
| --- | --- | --- |
| escape by default | `a_script_tag_in_a_variable_is_html_escaped` | `a_script_tag_is_never_rendered_unescaped_by_default` |
| opt-out is explicit | `raw_and_safe_render_the_value_verbatim` | `no_filter_other_than_raw_or_safe_disables_escaping` |
| full character set | `quotes_ampersands_and_angle_brackets_are_all_escaped` | `no_dangerous_character_survives_unescaped` |
| mode honesty | `an_escape_mode_argument_produces_context_correct_output` (resolution a) **or** `an_escape_mode_argument_raises_a_named_error` (resolution b) | `an_escape_mode_argument_is_never_silently_ignored` - the exact reproduction |
| js context | `js_escape_neutralises_a_quote_and_a_backslash` | `js_escape_output_cannot_break_out_of_a_string_literal` |
| css context | `css_escape_exists_and_neutralises_a_brace` | `no_framework_lacks_css_escape` |
| url context | `url_encode_percent_encodes_reserved_characters` | - |
| cross-framework | `all_four_produce_byte_identical_escaping_for_the_corpus` | `no_framework_escapes_a_character_the_others_leave_alone` |

The `an_escape_mode_argument_is_never_silently_ignored` negative is the one to write
first. It fails in all four today and it describes the actual hazard.

## Integration map

- Feature 51 applies escaping on output; Feature 52 holds the escape filters; Feature 49 parses
  the pipe; the ADR-0009 split moves this code and MUST have the escaping corpus first.
- The matrix row ("Auto-escaping (html/js/css/url)") and the docs are corrected in the same
  release as the resolution.
- Central fixtures, four runners, the CI matrix and the Frond security docs update together.

## Breaking changes and migration

- Resolution (b) is breaking for any template using `|e('js')` - but those templates are ALREADY
  getting HTML escaping, so the break reveals a latent XSS-shaped problem rather than creating one
  (an argument for (b) being safer than it looks). Resolution (a) is non-breaking (the mode starts
  working).
- Adding `css_escape` is additive.
- HTML escaping is unchanged; a template relying on escape-by-default is unaffected.

## Implementation backlog

### Methodology

1. **Corpus first, before any code and before the ADR-0009 split.** Add escaping cases
   to `frond_expression_corpus.txt` - the XSS payload, the quote/ampersand case, the
   `raw`/`safe` opt-out, and a JS-context payload. That file is already byte-identical
   in all four with one shared answer key, so the cases land once and gate everywhere.
2. Take the owner's decision on (a) versus (b).
3. Write the tests below. Expect red on every mode case in all four.
4. Implement, PHP or Python first (either is fine here - the change is small and the
   engines agree), then port.
5. **Fix the matrix row and the docs** in the same release: either the four contexts
   become true, or the claim goes.

## Porting capsule

### Pattern

**An escaping request either does what it says or fails loudly. It never silently
does something weaker.**

1. **`|e` / `|escape` with a mode argument must not silently HTML-escape.** Two
   acceptable resolutions, and the owner should pick:
   - **(a) Implement the modes.** `|e('js')`, `|e('url')`, `|e('css')` do real
     context escaping, delegating to the same code as `js_escape` / `url_encode` and
     a new `css_escape`.
   - **(b) Reject the argument.** `|e('js')` raises a named template error naming the
     correct filter: "escape() takes no mode argument; use |js_escape for JavaScript
     context". Then the docs and the matrix drop the html/js/css/url claim.

   **Recommendation: (a).** The capability already exists for two of three contexts, so
   (a) is mostly wiring plus one new filter, and it makes the Twig-shaped syntax a
   developer will reach for anyway actually correct. (b) is cheaper and safer to ship,
   but it leaves the framework advertising four contexts and providing one under that
   name.

   **What is not acceptable is the status quo**, because the current behaviour is the
   one shape a security control must never have: it accepts a request for stronger
   protection and quietly provides weaker.

2. **`css_escape` is added in all four**, whichever resolution is chosen - the matrix
   claims it and it does not exist.
3. **Filter names stay snake_case** per feature 51, so `js_escape`, `url_encode`,
   `css_escape` are canonical in all four.
4. **HTML escaping is not touched.** It is correct in all four; the only change is that
   it gains corpus coverage so the split cannot break it.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (HTML uniform; mode-arg silently-ignored; no css_escape).
- [x] Owner ambiguities recorded (the (a)-vs-(b) mode resolution is the open call; 5 proposed).
- [x] Proposed shared cases and mutation witnesses complete (the never-silently-ignored negative).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready. HTML escape-by-default is UNIFORM and correct (the best result in the audit)
- lock it with corpus cases BEFORE the ADR-0009 split. The open owner call is (a) implement the
`|e('mode')` escapes vs (b) reject the mode argument loudly; the status quo (silently HTML-escaping
a JS-context request) is not acceptable. `css_escape` is added regardless. Step 1 (corpus cases)
needs no decision and goes first. Decision-ready; the mode resolution and the build are not done.
