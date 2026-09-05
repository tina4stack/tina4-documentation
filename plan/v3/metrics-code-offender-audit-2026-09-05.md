# Metrics code-offender audit — 2026-09-05

## Outcome

Measure code health in Python, PHP, Ruby, and Node.js with one Tina4 Metrics
engine. Exclude example applications. Classify every offender before changing
code. Fix proven design debt at parity, then enforce the improved baseline in
CI without forcing the existing debt to disappear in one release.

This plan covers the active `v3` branches. The shipped Tina4 client used for
the current baseline is `v3.8.82`. It does not audit tina4-js, the Rust client,
generated bundles, or example applications.

## Scope

- [x] Run the native Tina4 Metrics client against all four framework roots.
- [x] Exclude `example/` and `examples/` trees with repeatable `--exclude` globs.
- [x] Confirm zero example offenders, zero refused files, and record the baseline.
- [x] Re-run a core view excluding Dev Admin, galleries, generated assets, tests,
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

Command shape (client `v3.8.82`):

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

## Baseline: core framework source

The shipped `v3.8.82` binary repeated this scan with explicit caller-owned
exclusions for Dev Admin, galleries, public assets, and example trees. The
result is the accepted core baseline. `files_refused` is zero in every scan.

| Framework | Files | Functions | Avg CC | Avg MI | Findings | Duplicate blocks | Duplicate lines | Refused |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Python | 105 | 2,646 | 3.87 | 26.4 | 293 | 19 | 162 | 0 |
| PHP | 171 | 3,056 | 3.72 | 35.6 | 389 | 76 | 796 | 0 |
| Ruby | 123 | 4,254 | 2.74 | 28.6 | 242 | 21 | 211 | 0 |
| Node.js | 139 | 3,536 | 3.31 | 28.0 | 368 | 62 | 688 | 0 |

The core scan is a debt baseline, not a release gate. It measures production
source and records existing findings so later work can prevent regressions
without pretending that the framework can remove all debt in one change.

#### Boundary correction for incremental Node.js scans

The documented Node.js core boundary includes `**/devAdmin.ts`. Several
incremental measurements below were initially run without that exclusion, so
their Node totals include Dev Admin and are directional only. The corrected
current scan at `c61908b` uses the documented boundary: 357 findings, 23
error-level findings, 60 duplicate blocks, and 611 duplicate lines. Future
measurements must include `--exclude '**/devAdmin.ts'`.

## Published-client lab smoke

The published Linux `v3.8.82` binary was copied to the lab and run against
`/home/andre/rel-3.13.132` with the same exclusions and `--no-history`.

| Framework | Files | Functions | Avg CC | Avg MI | Findings | Duplicate blocks | Duplicate lines | Refused |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Python | 105 | 2,646 | 3.87 | 26.4 | 293 | 19 | 162 | 0 |
| PHP | 171 | 3,056 | 3.72 | 35.6 | 389 | 76 | 796 | 0 |
| Ruby | 123 | 4,254 | 2.74 | 28.6 | 242 | 21 | 211 | 0 |
| Node.js | 139 | 3,495 | 3.35 | 28.0 | 367 | 62 | 688 | 0 |

Python, PHP, and Ruby match the local `v3` baseline. Node.js is not a
reproducibility failure: the lab checkout is at `e599584`, the
`feature/release3.13.132` branch carrying later `3.13.133` maintainability
changes, while the local comparison is `v3` at `23835dd`. The branch and
commit must be recorded whenever metrics are compared.

## Lab suite gate

On 2026-09-05, the Python `feature/release3.13.132` checkout at `2e956f0`
ran on the Linux lab as root with `TINA4_REQUIRE_SERVICES=1`:

```text
4 failed, 5663 passed, 98 skipped, 189 errors
```

The affected tests do not yet prove framework defects. The focused batch-write
run isolated two environment failures: MySQL used a root account without the
configured password, and MSSQL rejected the configured `sa` login. The error
set also contains unreachable or mismatched lab services: PostgreSQL was
addressed at `192.168.88.99:55432` while the container is localhost-bound,
MongoDB was addressed through a different bind, the PostGIS database name
`tina4_gis` does not exist in the provisioned container, the MQTT TLS CA was
missing or stale, and RabbitMQ/Kafka URLs were not set.

Decision: do not change framework code to satisfy these failures. Repair the
lab service matrix and rerun the affected service tests before calling the
Python suite a code gate. The SQLite-only validation and ORM contract tests
remain the correct targeted controls for the Node validation refactor below.

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

#### Shared audit slice: migration SQL splitting

