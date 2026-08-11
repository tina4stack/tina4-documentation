# Feature 57: Frond auto-escaping

## Identity and status

- Matrix identity: 57 - Frond auto-escaping
- Audit state: decision-ready
- Audit note: measured 2026-08-11 from four-language Frond source (part of the Frond-engine language sweep).
  Auto-escaping is ON by default in all four with a `SafeString` bypass; the one real divergence is the JSON
  filter's escaping model. Python `frond/engine.py:2342` (`46007c1`); PHP `Tina4/Frond.php:1239` (`ab871934`);
  Ruby `lib/tina4/frond.rb:1054` (`f549923`); Node `packages/frond/src/engine.ts:2552` (`1319cf3`).
- Dependencies: the runtime output path (51), the filter set (52).
- Dependants: every rendered variable; XSS safety.
- Existing ADRs: the boolean/json-escaping decisions ([[project_frond]] expression-parity work).

- Catalog phase: Frond

## Why this feature exists

Auto-escaping HTML-escapes every rendered variable by default so a template cannot emit an XSS vector unless
the author explicitly marks the value safe. The audit questions: is it on by default, is the escaped character
set the same, and does the JSON filter escape. On-by-default and the `SafeString` bypass are at parity; the
JSON filter uses a different (but deliberate) model in PHP.

## Existing implementation evidence

Universal, measured:

- ON BY DEFAULT in all four: Python `_eval_var_inner` html-escapes a `str` unless it is a `SafeString`
  (`engine.py:2342`); PHP `executeOutput` runs `htmlspecialchars($str, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')`
  unless SafeString/raw-marked (`Frond.php:1239-1255`); Ruby escapes at output (`frond.rb:1054`,
  `@auto_escape=true` `:295`); Node `htmlEscape` in `evalVarInner` (`engine.ts:2552`, `_autoEscape=true`
  `:1747`).
- `SafeString` BYPASS in all four (`engine.py:1292` `e`/`escape` return `SafeString`; PHP `SafeString.php`;
  Ruby `:21`; Node), plus `{% autoescape false %}...{% endautoescape %}` to toggle a block.
- The JSON filter (`|json_encode`/`|tojson`): PHP returns a RAW-marked value but pre-escapes the
  HTML-dangerous chars as `\uXXXX` (`< > & '` + U+2028/2029; `Frond.php:1350`); the other three HTML-escape.
  This is the deliberate Jinja2 `tojson` model (a prior parity decision, [[project_frond]]).

## Public surface contract

A rendered `{{ value }}` is HTML-escaped unless it is a `SafeString` or inside `{% autoescape false %}`. A
handler that needs raw HTML uses `|raw` / `SafeString`. This is the framework's primary XSS defense.

## Inputs and outputs

- Input: a value to render + the auto-escape flag. Output: the HTML-escaped string (or raw for SafeString).

## Lifecycle and operation graph

1. Evaluate the expression. 2. If auto-escape on and the value is a plain string (not SafeString), HTML-escape
it. 3. `|raw`/`|safe`/`SafeString` and `{% autoescape false %}` opt out.

## Configuration and precedence

- On by default; `{% autoescape false %}` blocks toggle it. `|raw`/`SafeString` per-value opt-out (sandbox may
  forbid `raw`). No env var.

## Failures, side effects and security

- SECURITY: this IS the XSS defense - escaping on by default is correct. The residual risks: the escaped
  CHARACTER SET must be the same in all four (a language that escapes fewer chars is a hole), and `|raw` /
  `SafeString` must be the only ways out. See the register.

## Wire and persistence contract

The escaped output IS the contract. No persisted state.

## Providers and substitutability

A future runtime must escape by default, escape the SAME character set, provide a SafeString/`|raw` opt-out,
and use the agreed JSON-filter model.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| AUTOESC-CHARSET-PARITY | The escaped CHARACTER SET is not gated identical across the four: PHP `htmlspecialchars(ENT_QUOTES|ENT_SUBSTITUTE)` escapes `& < > " '`; Python `html.escape` escapes `& < > " '`; Ruby/Node use their own `esc`/`htmlEscape`. Almost certainly the same 5 chars, but NOT proven by a shared fixture - and a language escaping fewer chars (e.g. missing the single quote in an attribute context) is an XSS hole. | Gate the exact escaped character set (`& < > " '` at minimum) identical across the four with a shared fixture. |
| AUTOESC-JSON-MODEL | The JSON filter escaping model diverges (deliberately): PHP `|json_encode`/`|tojson` returns a RAW-marked value that `\u`-escapes `< > & '` + U+2028/2029 (`Frond.php:1350`) - safe inside an HTML/script context but NOT entity-encoded; the other three HTML-escape the JSON string. A prior parity decision, but it means `{{ x|tojson }}` produces different bytes across languages. | Document the JSON-filter model as the agreed Jinja2 `tojson` behaviour, and pin it identical across the four (either all `\u`-escape like PHP, or all entity-encode). |
| AUTOESC-RAW-SANDBOX | `|raw`/`SafeString` are the escape hatch; under sandbox, `raw` must be forbidden unless allow-listed (Python gates it `engine.py:2335`; confirm PHP/Ruby/Node forbid `raw` in a sandbox). A sandbox that still honours `|raw` lets sandboxed template author emit XSS. | Confirm `raw`/`SafeString` are blocked in a sandbox in all four (cross-ref feature 58). |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- AUTOESC-DEC-01 (proposed): gate the escaped character set identical across the four (AUTOESC-CHARSET-PARITY)
  and pin the JSON-filter model (AUTOESC-JSON-MODEL). Both are XSS-adjacent parity items.
- AUTOESC-DEC-02 (proposed): confirm `|raw`/`SafeString` are forbidden under sandbox in all four
  (AUTOESC-RAW-SANDBOX; with feature 58).

## Proposed conformance fixture

A shared fixture (real render): `{{ "<script>'&\"" }}` escapes to the SAME output in all four (catches
AUTOESC-CHARSET-PARITY); a `SafeString`/`|raw` value renders unescaped; `{% autoescape false %}` disables it;
`{{ x|tojson }}` produces the agreed model; under sandbox `|raw` is refused.

## Integration map

- Consumers: every rendered variable. Composes: the runtime output (51), the filter set (52,
  `escape`/`raw`/`tojson`), the sandbox (58).

## Breaking changes and migration

- Aligning the JSON-filter model or the escaped char set changes output bytes for those cases - a correctness/
  security fix; note it.

## Porting capsule

HTML-escape every rendered variable by default (the same character set - at least `& < > " '`), with a
`SafeString`/`|raw` opt-out and a `{% autoescape false %}` block toggle. Under sandbox, forbid `raw`. Use ONE
agreed JSON-filter model (`|tojson`) across the four. Auto-escape-on-by-default is the primary XSS defense -
never make it opt-in.

## Audit closure checklist

- [x] Boundary and public surface complete (auto-escape + SafeString x four).
- [x] Lifecycle and producer/consumer edges complete (evaluate -> escape -> opt-out).
- [x] Configuration (on-by-default), failure and SECURITY (XSS) rules complete.
- [x] Wire (escaped output) and provider contracts complete.
- [x] Four-language behaviour recorded (on-by-default all four; json-model diverges).
- [x] Owner ambiguities decided (AUTOESC-DEC-01 charset/json, AUTOESC-DEC-02 raw-under-sandbox).
- [x] Conformance fixture (charset + json + raw) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
