# Feature 37: Auto-escaping (html / js / css / url)

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 3, row 6. **Planning only.**

**Status: CLOSED.** All four probed by execution with a live XSS payload.

Audited out of matrix order, deliberately: this is a **security control**, and feature
28-31 flagged it as the highest-risk part of the ADR-0009 folder split. Knowing its
current state matters before anyone moves the code that decides what gets escaped.

## The good news, and it is the best result in the audit

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

## The finding: three of the four advertised contexts do not work as advertised

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

## Verdict: UNIFORM on HTML, GAP on the rest

Decided on **correctness**, and it splits two ways.

**HTML escaping: UNIFORM.** Nothing to change, and it should be locked with corpus
cases before the ADR-0009 split moves any of that code. This is the row's most
important output.

**Mode argument and CSS: GAP.** Category 4 - nothing runtime-related prevents any
framework from either implementing the mode or rejecting it.

## Pattern

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
3. **Filter names stay snake_case** per feature 32, so `js_escape`, `url_encode`,
   `css_escape` are canonical in all four.
4. **HTML escaping is not touched.** It is correct in all four; the only change is that
   it gains corpus coverage so the split cannot break it.

## Methodology

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

## Tests to write

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

## Risks

- **Resolution (b) is breaking** for any template using `|e('js')` - though those
  templates are *already* getting HTML escaping, so the breakage reveals a latent
  problem rather than creating one. That is an argument for (b) being safer than it
  looks.
- **Resolution (a) must not weaken HTML escaping** while adding modes. The corpus
  cases from step 1 are what make that check automatic.
- **Do not reorder steps 1 and 4.** Adding escaping corpus cases after touching
  escaping code means the safety net arrives after the risk.

## Note on the ADR-0009 split

Feature 28-31 identified auto-escaping as the highest-risk part of the folder split.
This row's finding refines that: HTML escaping is provably identical across four
engines *today*, so the corpus can capture it exactly and the split becomes verifiable
rather than hoped-for. **Add the escaping corpus cases before the split, not after** -
that single sequencing choice removes most of the risk the split carries.

## Parked

Not implemented. Blocked on the owner's (a)-versus-(b) decision. Step 1 (corpus cases)
needs no decision and should go first regardless.