The first cross-language review covers the SQL statement splitter because it is
an error-severity complexity offender in every framework:

| Framework | Implementation | Complexity | Existing contract coverage |
| --- | --- | ---: | --- |
| Python | `migration/runner.py::_split_statements` | 40 | `tests/test_sql_translation.py`, migration contract |
| PHP | `Migration.php::splitStatements` | 41 | migration contract and footgun tests |
| Ruby | `migration.rb::split_sql_statements` | 40 | `spec/migration_footguns_spec.rb`, migration contract |
| Node.js | `orm/src/migration.ts::splitStatements` | 40 | `test/migrationContract.test.ts` and ORM migration tests |

The four implementations already share the same contract: normalize smart
quotes, ignore semicolons in strings and comments, preserve `$$` and `//`
procedure blocks, and consume `SET TERM` directives. The fixture packet covers
transaction boundaries, rollback ledger safety, CLI/ORM path identity, and
real Firebird/MSSQL idempotency. This is intentional parser complexity, not a
safe blind refactor target.

Decision: retain the current implementations for now. Before any split, add a
shared splitter fixture for every edge case above, run the four native suites,
and measure migration throughput on the lab. A refactor is accepted only if it
preserves statement bytes, delimiter state, failure semantics, and parity.

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

#### Second completed slice: Node.js Frond path resolution

`resolveVar` was decomposed into cached path parsing, method invocation, key
resolution, slicing, and member access. The public template contract is
unchanged, and new characterization cases cover bracket variables, slices, and
object methods.

| Measurement | Before | After |
| --- | ---: | ---: |
| `resolveVar` complexity | 62 | 31 |
| Frond fixture tests | 297 passed | 300 passed |
| Typecheck | passed | passed |
| Render benchmark average | 71.73 µs | 59.56 µs |

The benchmark uses the same warm-up, template, data set, and 50,000 cached
renders as the first slice. Repeat on the lab before release acceptance.

Code commit: `9dc4b21` (`refactor(frond): split path resolution responsibilities`).

#### Third completed slice: Node.js Frond block dispatch

`renderTokens` now owns token iteration and whitespace handling, while tag
dispatch is isolated from the long chain of block-specific branches. Common
`if`/`for` paths stay direct; the remaining tags use a responsibility-based
dispatcher. This keeps sandbox gates, unknown-tag errors, whitespace control,
and nested output unchanged.

| Measurement | Before | After |
| --- | ---: | ---: |
| `renderTokens` complexity | 40 | 27 |
| Frond fixture tests | 300 passed | 300 passed |
| Typecheck | passed | passed |
| Render benchmark average | 77.68 µs | 77.75 µs |

The benchmark is the same 50,000 cached renders and warm-up used for the prior
slices; the result is performance-neutral within run variance.

Code commit: `b6b36e7` (`refactor(frond): dispatch block tags by responsibility`).

#### Fourth completed slice: Node.js Frond loop handling

`handleFor` now delegates token collection (including nested `for`/`if` depth),
iterable normalization, and loop execution. The public loop contract is
unchanged: arrays, objects, key/value loops, nested loops, `else`, loop metadata,
and parent-context fallback remain covered by the existing fixture suite.

| Measurement | Before | After |
| --- | ---: | ---: |
| `handleFor` complexity | 36 | no longer an offender |
| Frond fixture tests | 300 passed | 300 passed |
| Typecheck | passed | passed |
| Local render benchmark average | 77.75 µs | 89.40 µs |

The local loop benchmark showed JIT variance across repeated runs (roughly
89–96 µs after the refactor), so this is not accepted as a performance result
yet. The lab must repeat the fixed-shape benchmark before release acceptance;
if the regression reproduces, optimize the loop path before continuing.

Code commit: `23835dd` (`refactor(frond): separate loop collection and iteration`).

#### Fifth completed slice: Node.js macro import and ORM validation paths

The Frond `import ... as` and `from ... import` handlers shared the same macro
token scan and closure construction but had two copies of the implementation.
`collectMacroDefinitions` and `createMacro` now own that common path. The
selected-macro context capture remains ordered, so a later imported macro can
still call an earlier one.

The ORM field validator also carried one large type switch. String, numeric,
and remaining field rules now use small helpers while preserving error order,
messages, update-mode handling, and pattern compilation.

| Measurement | Before | After |
| --- | ---: | ---: |
| Node core offenders | 386 | 385 |
| Duplicate blocks | 68 | 66 |
| Duplicate lines | 711 | 680 |
| `validate` complexity | 52 | no longer an offender |
| Frond import/macro tests | 18 passed | 18 passed |
| ORM, validation, and contract tests | not split | 165 passed |
| Typecheck | passed | passed |

