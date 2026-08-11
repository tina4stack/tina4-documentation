# Feature 53: Frond tags

## Identity and status

- Matrix identity: 53 - Frond tags (block/structural tags)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language Frond source (correcting a prior-session doc claiming
  an unknown tag "LEAKS into output" - FALSE, all four RAISE - and per-language macro/set bugs that are
  STALE/fixed). Surfaced a UNIVERSAL security gap (no include/extends path confinement). Python
  `frond/parser.py:487` + `engine.py:2347` (`46007c1`); PHP `Tina4/Frond.php:657` (`ab871934`); Ruby
  `lib/tina4/frond.rb:154` (`f549923`); Node `packages/frond/src/engine.ts:47` (`1319cf3`).
- Dependencies: the parser (49) / interpreter (51).
- Dependants: template authors; inheritance; includes; macros.
- Existing ADRs: ADR-0005 (Frond tracks Twig/Jinja2, not Blade).

- Catalog phase: Frond

## Why this feature exists

Tags are the block/structural template syntax (`if`/`for`/`block`/`include`/`macro`/...). The audit questions:
is the tag set the same, does an unknown tag fail safely, and are `include`/`extends` paths confined. The tag
set is at parity (all four even share `spaceless`), an unknown tag RAISES in all four (the prior "leak" claim
is false), but NO language confines an include/extends path - a template traversal risk.

## Existing implementation evidence

Universal, measured:

- The tag set matches across the four: `if`/`elif`/`else`, `for`(+`else`), `set` (inline AND capture
  `{% set x %}...{% endset %}`), `extends`, `block`, `include` (+`with`/`ignore missing`), `macro`,
  `from...import`, `import...as`, `raw`, `cache`, `live`, `autoescape`, and `spaceless` - which the prior
  doc's tag LIST omits, though all four implement it.
- An UNKNOWN tag RAISES in all four (Python `parser.py:583`; PHP `Frond.php:733`; Ruby `frond.rb:868`; Node
  `engine.ts:2173`), fixed in 3.13.89. The prior doc's "unknown tag LEAKS into output (bug)" and its
  unverified cells are FALSE. (The raise is NOT positioned - no source line.)
- Set-capture, `import...as` (dotted `alias.name` macros), and macro default params all WORK in all four -
  the prior doc's per-language "bug" cells (set-capture bug, aliased-macro-silently-empty, macro-default bug)
  are STALE/fixed (Ruby proven by 342 green specs; PHP/Python/Node code-verified).
- `for...else` works in all four.
- NO include/extends PATH CONFINEMENT in any language: the template name is joined to the templates dir with
  no `..`/realpath/containment check (Python `engine.py:1793`; PHP `Frond.php:1025`; Ruby `frond.rb:654`;
  Node `engine.ts:1892`), so `{% include "../../etc/passwd" %}` resolves outside the dir.
- A SECOND `{% extends %}` is silently ignored (first wins), not an error, in all four.

## Public surface contract

The Twig/Jinja2 tag set (plus `spaceless`); an unknown tag is an error; `include`/`extends` resolve a template
by name (and must be confined - today they are not).

## Inputs and outputs

- Input: template source with tags. Output: rendered blocks; an error on an unknown tag.

## Lifecycle and operation graph

1. Dispatch each BLOCK token to its tag handler. 2. Unknown tag -> raise. 3. `include`/`extends` -> load
another template by name (unconfined today).

## Configuration and precedence

- A user `block` overrides a parent's; `include` merges context. No env var.

## Failures, side effects and security

- SECURITY (the crux): `include`/`extends` accept a path with no traversal guard in all four, so a template
  name containing `..`/an absolute path escapes the templates dir. Low risk when template names are static;
  a real risk if a name is ever built from user input. This is the template-side analogue of the static-asset
  symlink gap (feature 41). See the register.
- An unknown tag raises (safe), but unpositioned.

## Wire and persistence contract

No wire format; tags produce rendered output. Template files are read from the templates dir (unconfined).

## Providers and substitutability

