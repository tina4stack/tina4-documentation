# Task: adversarial re-audit of every previously audited feature

Owner decision, 2026-08-08: re-audit the features already marked audited after
Feature 27 exposed shipping contradictions behind fully green suites.

Owner decision, 2026-08-08: the accumulated output must also be a clean-room
formula for implementing Tina4 in another language. Every feature therefore
owes a language-neutral porting capsule defined in `PORTING-FORMULA.md`; the
existing four implementations are evidence, not instructions to copy.

Owner decision, 2026-08-08: those same porting packets are the parity oracle for
all existing and future languages. When evidence leaves more than one defensible
rule, stop that rule, give the owner the alternatives and consequences, and
record the owner's choice in an ADR before fixtures or implementations encode it.

Owner decision, 2026-08-08: **3.14.0 is the stable-contract boundary.** Before
that release, any API or behavior may break when required to achieve correctness,
simplicity and full parity. Do not preserve a known-wrong pre-3.14 behavior with
aliases, compatibility branches or duplicated result shapes merely because it
already shipped. Every break must still be named, fixture-proven and accompanied
by an actionable migration note. At 3.14.0 the resulting neutral contracts become
the stable baseline.

Owner decision, 2026-08-08: **finish the audit before coding.** During this phase,
make no framework fixes and add no implementation/regression tests. Capture
evidence, owner decisions, neutral contracts, porting capsules, proposed fixtures
and the dependency-ordered implementation backlog first. Coding and executable
conformance changes begin as a separate phase only after the complete feature
walk has exposed the full 3.14 contract and blast radius.

Owner decision, 2026-08-08: **one feature, one Markdown file.** Every matrix row,
variant member and retired identity gets its own contract packet under
`features/`. Existing combined plans are split during their re-audit; shared
evidence may be linked but cannot stand in for an individual implementation and
parity plan.

The apparent completed count is reconciled directly from the audit record in
`AUDITED-FEATURE-REAUDIT-TABLE.md`. `98-feature-audit.md` supports 32 historically
audited numbered features, not 44 completed features; grouped rows are expanded
there without inventing additional closures.

## Why the first audit is not sufficient

The migration suites were independently green on the live lab with zero skips:
Python 93, PHP 105, Ruby 94, Node 272. Yet the public feature still contradicted
itself:

- Node creates a `.ts` migration which its runner never discovers.
- Python can run `.py` migrations which its status/file surfaces omit.
- three frameworks can erase applied history when no rollback exists.
- Node erases applied history even after rollback SQL fails.

The tests proved the paths they named. They did not prove the feature was closed.
This re-audit checks for the missing path between public operations.

## Scope

Re-open every feature currently in Layer 1 or Layer 2 of `CONTRACT-MAP.md`, in
strict numeric order starting with Feature 1. Messenger retains its existing
matrix identity, **Feature 55**; its earlier "Feature 0" label described its role
as the audit pilot and is retired. Feature 27 remains open and is revisited in
sequence; this plan does not discard its findings.

## Required loop for each feature

- [ ] Enumerate every public constructor, method, helper, CLI command, startup
      hook, environment variable, stored format, and wire endpoint.
- [ ] Build an operation graph: create -> discover -> execute -> inspect ->
      retry/rollback/delete. Every produced artefact must be consumable by the
      next public operation.
- [ ] Map every public operation and every branch to a test that the real runner
      reports. A file or test name is not evidence that a branch executes.
- [ ] Run the positive path and its negative pair against all four frameworks.
- [ ] Probe contradictions between methods, not only each method in isolation.
- [ ] Exercise explicit argument vs environment vs default precedence.
- [ ] Exercise missing, malformed, duplicate, stale, partially-written, and
      already-applied/already-deleted states where the feature admits them.
- [ ] For pluggable features, run the identical application case against every
      provider on the .99 lab (ADR-0024); zero skips.
- [ ] Specify the mutation witness each future gate must carry. Execute those
      mutations in the implementation phase after the audit is complete.
- [ ] Reconcile implementation, CLI, startup integration, docs, fixture, and
      status/introspection surfaces. A feature is not closed when only one path
      is correct.
- [ ] Design the shared executable fixture and map every case to all four
      languages. Write/strengthen and execute it in the implementation phase.
- [ ] Preserve exact-HEAD focused/full lab baselines as evidence. Re-run the new
      conformance and full suites during implementation.
- [ ] Update the feature plan, `98-feature-audit.md`, `CONTRACT-MAP.md`, ADRs,
      and release migration notes together.
- [ ] Write the feature's ten-part porting capsule: boundary, surface, types,
      lifecycle, precedence, failures/side effects, wire/storage, providers,
      executable cases and integration map. It must be implementable without
      reading one of the four existing source trees.
- [ ] Run the completed porting packet back against every existing language.
      The artifact for creating language five is also the parity validator for
      languages one through four.
- [ ] Escalate genuinely ambiguous rules to the owner with concrete alternatives
      and consequences; record the decision in an ADR before closing the row.
- [ ] Prefer one corrected 3.14 surface over compatibility aliases or parallel
      legacy behavior. Record every breaking change and its migration path.

## Closure rule

A feature re-closes only when:

1. every public producer has a tested consumer;
2. every destructive/state-changing operation has a tested failure path;
3. all four expose the same outcome with idiomatic spelling;
4. the shared fixture is executable and mutation-witnessed;
5. required-service lab runs have zero skips;
6. the full four suites pass at the exact committed HEAD.
7. an implementer adding another language can build the feature from its porting capsule,
   fixture and ADRs without being told which existing runtime to copy.