The metric count is a directional code-health measure; the targeted tests are
the behaviour gate. Code commit: `ce9d468` (`refactor(metrics): remove node
frond and validation offenders`).

#### Sixth completed slice: Node.js AI stream aggregation

The AI client’s OpenAI and Anthropic stream aggregators mixed provider dispatch,
tool-call buffering, usage accounting, terminator handling, and parse errors in
two large methods. Those responsibilities now delegate to focused handlers while
keeping the public `Ai.chat(..., { stream: true })` event contract unchanged.

| Measurement | Before | After |
| --- | ---: | ---: |
| Node core offenders | 380 | 378 |
| `AggregateState.consumeOpenAi` complexity | 26 | no longer an offender |
| `AggregateState.consumeAnthropic` complexity | 33 | no longer an offender |
| AI contract tests over a real HTTP socket | 35 passed | 35 passed |
| AI installer tests | 31 passed | 31 passed |
| Typecheck | passed | passed |

The remaining AI findings are the request/validation path and file-size warning;
they are separate from stream aggregation and should be benchmarked or tested in
their own slice. Code commit: `d2eeeb4` (`refactor(metrics): split ai stream aggregation`).

#### Seventh completed slice: Node.js AI content validation

`validateContent` now delegates text, image, and tool-result checks to focused
validators. The accepted input shapes and fail-fast `AiConfigError` messages are
unchanged, including the data-URI and HTTPS image restrictions.

| Measurement | Before | After |
| --- | ---: | ---: |
| Node core offenders | 378 | 377 |
| `Ai.validateContent` complexity | 21 | no longer an offender |
| AI contract tests over a real HTTP socket | 35 passed | 35 passed |
| Typecheck | passed | passed |

Code commit: `ebe609e` (`refactor(metrics): split ai content validation`).

#### Eighth completed slice: Node.js AI stream event consumption

The stream request path now delegates SSE framing, aggregation, and mid-stream
parse handling to `readStream`. Retry, timeout, cleanup, and incomplete-stream
rules remain in `streamRequest`; this keeps transport policy separate from event
decoding.

| Measurement | Before | After |
| --- | ---: | ---: |
| `Ai.streamRequest` complexity | 24 | 18 (warning, no longer an error) |
| AI contract tests over a real HTTP socket | 35 passed | 35 passed |
| AI retry tests | 8 passed | 8 passed |
| Typecheck | passed | passed |

Code commit: `aaf242b` (`refactor(metrics): isolate ai stream event consumption`).

#### Ninth completed slice: Node.js Messenger SMTP send path

`Messenger.send` now owns recipient preparation and capture gating while focused
helpers own SMTP connection/session setup, authentication, envelope delivery, and
MIME transmission. Capture still wins before `TINA4_MAIL_REDIRECT_TO`, and SMTP
failure messages retain their existing shapes.

| Measurement | Before | After |
| --- | ---: | ---: |
| Node core offenders | 377 | 375 |
| `Messenger.send` complexity | 32 | no longer an offender |
| Duplicate blocks | 66 | 65 |
| Duplicate lines | 680 | 650 |
| Messenger parity tests | 13 passed | 13 passed |
| DevMailbox tests | 87 passed | 87 passed |
| Redirect contract | 3 skipped (GreenMail unavailable) | 3 skipped (GreenMail unavailable) |
| Typecheck | passed | passed |

The redirect contract remains infrastructure-red because GreenMail is not
available on this workstation; the local negative and capture paths are covered by
the parity suite. Code commit: `790cefb` (`refactor(metrics): split messenger smtp send`).

#### Tenth completed slice: Node.js ProjectIndex modules

Project indexing now separates the public index operations from filesystem
storage and language extractors. Search scoring is unchanged, and the extractor
module has a direct route assertion so the module is tested independently rather
than inferred through a transitive import.

| Measurement | Before | After |
| --- | ---: | ---: |
| Node core offenders | 375 | 373 |
| `ProjectIndex.search` complexity | 22 | no longer an offender |
| ProjectIndex error-level findings | 1 | 0 |
| ProjectIndex tests | 18 passed | 19 passed |
| Typecheck | passed | passed |

The ProjectIndex files retain warning-level complexity signals for a later
warning-debt pass; no error-level finding remains in this subsystem. Code commit:
`4225e2e` (`refactor(metrics): split project index modules`).

#### Eleventh completed slice: Node.js CLI lint execution

