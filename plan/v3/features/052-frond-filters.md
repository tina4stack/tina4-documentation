# Feature 52: Frond filters

## Identity and status

- Matrix identity: 52 - Frond filters (`{{ x | upper }}`)
- Audit state: decision-ready
- Audit note: measured 2026-08-11 from four-language Frond source. 58 filters are shared across all four; the
  divergences are PHP's non-portable `|date`, PHP's `|join`/`|default` defaults, and 3 extra form-token alias
  filters in PHP+Node. Python `frond/engine.py:1268` (`46007c1`); PHP `Tina4/Frond.php:3207` (`ab871934`);
  Ruby `lib/tina4/frond.rb:2613` (`f549923`); Node `packages/frond/src/engine.ts:1369` (`1319cf3`).
- Dependencies: the runtime (51), auto-escape (57).
- Dependants: every filtered template value.
- Existing ADRs: the 72/72 expression-parity corpus.

- Catalog phase: Frond

## Why this feature exists

Filters transform a value in a template (`{{ x | upper | truncate(20) }}`). The audit question is vocabulary +
behaviour parity. The set is 58 shared (strong), but `|date` is not portable and a few PHP filter defaults
diverge.

## Existing implementation evidence

Measured, all four:

- 58 built-in filters are present in ALL FOUR (upper/lower/capitalize/title/trim/length/reverse/sort/first/
  last/join/split/replace/default/raw/safe/escape/e/striptags/nl2br/abs/round/int/float/string/json_encode/
  json_decode/to_json/tojson/js_escape/keys/values/merge/slice/batch/unique/map/filter/column/number_format/
  date/truncate/wordwrap/slug/md5/sha256/base64_encode/base64_decode/data_uri/url_encode/format/dump/form_token
  + spelling variants). Python 58, Ruby 58, PHP 61, Node 61.
- The 61-vs-58 delta: PHP + Node register 3 extra form-token ALIAS filters (`formToken`, `formTokenValue`,
  `form_token_value`); Python + Ruby expose only snake `form_token` as a filter (the others are call-only
  globals there - see feature 55).
- Filter chains parse `x|f1|f2("arg")` with POSITIONAL args, threaded through the SAME expression evaluator so
  a filtered value means the same inside `{{ }}` and `{% if %}`. The `|json_encode`/`|tojson` serializer is a
  uniform json-safe (`\u`-escape) model (feature 57).
- BEHAVIOURAL outliers, all PHP: `|date` feeds the format to native `date()` (PHP codes, default `Y-m-d`) while
  py/ruby/node use `strftime` (`%`-codes, default `%Y-%m-%d`); `|join` defaults the separator to `''` (PHP) vs
  `', '` (others); `|default` also treats boolean `false` as "use fallback" (PHP) vs keeps `false` (others).

## Public surface contract

`{{ value | filter(args) }}` transforms the value; the built-in vocabulary is shared; a custom filter is added
via `add_filter` (feature 56). Filter behaviour should be identical across the four (it is, except the PHP
outliers).

## Inputs and outputs

- Input: a value + a filter name + positional args. Output: the transformed value.

## Lifecycle and operation graph

1. Parse the pipe chain. 2. For each filter, evaluate args, call `filter(value, *args)`. 3. Thread through the
shared evaluator.

## Configuration and precedence

- None. Custom filters shadow built-ins (feature 56).

## Failures, side effects and security

- `|escape`/`|e`/`|raw`/`|tojson` are the XSS-relevant filters (feature 57). No other security surface. The
  `|date` divergence is a portability bug, not security. See the register.

## Wire and persistence contract

The filtered output IS the contract. No persisted state.

## Providers and substitutability

A future runtime must ship the 58 shared filters with identical behaviour, ONE `|date` convention, and the
same defaults.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| FILT-DATE-FORMAT-DIVERGE | `|date` is NOT portable: PHP feeds the format to native `date()` (PHP format codes, default `Y-m-d`, `Frond.php:3262`); Python/Ruby/Node use `strftime` (`%`-codes, default `%Y-%m-%d`). So `{{ d|date("Y-m-d") }}` renders `2026-08-11` in PHP but a literal-riddled string under strftime in the others, and `{{ d|date("%Y-%m-%d") }}` is the reverse. A template's date-format arg is NOT cross-language. | Pin ONE `|date` format convention across the four (strftime `%`-codes is the 3-of-4 majority) and gate it. |
| FILT-FORMTOKEN-ALIAS-GAP | PHP + Node register `formToken`/`formTokenValue`/`form_token_value` as pipe FILTERS; Python + Ruby register only snake `form_token` as a filter (the camelCase/`_value` variants are call-only globals there). So `{{ "x"|formTokenValue }}` renders in PHP/Node but silently no-ops in Python/Ruby. The 61-vs-58 delta. | Register the same form-token filter aliases in all four (or none - keep them globals-only). |
| FILT-JOIN-DEFAULT | PHP's `|join` defaults the separator to `''` (empty); Python/Ruby/Node default to `', '`. So `{{ list|join }}` differs. | Pin one `|join` default separator across the four. |
| FILT-DEFAULT-FALSE | PHP's `|default` treats boolean `false` as "use the fallback" (`Frond.php:3337`); Python/Ruby/Node keep `false`. So `{{ false|default("x") }}` is `x` in PHP and `false` elsewhere. | Pin the `|default` trigger set (null/empty, and whether `false` counts) across the four. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- FILT-DEC-01 (proposed): pin ONE `|date` format convention (FILT-DATE-FORMAT-DIVERGE) - the real portability
  bug (a date filter arg does not carry across languages).
- FILT-DEC-02 (proposed): reconcile the form-token filter aliases (FILT-FORMTOKEN-ALIAS-GAP) and the PHP
  `|join`/`|default` default outliers (FILT-JOIN-DEFAULT, FILT-DEFAULT-FALSE).

## Proposed conformance fixture

A shared fixture: the 58 shared filters produce identical output across the four; `{{ d|date(fmt) }}` renders
the same for the agreed convention (catches FILT-DATE-FORMAT-DIVERGE); `{{ list|join }}` and
`{{ false|default("x") }}` agree; a form-token alias filter behaves the same in all four.

## Integration map

- Consumers: every filtered value. Composes: the runtime (51), auto-escape (57, `escape`/`raw`/`tojson`),
  extensibility (56, custom filters). Related: the form-token filters (37/55).

## Breaking changes and migration

- Pinning `|date`, `|join`, `|default` changes output for those cases in the outlier language (PHP) - a
  correctness/portability fix; note it.

## Porting capsule

Ship the 58 shared filters with IDENTICAL behaviour, chained with positional args and threaded through the one
expression evaluator. Use ONE `|date` format convention (a date-format arg must be portable - the PHP
`date()`-vs-`strftime` split is the bug), one `|join` default separator, and one `|default` trigger set. Route
`|escape`/`|raw`/`|tojson` through the auto-escape model (57). Register form-token filter aliases consistently
(or keep them globals-only) across the four.

## Audit closure checklist

- [x] Boundary and public surface complete (58 shared filters x four).
- [x] Lifecycle and producer/consumer edges complete (parse chain -> apply).
- [x] Configuration, failure and security (escape filters) rules complete.
- [x] Wire (filtered output) and provider contracts complete.
- [x] Four-language behaviour recorded (58 shared; PHP date/join/default outliers; alias gap).
- [x] Owner ambiguities decided (FILT-DEC-01 date, FILT-DEC-02 aliases/join/default).
- [x] Conformance fixture (filter parity + date) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
