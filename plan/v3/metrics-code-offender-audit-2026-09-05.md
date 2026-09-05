# Metrics code-offender audit — 2026-09-05

## Outcome

Measure code health in Python, PHP, Ruby, and Node.js with one Tina4 Metrics
engine. Exclude example applications. Classify every offender before changing
code. Fix proven design debt at parity, then enforce the improved baseline in
CI without forcing the existing debt to disappear in one release.

This plan covers the active `v3` branches. It does not audit tina4-js, the Rust
client, generated bundles, or example applications.

## Scope

- [x] Run the native Tina4 Metrics client against all four framework roots.
- [x] Exclude `example/` and `examples/` trees with repeatable `--exclude` globs.
- [x] Confirm zero example offenders, zero refused files, and record the baseline.
- [ ] Re-run a core view excluding Dev Admin, galleries, generated assets, tests,
  declarations, dependencies, caches, and build output.
- [ ] Classify every error and warning as real debt, intentional complexity,
  duplicate protocol shape, generated/non-production code, or engine false positive.
- [ ] Compare the same subsystem in all four languages before selecting a fix.
- [ ] Write characterisation tests before each behaviour-preserving refactor.
- [ ] Fix the highest-value subsystem at parity, led by the strongest implementation.
- [ ] Re-measure after each change and record before/after evidence.
- [ ] Add a CI gate that blocks new regressions while grandfathering the current baseline.
- [ ] Re-run complete framework suites on the Linux lab as root.
- [ ] Update the metrics plan, feature matrix, and release notes after acceptance.

## Baseline: full framework source, examples excluded

Command shape:

```bash
tina4 metrics --path <framework-root> --json --top 10000 \
  --exclude 'example/**' --exclude 'examples/**' \
  --exclude '**/example/**' --exclude '**/examples/**' --no-history
```

| Framework | Files | Functions | Avg CC | Avg MI | Offenders | Duplicate blocks | Duplicate lines | Refused | Example offenders |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Python | 125 | 3,027 | 3.97 | 27.5 | 354 | 23 | 198 | 0 | 0 |
| PHP | 188 | 3,495 | 3.61 | 35.8 | 434 | 81 | 838 | 0 | 0 |
| Ruby | 137 | 4,769 | 2.72 | 29.5 | 280 | 24 | 238 | 0 | 0 |
| Node.js | 163 | 3,956 | 3.26 | 31.0 | 411 | 70 | 754 | 0 | 0 |

These totals include framework Dev Admin source because the request covers each
framework root. They do not include the repositories' `example/` trees. The
core view below prevents Dev Admin and generated or non-production code from
distorting the framework comparison.

## Initial priority signals

The ranking is a work order, not permission to split code blindly. A single
file can raise several signals, and a high score may describe a deliberate
parser or protocol boundary.

| Priority | Evidence | First review targets |
| --- | --- | --- |
| P0 | Very high cyclomatic complexity | Node.js Frond `evalVarInner` 76; Node.js `resolveVar` 62; Python `ORM.create_table` 60; PHP `Docs.parseSource` 57; PHP `Frond.findMathOp` 50 |
| P1 | Low maintainability in large core modules | Python ORM, CLI, Dev Admin, AI client; PHP Frond, Docs, AI, API; Node.js Docs and AI client |
| P1 | Large duplicate bodies | PHP testing/database adapters: 838 duplicate lines; Node.js adapter/core code: 754; Ruby and Python require targeted review rather than a bulk split |
| P2 | Complex migration, middleware, ORM, and seeder paths | Python `ORM.save`, Frond resolver, migration splitter; Ruby migration and Frond; Node.js migration and BaseModel |
| P2 | Test and tooling code inside framework roots | PHP `TestSkippedSubscriber.php` and framework Dev Admin; classify before refactoring because test infrastructure has different constraints |

## Core comparison

The second scan will use explicit exclusions for the same non-core classes in
each language. The exact paths must be recorded from the source tree before the
scan; do not assume that a Python path maps byte-for-byte to another language.

| Exclusion class | Python | PHP | Ruby | Node.js |
| --- | --- | --- | --- | --- |
| Dev Admin runtime | `**/dev_admin/**` | `**/DevAdmin.php`, security middleware | `**/dev_admin.rb` | `**/devAdmin.ts` |
| Examples | `**/example/**` | `**/example/**` | `**/example/**` | `**/example/**` |
| Generated/minified assets | Metrics defaults plus explicit bundle paths | Metrics defaults plus explicit bundle paths | Metrics defaults plus explicit bundle paths | Metrics defaults plus explicit bundle paths |
| Tests/specs/declarations | Metrics production defaults | Metrics production defaults | Metrics production defaults | Metrics production defaults |

The core table is accepted only when all four scans report zero refused files
and the JSON contains no legacy `has_tests` field.

## Triage rules

For every offender, record one decision:

1. **Real design debt:** split or simplify it with no public behaviour change.
2. **Intentional complexity:** retain it and add a short source comment plus a
   regression or contract test that explains the boundary.
3. **Cross-language duplication:** compare the four implementations and adopt
   the clearest proven design under ADR-0004.