The lint command now separates eslint bootstrap, eslint execution, TypeScript
baseline checking, and JavaScript syntax checking. The command selection,
dev-only dependency installation, scaffold rules, exit codes, and summaries are
unchanged.

| Measurement | Before | After |
| --- | ---: | ---: |
| Node core offenders | 373 | 372 |
| `runLint` complexity | 29 | no longer an offender |
| CLI lint contract tests | 28 passed | 28 passed |
| Typecheck | passed | passed |

The remaining lint warning is isolated to eslint bootstrap branching and is not
an error-level finding. Code commit: `d7e090f` (`refactor(metrics): split cli lint execution`).

#### Twelfth completed slice: Node.js MongoDB SQL parser

The MongoDB adapter now dispatches SQL parsing to focused SELECT, INSERT, UPDATE,
DELETE, CREATE, and COUNT handlers. The fail-closed `WHERE` parser and mass-write
guard were retained unchanged; unsupported write conditions still raise instead
of becoming an empty MongoDB filter.

| Measurement | Before | After |
| --- | ---: | ---: |
| Node core offenders | 372 | 372 |
| Error-level findings | 28 | 27 |
| `parseSql` complexity | 31 | no longer an offender |
| Typecheck | passed | passed |
| Mongo fail-closed contract | unavailable locally (MongoDB absent) | unavailable locally (MongoDB absent) |

The Mongo contract must be rerun on the lab with a reachable MongoDB before this
slice is release-accepted. Code commit: `ba97770` (`refactor(metrics): split mongodb sql parser`).

#### Thirteenth completed slice: Node.js Plan flesh workflow

`Plan.flesh` now delegates prompt construction, AI response retrieval, response
parsing, and duplicate-safe step insertion. The nonexistent-plan fast failure,
JSON-array contract, markdown-list fallback, and AI error response remain the
same.

| Measurement | Before | After |
| --- | ---: | ---: |
| Corrected Node core findings | 357 | 357 |
| Corrected error-level findings | 24 | 23 |
| `Plan.flesh` complexity | 27 | 12 (warning, no longer an error) |
| Plan tests | 42 passed | 42 passed |
| Plan list tests | 25 passed | 25 passed |
| Typecheck | passed | passed |

Code commit: `c61908b` (`refactor(metrics): split plan flesh workflow`).

#### Fourteenth completed slice: Node.js CSRF middleware checks

CSRF request classification, bearer bypass, token extraction, and session binding
now live in focused helpers. The fail-closed secret rule, query-token rejection,
token type enforcement, and four-key `CSRF_INVALID` response are unchanged.

| Measurement | Before | After |
| --- | ---: | ---: |
| Corrected Node core findings | 357 | 357 |
| Corrected error-level findings | 23 | 22 |
| `CsrfMiddleware.beforeCsrf` complexity | 25 | 13 (warning, no longer an error) |
| CSRF conformance tests | 46 passed | 46 passed |
| Typecheck | passed | passed |

Code commit: `0512b02` (`refactor(metrics): split csrf middleware checks`).

#### Fifteenth completed slice: Node.js logger snapshot resolution

Logger configuration resolution now delegates level, format, output, and path
validation to focused helpers. The explicit-over-environment precedence,
development/prod defaults, path-target heuristic, NUL rejection, and
transactional sink setup are unchanged.

| Measurement | Before | After |
| --- | ---: | ---: |
| Corrected Node core findings | 357 | 356 |
| Corrected error-level findings | 22 | 21 |
| `resolveSnapshot` complexity | 23 | cleared |
| Logger unit tests | 62 passed | 62 passed |
| Logger contract tests | 30 passed | 30 passed |
| Logger fixture tests | 60 passed | 60 passed |
| Typecheck | passed | passed |

Code commit: `9995a77` (`refactor(metrics): split logger snapshot resolution`).

#### Sixteenth completed slice: Node.js MCP syntax verification

MCP write-time syntax verification now separates target selection, command
construction, and process-output formatting. The `src/` boundary, test-file
exclusion, TypeScript missing-compiler fallback, five-second timeout, and
project-relative diagnostics are unchanged.

| Measurement | Before | After |
| --- | ---: | ---: |
| Corrected Node core findings | 356 | 356 |
| Corrected error-level findings | 21 | 20 |
| `verifyNodeSyntax` complexity | 23 | cleared |
| MCP protocol tests | 101 passed | 101 passed |
| MCP dev-tool conformance | 72 passed | 72 passed |
| MCP security tests | 30 passed | 30 passed |
| Typecheck | passed | passed |