A future runtime must implement the shared tag set (incl. `spaceless`), raise on an unknown tag, and CONFINE
include/extends paths under the templates dir.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| TAG-INCLUDE-TRAVERSAL | UNIVERSAL SECURITY: `include`/`extends` have NO path confinement in any language - the name is joined to the templates dir with no `..`/realpath/containment check (`engine.py:1793`, `Frond.php:1025`, `frond.rb:654`, `engine.ts:1892`), so `{% include "../../etc/passwd" %}` (or an absolute path) escapes the dir. Template-injection/traversal risk if a template name is ever attacker-influenced. | Confine include/extends paths (realpath under the templates dir; reject `..`/absolute) in all four - the template-side analogue of feature 41's static-asset fix. Highest-value Frond fix. |
| TAG-UNKNOWN-RAISES | RESOLVES the prior unverified/false-claim claim: an unknown tag RAISES in all four (`parser.py:583`, `Frond.php:733`, `frond.rb:868`, `engine.ts:2173`), fixed 3.13.89 - it does NOT "leak into output". POSITIVE parity, but the raise is NOT positioned. | Ratify raise-on-unknown-tag; add a source position (with LEX-DEC-01). |
| TAG-SECOND-EXTENDS-IGNORED | UNIVERSAL: a second `{% extends %}` is silently ignored (first wins), not an error, in all four (`engine.py:1854`, `Frond.php:1012`, `frond.rb:864`, `engine.ts:2169`). The prior doc's "single inheritance; a second extends is an error" is not the behaviour. | Make a second `{% extends %}` a (positioned) error in all four. |
| TAG-SPACELESS-OMITTED | All four implement a `spaceless` tag the prior doc's tag list omits (a doc completeness gap, not a code bug). | Add `spaceless` to the tag contract/list. |
| TAG-STALE-BUGS-FIXED | The prior doc's per-language bug cells (set-capture bug, aliased-macro-silently-empty, macro-default bug) are STALE - all fixed in all four (set-capture works, `import...as` registers `alias.name` macros, macro defaults parse). Do NOT re-flag as current. | Remove the stale bug claims from the doc. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- TAG-DEC-01 (proposed, SECURITY - highest value): confine `include`/`extends` paths under the templates dir
  (realpath + containment; reject `..`/absolute) in all four (TAG-INCLUDE-TRAVERSAL).
- TAG-DEC-02 (proposed): make a second `{% extends %}` a positioned error (TAG-SECOND-EXTENDS-IGNORED); add
  `spaceless` to the tag contract (TAG-SPACELESS-OMITTED); position the unknown-tag raise (with LEX-DEC-01);
  and strike the stale per-language bug claims (TAG-STALE-BUGS-FIXED).

## Proposed conformance fixture

A shared fixture (real render): `{% include "../../evil" %}` is REFUSED in all four (catches
TAG-INCLUDE-TRAVERSAL); an unknown tag raises; a second `{% extends %}` errors; `spaceless`, set-capture,
`import...as`, macro-defaults, and `for...else` all render identically across the four.

## Integration map

- Consumers: template authors, inheritance, includes, macros. Composes: the parser (49), the runtime (51),
  the template loader (shared with the cache, 59). The traversal fix shares feature 41's confinement pattern.

## Breaking changes and migration

- Confining include/extends paths can refuse a previously-served traversal (a security fix - note it). Erroring
  on a second `extends` changes behaviour for malformed templates. Both are correctness/security fixes.

## Porting capsule

Implement the Twig/Jinja2 tag set (if/for/set(+capture)/extends/block/include/macro/from-import/import-as/raw/
cache/live/autoescape/spaceless); RAISE (positioned) on an unknown tag - never leak it; make a second
`{% extends %}` an error; and CONFINE `include`/`extends` paths under the templates dir (realpath + containment,
reject `..`/absolute) - the one security-critical property, unmet in all four today.

## Audit closure checklist

- [x] Boundary and public surface complete (tag set + include/extends x four).
- [x] Lifecycle and producer/consumer edges complete (dispatch -> handler -> load).
- [x] Configuration, failure (unknown-tag raise) and SECURITY (traversal) rules complete.
- [x] Wire (rendered output) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (all raise on unknown; spaceless everywhere; stale bugs fixed).
- [x] Owner ambiguities decided (TAG-DEC-01 security traversal, TAG-DEC-02 second-extends/spaceless).
- [x] Conformance fixture (traversal refusal + tag parity) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