4. **Generated or non-production code:** correct the scan boundary instead of
   changing the generated output.
5. **Metrics false positive:** reproduce with a focused fixture, then fix the
   native engine or its language provider before changing framework code.

No offender is removed because of its score alone. A refactor must preserve
the public API, response bytes, error semantics, resource bounds, and language
parity.

## Remediation sequence

### Phase 0 — Freeze and reproduce

- [ ] Record the Tina4 client version and active `v3` commit for each repository.
- [ ] Save the full JSON totals and the core JSON totals as audit evidence.
- [ ] Confirm that no path matching `example/` or `examples/` appears in offenders.
- [ ] Confirm that `files_refused` is zero in both views.
- [ ] Run the metrics contract fixture and native client tests.

### Phase 1 — Characterise the top debt

- [ ] Read each top-ranked function and its tests.
- [ ] Add a focused regression test for each behaviour that must survive a split.
- [ ] Measure Carbonah before changing a hot path: Frond render, ORM query/write,
  migration, routing, and server dispatch.
- [ ] Choose the best implementation across the four languages. Record why it wins.

#### First completed slice: Node.js Frond fast-filter dispatch

The first behaviour-preserving slice extracted the no-argument filter dispatch
from `Frond.evalVarInner` into a table-driven helper. This keeps filter order,
sandbox gates, escaping, and output bytes unchanged while removing the large
inline switch from the hot expression path.

| Measurement | Before | After |
| --- | ---: | ---: |
| Frond source offenders | 33 | 32 |
| Average function complexity | 4.87 | 4.44 |
| Frond fixture tests | 297 passed | 297 passed |
| Typecheck | passed | passed |
| Render benchmark average | 77.68 µs | 71.73 µs |

Benchmark shape: 50,000 cached `renderString` calls over a loop/filter/escape
template with 20 records, after a 5,000-call warm-up. The timing is directional,
not a release performance claim; repeat it on the lab before accepting a larger
Frond split.

Code commit: `888cdaa` (`refactor(frond): isolate fast filter dispatch`).

### Phase 2 — Refactor at parity

- [ ] Start with Frond expression/render complexity, ORM/database translation,
  and migration splitting because they affect multiple frameworks.
- [ ] Keep one concern per commit and one subsystem per plan item.
- [ ] Port the proven shape to all four backends. Do not create a framework-only
  workaround for a shared contract.
- [ ] Keep Dev Admin improvements separate from core framework refactors.

### Phase 3 — Re-measure and enforce

- [ ] Re-run both full and core metrics views after each landed subsystem.
- [ ] Require no new error-severity offenders and no increase in total warning
  debt from the previous baseline.
- [ ] Grandfather existing findings in a checked-in baseline. Ratchet the baseline
  down only after a real fix and its full-suite proof.
- [ ] Wire `--fail-on error` for new errors first; add the warning gate after the
  baseline process proves stable.

### Phase 4 — Release gate

- [ ] Run Python, PHP, Ruby, and Node.js full suites on
  `andre@192.168.88.99` as root with live services.
- [ ] Run the shared metrics contract and parse-health fixtures.
- [ ] Rebuild Docker images and confirm the reported framework version.
- [ ] Update the four release chapters, quick references, and the metrics feature
  packet with the measured before/after numbers.
- [ ] Merge the release branch into `v3` only after the exact merged heads pass.

## Parity dashboard

| Work item | Python | PHP | Ruby | Node.js |
| --- | --- | --- | --- | --- |
| Full examples-excluded baseline | ✅ | ✅ | ✅ | ✅ |
| Core exclusion baseline | ❌ BUILD | ❌ BUILD | ❌ BUILD | ❌ BUILD |
| Top-offender characterisation tests | ❌ BUILD | ❌ BUILD | ❌ BUILD | ❌ BUILD |
| Cross-language subsystem comparison | ❌ BUILD | ❌ BUILD | ❌ BUILD | ❌ BUILD |
| Behaviour-preserving remediation | ❌ BUILD | ❌ BUILD | ❌ BUILD | ❌ BUILD |
| Full lab suite at merged HEAD | ❌ BUILD | ❌ BUILD | ❌ BUILD | ❌ BUILD |

## Acceptance criteria

- The full and core scan boundaries are explicit and reproducible.
- Examples never appear in the offender set.
- No parser refusal or silent source omission remains.
- Every accepted refactor has a named regression test and a before/after metric.
- Shared behaviour remains byte- and error-compatible across all four languages.
- The CI gate blocks new debt without making the current baseline an overnight
  rewrite requirement.
- The final plan lists each fixed offender, commit, test result, and remaining
  intentional complexity.

## Bugs and open decisions

- [ ] Confirm whether framework Dev Admin belongs in the public framework score
  or only in a separate dashboard score. The current full view includes it;
  the core view excludes it.
- [ ] Confirm the baseline format for grandfathered offenders before enabling
  the CI warning gate.
- [ ] Confirm the first remediation subsystem after the core re-baseline.

## Commits

- Pending: audit plan created from the 2026-09-05 examples-excluded scan.

## Status: Plan ready for owner review