Code commit: `7577029` (`refactor(metrics): split mcp syntax verification`).

#### Seventeenth completed slice: Node.js CLI resolution output

The human `generate` resolution block now separates summary, reserved-word
guidance, and optional test/edit/next sections. JSON mode, stderr routing,
section order, and the `generate_v1_1` envelope remain unchanged.

| Measurement | Before | After |
| --- | ---: | ---: |
| Corrected Node core findings | 356 | 355 |
| Corrected error-level findings | 20 | 19 |
| `printResolution` complexity | 21 | cleared |
| Generator resolution tests | 48 passed | 48 passed |
| Generator envelope v1.1 tests | 79 passed | 79 passed |
| Co-emitted generator tests | 38 passed | 38 passed |
| Reserved-table generator tests | 23 passed | 23 passed |
| Typecheck | passed | passed |

Code commit: `94fb039` (`refactor(metrics): split cli resolution output`).

#### Eighteenth completed slice: Node.js compression and ETag finalization

The response interceptor now separates gzip eligibility, conditional-validator
matching, 304 header cleanup, and buffered response finalization. Compression
thresholds, static pre-encoding protection, ETag precedence, conditional GET
rules, and content-length handling are unchanged.

| Measurement | Before | After |
| --- | ---: | ---: |
| Corrected Node core findings | 355 | 355 |
| Corrected error-level findings | 19 | 18 |
| `compressionEtagIntercept` end callback complexity | 27 | cleared |
| Compression/ETag contract | 25 passed | 25 passed |
| HEAD conformance | 5 passed | 5 passed |
| Dispatch pipeline contract | 9 passed | 9 passed |
| Dispatch characterisation | 11 passed | 11 passed |
| Dev-toolbar gzip suite | runner blocked | runner blocked (Vitest `import.meta.url` setup error) |
| Typecheck | passed | passed |

Code commit: `f72eac2` (`refactor(metrics): split compression etag response handling`).

#### Nineteenth completed slice: Node.js Frond filter dispatch

Frond now shares one filter-value dispatcher for nested filter pipes and raw
condition evaluation, while rendered output keeps its separate fast-filter and
escaping path. Sandbox allow-list checks, first/last property tails, custom
filters, comparison suffixes, and unknown-filter expression fallback are
unchanged.

| Measurement | Before | After |
| --- | ---: | ---: |
| Corrected Node core findings | 355 | 355 |
| Corrected error-level findings | 18 | 16 |
| `Frond.applyFilters` complexity | 23 | cleared |
| `Frond.evalVarRaw` complexity | 23 | cleared |
| Frond core tests | 300 passed | 300 passed |
| Frond sandbox contract | 22 passed | 22 passed |
| Frond expression parity | 130 passed | 130 passed |
| Typecheck | passed | passed |

`Frond.evalVarInner` fell from complexity 34 to 24 but remains an error-level
offender; it is retained for the next focused slice rather than being marked
complete here.

Code commit: `5d23305` (`refactor(metrics): consolidate frond filter dispatch`).

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
| Core exclusion baseline | ✅ | ✅ | ✅ | ✅ |
| Shared migration splitter audit | ✅ | ✅ | ✅ | ✅ |
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

- `v3.8.82` shipped the metrics client used for the core baseline.
- `d575324` recorded the published-client core baseline and migration splitter triage.
- `0da4a74` recorded the published-client lab smoke and branch difference.
- `ce9d468` removed the Node Frond macro duplication and ORM validation offender.
- `d2eeeb4` split Node AI stream aggregation without changing its event contract.
- `ebe609e` split Node AI content validation without changing its input contract.
- `aaf242b` isolated Node AI stream event consumption from transport policy.
- `790cefb` split Node Messenger SMTP send responsibilities and preserved capture precedence.
- `4225e2e` split Node ProjectIndex storage and language extraction modules.
- `d7e090f` split Node CLI lint execution paths.
- `ba97770` split Node MongoDB SQL parsing by statement type.
- `c61908b` split Node Plan flesh workflow responsibilities.
- `0512b02` split Node CSRF middleware checks without changing the security contract.
- `9995a77` split Node logger snapshot resolution without changing configuration semantics.
- `7577029` split Node MCP syntax verification without changing write-time validation.
- `94fb039` split Node CLI resolution output without changing the envelope or human output contract.
- `f72eac2` split Node compression and ETag response finalization without changing HTTP semantics.
- `5d23305` consolidated Node Frond filter dispatch without changing expression or sandbox semantics.

## Status: Audit in progress — core baseline accepted; targeted Node remediation started; lab service gate remains infrastructure-red
