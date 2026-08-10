# Feature 087: Localization and i18n

## Identity and status

- Matrix identity: 87 - Localization and i18n
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the i18n/localization module in each repo)
  at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c`, Node `26be920`. The module source on the
  in-flight `feature/csrf-fail-closed` branches is byte-identical to `v3` (PHP's I18n.php last moved at
  "3.13.48: i18n parity hardening"). I self-verified the Python master's leaf-alias, the orphaned
  gettext catalogs, and the Python per-call-override thread-safety defect (I18N-01) against source. No
  framework code changed.
- Dependencies: the template engine (Frond auto-wires a `t` global), the core server (boot-time
  auto-wire), the dotenv layer (`TINA4_LOCALE`/`TINA4_LOCALE_DIR`)
- Dependants: any app with translated UI strings; templates calling `{{ t("key") }}`
- Existing ADRs: none specific to i18n. The parity contract (constructor order, leaf-alias, scalar
  coercion) was hardened in 3.13.48 without an ADR; this audit proposes the first (the i18n contract)
  plus the fixture.
- Shared fixtures: NONE. `i18n_contract.json` is owed (no fixture, no CONTRACT-MAP row). This is the
  most fixturable feature in the catalog (pure-logic, deterministic) and 3 of 4 already ship lock-in
  tests on the SAME contract (leaf-alias first-wins, no-clobber, scalar coercion, `(locale, path)`
  order) - the fixture would flip it to reference-quality-PROVEN cheaply.
- Catalog phase: Integrations

## Why this feature exists

An application needs translated UI strings without a heavy dependency. Tina4 ships a hand-rolled,
ZERO-DEPENDENCY i18n engine in every language: it loads per-locale JSON (or a zero-dep simple-YAML),
resolves a key with a leaf-alias convenience, interpolates named `{placeholder}` tokens, falls back
current -> default -> the key itself without ever crashing, and auto-wires a `t()` global into
templates. It localizes the APP's strings; the framework does not localize its own messages.

## Boundary

This feature owns the i18n ENGINE: the translation store, per-locale JSON/YAML loading, the key
resolver (dot-notation + leaf-alias), named interpolation, the fallback chain, locale selection, and
the Frond `t`-global auto-wire. It does NOT own framework-message localization - that does not exist
(the framework's own strings are hard-coded English in all four; Python's shipped gettext catalogs are
dead - I18N-07). The SQL translator is a different feature and is out of scope.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Zero-dep (stdlib JSON + hand-rolled/stdlib YAML) | yes | yes | yes | yes |
| Instantiable class (per-context instances) | yes | yes | NO (global module) | yes |
| Constructor `(locale, path)` order | yes (+legacy) | yes | n/a (module) | yes |
| JSON per-locale + simple-YAML loading | yes | yes | yes | yes |
| Dot-notation nesting + LEAF ALIAS (first-wins, no-clobber) | yes | yes | yes | yes |
| Named `{name}` interpolation, partial, never raises | yes | yes | yes | yes |
| Fallback current -> default -> key; no pluralization | yes | yes | yes (+`default:`) | yes |
| Scalar coercion (`true`->`"true"`, `42`->`"42"`) | yes | yes | yes | yes |
| Locale selection explicit > env > default; no Accept-Language | yes | yes | yes | yes |
| Per-call locale override WITHOUT mutating active locale | NO (mutates+restores) | yes | yes | yes |
| Framework localizes its own messages | no (dead .po) | no | no | no |
| `t` auto-wired into FROND | yes | yes | NO (legacy engine) | yes |
| Interpolation free of `$`/regex-injection hazards | yes | yes | yes | NO |
| Real no-mock tests | ~48 | 43 | 45 | 44 |

The CONTRACT (leaf-alias, interpolation, fallback, coercion, `(locale,path)`) is genuine four-way
parity - deliberately hardened, with lock-in tests in all four. The divergences are structural (Ruby is
a module; Ruby wires the wrong template engine), a concurrency defect in the Python master, and a Node
interpolation hazard.

## Public surface contract

An `I18n` instance (`new I18n(locale, path)`; Ruby uses the `Tina4::Localization` global module) exposes
`t(key, params)` (translate + interpolate; Python `t(**kwargs)` vs `translate(dict, locale)` are two
real methods), `setLocale`/`getLocale` (Python: a `locale` property), `loadTranslations(locale)`,
`addTranslation(locale, key, value)` (in-memory), and `availableLocales()`. Python adds module-level
`t()` + `set_default()` and the `_ = i18n.t` idiom; Ruby adds `Tina4.t`; PHP/Node are class-only
(I18N-04). Templates call the auto-wired global `{{ t("key") }}`.

## Inputs and outputs

- Input: a key (flat `home`, dotted `nav.home`, or a leaf alias `home` for `nav.home`), optional named
  interpolation params, an optional per-call locale override.
- Output: the translated string with `{name}` tokens substituted (missing tokens left literal), or - on
  a miss - the default-locale value, or the key itself. A JSON scalar (bool/number/null) is coerced to
  its string form. `availableLocales()` returns the locale stems found in the locale dir.

## Lifecycle and operation graph

1. LOAD: at construction the default locale loads eagerly; other locales load lazily on first
   `setLocale`/lookup. A file is read once and cached; a missing/malformed file caches an empty map.
2. FLATTEN: nested JSON/YAML is flattened to dotted keys, and each leaf also registers a bare-segment
   alias (first-wins; an explicit flat key is never overwritten).
3. RESOLVE: look up the key in the current locale; on a miss fall back to the default locale; on a
   miss return the key itself.
4. INTERPOLATE: substitute `{name}` tokens present in the params; leave a missing/malformed token
   literal; never raise.
5. AUTO-WIRE: at boot, if the app locale dir holds JSON, register a `t` global into the template engine
   (unless the app already registered one).

## Configuration and precedence

- `TINA4_LOCALE` (default `en`) - the default/active locale. Explicit constructor arg > env > `en`.
- `TINA4_LOCALE_DIR` (default `src/locales`) - the app locale directory. Explicit arg > env > default.
  Ruby searches a list (`locales`, `translations`, `i18n`, `src/locales`) when the env is unset.
- There is NO per-request `Accept-Language` negotiation in any framework; the locale is set by the app.

## Failures, side effects and security

- SILENT FAILURE is the shared footgun (all four): a missing key returns the key itself with no log; a
  missing/malformed locale file caches an empty map with no diagnostic, so a mistyped `TINA4_LOCALE` or
  a corrupt file yields a fully-untranslated app that looks like missing translations, not an error.
  Consistent across the four, but worth a debug-level log.
- THREAD-SAFETY (I18N-01): Python's per-call `translate(locale=)` MUTATES the instance's active locale
  and restores it in a `finally` (self-verified: `i18n/__init__.py:102-108`), opening a window where a
  concurrent `t()` on the same instance - or via the module-wide `_default` singleton behind the
  module-level `t()` - reads the wrong locale. PHP, Node and Ruby all resolve the override against a
  local without mutating. Python is the sole unsafe framework.
- LEAF-ALIAS AMBIGUITY (all four): when two branches share a leaf (`nav.title` vs `page.title`), the
  bare `t("title")` resolves to whichever flattened first (JSON key order). Convenient, but a silent
  precedence trap; the dotted form is the unambiguous escape hatch.
- NODE INTERPOLATION HAZARD (I18N-08): Node builds `new RegExp("\\{" + key + "\\}", "g")` and uses the
  param VALUE as the `String.replace` replacement, so a value containing `$&`/`$1` is treated as a
  replacement pattern and a key with regex metacharacters injects/breaks the pattern. The other three
  (`str_replace`, `re.sub` with a lambda, `gsub` with a block) have neither hazard. This is app-data
  driven (a translated value or a key), so it is a robustness/correctness bug.
- NO framework-message localization anywhere: `TINA4_LOCALE` selects the APP's locale only. Python
  ships six dead gettext `.po`/`.mo` catalogs (I18N-07) - nothing loads them (no `gettext` import; the
  msgids are stale vs current f-strings), and the env-doc claim that `TINA4_LOCALE` picks a framework
  message language is FALSE.

## Wire and persistence contract

No wire protocol; no persistence. The on-disk contract is a per-locale `{locale}.json` (an object,
arbitrarily nested) or a simple `{locale}.yml`/`.yaml` (one nesting level in Python/PHP/Node's
hand-rolled parser; Ruby uses stdlib YAML). Values are coerced to strings on load. The resolution
contract (dotted key, leaf alias first-wins, explicit-flat-never-clobbered, current->default->key
fallback, `{name}` partial interpolation) is uniform across the four and is what `i18n_contract.json`
should lock.

## Providers and substitutability

No provider seam - the "providers" are the app's locale files. The engine is self-contained (no i18n
library in any language: no `gettext`, `i18n` gem, `js-yaml`, or Babel). The template `t` global is the
integration point; an app can register its own `t` and the auto-wire steps aside.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| I18N-01 | CONCURRENCY, FIX PYTHON: Python's `translate(key, params, locale)` mutates the instance's active locale and restores it in a `finally` (`i18n/__init__.py:102-108`), a thread-unsafe window amplified by the module-wide `_default` singleton. PHP, Node and Ruby resolve the override against a local without mutating. The master is the broken one. | Python resolves `translate(locale=)` against the override locale WITHOUT mutating `_current_locale` (load-if-needed + a locale-scoped lookup, like the other three). FIX PYTHON; do not mirror the mutate/restore. |
| I18N-02 | STRUCTURAL: Ruby's `Tina4::Localization` is a process-global MODULE (singleton state, no constructor, no instances); Python/PHP/Node are instantiable classes. Ruby cannot hold two locale contexts in one process. | Owner decision: Ruby ships an instantiable `I18n` (matching the master) OR the module-singleton is ratified as the Ruby idiom with the concurrency limitation documented. |
| I18N-03 | FIX RUBY: Ruby auto-wires the `t` template global into the LEGACY `Tina4::Template` engine, NOT Frond (`lib/tina4.rb:875`). But `response.render` uses Frond in v3, so a v3 app template gets NO framework `t` - only the legacy `template:` route keyword has it. The other three wire `t` into Frond. | Ruby wires `t` into `Tina4::Frond.add_global` (matching Python/PHP/Node), so `response.render` templates get the framework `t`. |
| I18N-04 | Surface divergence: Python exposes module-level `t()` + `set_default()` + the `_ = i18n.t` idiom; Ruby exposes `Tina4.t`; PHP/Node are class-only. The convenience shortcut is inconsistent. | Owner decision: pin one module-level shortcut contract (a bare `t()` + a set-default) across all four, or drop it to class-only. |
| I18N-05 | Alias methods: Node's `translate()` is a pure alias for `t()`; PHP's `t()` aliases `translate()`; Ruby's `get_locale`/`add_translation`/`translate` are alias-shims; Python's `t(**kwargs)` vs `translate(dict, locale)` are DISTINCT. This collides with the no-alias rule but exists for cross-framework name parity. | Owner decision (parity vs no-alias): keep the two real methods (Python's model - `t` for kwargs, `translate` for a dict + per-call locale) as the canonical pair, and drop the pure aliases. |
| I18N-06 | Ruby extras/footguns: `t(key, default:)` adds a per-call default (a 4th fallback step) the others lack (additive); and its two setters are asymmetric - `current_locale=` sets the ivar WITHOUT loading, `set_locale` loads, so an assignment after boot silently key-falls-back for an unloaded locale. | Decide whether `default:` is part of the contract (add to all four or drop); make `current_locale=` load the locale like `set_locale`. |
| I18N-07 | Python ships six orphaned gettext `.po`/`.mo` catalogs (`translations/{af,en,es,fr,ja,zh}/LC_MESSAGES/`) that nothing loads (self-verified: no `gettext` import; msgids stale), and the env-doc claims `TINA4_LOCALE` picks a framework-message language - FALSE. Dead weight + doc drift. | Remove the dead catalogs and fix the Python CLAUDE.md `TINA4_LOCALE` line (framework messages are not localized). Python-only. |
| I18N-08 | FIX NODE: Node's interpolation uses the param value as a `String.replace` replacement (so `$&`/`$1` in a value misbehave) and injects the key into `new RegExp()` unescaped (a key with regex metacharacters breaks/injects). The other three are hazard-free. | Node escapes the key for the RegExp (or matches literally) and passes the value via a replacement FUNCTION, not a replacement string. |
| I18N-09 | Node's `TINA4_LOCALE`/`TINA4_LOCALE_DIR` are absent from the CLI `known_vars()` env surface (the env-uniformity source of truth). Minor. | Add both to the CLI `known_vars()`; confirm the other three are present. |
| I18N-10 | No `i18n_contract.json`; no CONTRACT-MAP row; no ADR. The contract is proven per-framework (real no-mock tests: ~48/43/45/44) but not by one oracle, despite being the most fixturable feature in the catalog. | Add `i18n_contract.json` gating leaf-alias (first-wins + no-clobber), fallback, `{name}` partial interpolation, scalar coercion, `(locale,path)` order, and explicit>env>default; wire four runners. |

## Owner decisions

Proposed for owner ratification. The resolution contract is settled parity; the open calls are the
three targeted bugs and the surface conventions:

1. THREAD-SAFETY (I18N-01, FIX PYTHON): the per-call locale override never mutates the active locale in
   any framework. Python adopts the local-resolve approach. Headline concurrency fix.
2. RUBY TEMPLATE WIRE (I18N-03, FIX RUBY): `t` is auto-wired into Frond so v3 `response.render`
   templates get it.
3. NODE INTERPOLATION (I18N-08, FIX NODE): escape the key, use a replacement function.
4. RUBY STRUCTURE (I18N-02): decide instantiable class vs ratified module-singleton.
5. SURFACE (I18N-04, I18N-05): pin the module-level shortcut and the `t`/`translate` method pair
   uniformly; drop pure aliases.
6. PYTHON DEAD CODE (I18N-07): remove the gettext catalogs and fix the doc.
7. RUBY EXTRAS (I18N-06): decide `default:`; fix the two-setter asymmetry.
8. FIXTURE (I18N-10) + ADR: add `i18n_contract.json` and the first i18n ADR ratifying the contract.

## Proposed conformance fixture

Add `i18n_contract.json` driving four runners against real on-disk locale files (no mocks - every
framework's suite already writes real temp JSON): a nested `{"nav":{"home":"Home"}}` resolves via BOTH
`nav.home` (dotted) AND `home` (leaf alias); a leaf collision resolves first-wins and an explicit flat
key is never clobbered by an alias; a missing key falls back current -> default -> the key itself; a
`{name}` token interpolates and a missing/malformed token (`{x.y}`, `{n:d}`, lone brace) is left
literal without raising; JSON scalars coerce (`true`->`"true"`, `42`->`"42"`, `null`->`"null"`); the
constructor honours `(locale, path)`; explicit args beat `TINA4_LOCALE`/`TINA4_LOCALE_DIR` which beat
the defaults; and a per-call locale override resolves without mutating the active locale (the I18N-01
witness - proves Python is fixed and the others stay safe).

## Integration map

- The core server auto-wires `t` into Frond at boot (Ruby must switch from the legacy engine - I18N-03);
  the dotenv layer supplies `TINA4_LOCALE`/`TINA4_LOCALE_DIR`.
- `i18n_contract.json` (owed) is the shared oracle; the CLI `known_vars()` must list the two env vars
  (I18N-09).
- Python's dead gettext catalogs and the false doc line are a cleanup edge (I18N-07), not an
  integration.

## Breaking changes and migration

- I18N-01 changes Python's `translate(locale=)` to not mutate the active locale: OBSERVABLE behaviour is
  unchanged for single-threaded callers (same return value); a caller that (incorrectly) relied on the
  side-effect of the active locale changing mid-call is corrected. Effectively non-breaking.
- I18N-03 gives Ruby `response.render` templates a `t` they did not have: additive.
- I18N-08 changes Node interpolation so `$`-bearing values insert literally: a value that happened to
  contain `$&` now renders literally instead of as a (broken) pattern - a fix, `Breaking:` only for a
  translation that depended on the buggy behaviour (none should).
- I18N-05 (drop pure aliases) would remove `translate`/`t` alias spellings in the frameworks that have
  them: `Breaking:` for a caller using the dropped spelling - migrate to the canonical method. Gate on
  the owner decision.

## Implementation backlog

1. Add `i18n_contract.json` and wire four runners (I18N-10); add the first i18n ADR.
2. Python: resolve the per-call override without mutating (I18N-01); remove the dead gettext catalogs
   and fix the doc (I18N-07).
3. Ruby: wire `t` into Frond (I18N-03); fix the two-setter asymmetry (I18N-06); decide the module vs
   class structure (I18N-02).
4. Node: escape-key + replacement-function interpolation (I18N-08); add the env vars to CLI
   `known_vars()` (I18N-09).
5. Settle the surface conventions (I18N-04, I18N-05); run locally and on the root lab, then flip
   owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a zero-dependency i18n engine: an instantiable `I18n(locale, path)` that loads per-locale
`{locale}.json` (or a simple `{locale}.yml`) from the app locale dir (default `src/locales`), the
default eagerly and others lazily, caching a missing/bad file as an empty map; flatten nested data to
dotted keys AND register a bare-leaf alias (first-wins, never clobbering an explicit flat key); resolve
a key current-locale -> default-locale -> the key itself; interpolate `{name}` tokens present in the
params and leave a missing/malformed token literal (never raise); coerce JSON scalars to strings;
select the locale explicit > `TINA4_LOCALE` > `en`; support a per-call locale override that resolves
WITHOUT mutating the active locale (thread-safe); and auto-wire a `t` global into the template engine
(Frond) at boot unless the app registered one. Do NOT localize framework messages. Prove the port with
`i18n_contract.json`: leaf-alias, fallback, partial interpolation, scalar coercion, constructor order,
env precedence, and the non-mutating override.

## Audit closure checklist

- [x] Boundary and public surface complete (the engine + the template-global wire; framework messages excluded).
- [x] Lifecycle and every producer/consumer edge complete (load/flatten/resolve/interpolate/auto-wire).
- [x] Configuration, failure, side-effect and security rules complete (silent-failure, thread-safety, interpolation hazard).
- [x] Wire/storage and provider contracts complete (per-locale JSON/YAML; the resolution contract).
- [x] Existing-language contradictions recorded (I18N-01..10; the contract is parity, the outliers are Python-concurrency and Ruby-structure).
- [x] Owner ambiguities recorded (8 proposed; thread-safety, the Ruby template wire, and the Node interpolation fix are the keys).
- [x] Proposed shared cases and mutation witnesses complete (`i18n_contract.json` over real files, no mocks).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