8. the same packet validates every current implementation, and every unresolved
   owner rule has either been decided and recorded or keeps the feature open.

These are implementation closure rules. During the audit-first phase each row
instead closes as a **decision-ready contract packet**: complete evidence,
resolved owner rules, proposed fixture/witness cases, porting capsule and scoped
implementation tasks. Green legacy suites establish a baseline only.

## Ordered dashboard

| Feature | Prior state | Re-audit state |
| --- | --- | --- |
| 1 DotEnv | closed | **CONTRACT COMPLETE 2026-08-09; implementation pending after full audit** |
| 2 Structured logger | auditing | **CONTRACT COMPLETE 2026-08-09; 59-case fixture and runner implementation pending after full audit** |
| 3 DB adapter interface | closed | **CONTRACT COMPLETE 2026-08-10; ADR-0044 + 38-case fixture, implementation pending after full audit** |
| 4 SQLite adapter/write path | effectively closed | queued |
| 5 DATABASE_URL parser | shipped | queued |
| 6 Router/dispatch | closed | queued |
| 7 Middleware | closed | queued |
| 8 Health | Layer 2 | queued |
| 9 Shutdown | closed | queued |
| 10 CORS | closed | queued |
| 11-12,79 Routing surface | closed | queued |
| 13-20 ORM/data | closed or re-opened | queued |
| 27 Migrations | audit in progress | queued with known defects |
| 28-32 Frond core/filters | closed | queued |
| 37-38 Escaping/sandbox | closed | queued |
| 41-43 Auth/session/cache | Layer 1/2 | queued |
| 47 Swagger | Layer 2 | queued |
| 48 Queue | Layer 2 | queued |
| 50 HTTP client | shipped, no fixture | queued |
| 55 Email / Messenger | Layer 2 / former pilot | queued in numeric order |
| unnumbered DocStore/tina4-css | Layer 2 | queued after numbered rows |

## Feature 55 planned work

- [ ] Enumerate construction/factory, send, capture, folder/list, read, search,
      attachments, flags, delete/move and transport configuration surfaces.
- [ ] Build the complete SMTP/IMAP operation graph, including captured-message
      behavior and every producer-to-consumer identifier transition.
- [ ] Reconcile public result/error shapes, wire identifiers, attachment bytes,
      TLS/auth configuration, missing-message behavior and destructive failures.
- [ ] Map all 14 existing `messenger_contract.json` invariants to reported tests
      and identify public branches that the fixture does not describe.
- [ ] Run read-only probes against real GreenMail on the lab where existing
      evidence is insufficient; preserve the zero-skip baseline.
- [ ] Complete the ten-part Messenger porting capsule and decision-ready proposed
      fixture additions. Do not change framework code during the audit phase.

## Feature 1 immediate work

- [ ] Enumerate `load_env`, typed getters, required-variable checks, interpolation,
      precedence, and top-level exports in all four.
- [x] Compare the four `dotenv_corpus.json` files byte-for-byte. The versioned
      `contract_3_14` section contains all 46 named Feature 1 cases and all four
      copies have SHA-1 `51f1ec315fe157d3f7fb7f62052dd0985595383e`.
- [x] Map every corpus row to a reported test. Dedicated fail-closed runners in
      all four frameworks discover each of the 46 IDs exactly once and reject a
      missing executor; no case can disappear behind a skip or a green legacy
      suite. Branch-to-row mutation proof remains implementation work.
- [ ] Probe producer/consumer paths: file load -> process env -> typed getter ->
      framework startup consumer.
- [ ] Probe duplicate keys, empty values, malformed lines, escaped dollars,
      recursive/circular interpolation, CRLF/BOM, inline comments after every
      quote form, explicit root precedence, and ambient environment wins.
- [ ] Promote the corpus into the central contract map or explain why a separate
      fixture earns its duplication.
- [x] Run the wired contract runners locally and on the lab. Expected-red lab
      baseline: Python 46 failed/2 metadata passed; PHP 46 failed in 48 tests;
      Ruby 46 failed in 48 examples; Node 46 failed/4 harness checks passed.
      All failures name the absent case executor. Behavioral executors, mutation
      proof and post-implementation full suites remain implementation work.

## Bugs

- [ ] Feature 1: Python `require_env` treats a present empty value as missing;
      PHP, Ruby and Node return it, and the shared corpus explicitly says
      `EMPTY=` is set rather than absent.
- [ ] Feature 1: Python, PHP and Node lost the intended project-bootstrap
      behavior: `load_env(root)` must create a default `.env` when it is absent,
      as Ruby still does. Owner decision 2026-08-08; Python and PHP previously
      behaved this way. Canonical generated contents and secure secret generation
      still require conformance evidence.
- [ ] Feature 1: typed `Env.bool` in Python, PHP and Node accepts the retired
      single-letter tokens `y/t/n/f`, contradicting their own public
      `is_truthy` helper, the shared corpus, and Ruby's unified table.
- [ ] Feature 1: typed bool unknown-token handling differs: Python/PHP/Node return
      the caller's default for a present unknown token, while Ruby and the
      shared truthiness contract classify every non-truthy present value false.
- [ ] Feature 1: Node `Env.int`/`Env.float` use prefix parsers, so values such as
      `12px` and `1.5seconds` are silently accepted; Python, PHP and Ruby reject
      the entire malformed token and return the default.
- [ ] Feature 27: Node-generated `.ts` migration is not runnable/discoverable.
- [ ] Feature 27: Python/Node status/file surfaces omit native code migrations.
- [ ] Feature 27: missing or failed rollback can erase applied history.
- [ ] Feature 27: public outcomes differ four ways.

## Commits

- None yet.

## Status: In progress
