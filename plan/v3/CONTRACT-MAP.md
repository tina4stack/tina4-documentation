# Tina4 v3 - Contract and Spec Map

> The living index that ties every audited feature to its machine-checked
> contract, its decisions, and its proven-in-all-four status. This is the
> backbone of a future formal Tina4 language specification.
> **Last synced:** 2026-08-12 (3.13.99 pass: +csrf/devadmin/static/requestid/frondtags/securityheaders/porttakeover/overlay/inlinetesting/fileupload/backgroundtasks/ormcache/nextid fixtures)

> **Adversarial re-audit started 2026-08-08:** a zero-skip live-lab migration
> baseline still omitted contradictory public paths (generated code migration
> not discoverable; failed rollback erasing history). Every row previously
> labelled closed is being re-checked under `99-feature-reaudit.md`. Existing
> proven counts remain true for the invariants they name; they are not treated
> as proof that the fixture is complete.
>
> **Portability target, 2026-08-08:** this map must converge on the clean-room
> implementation formula in [PORTING-FORMULA.md](PORTING-FORMULA.md). A feature
> is not fully specified until another language can implement it from the
> language-neutral contract packet without reading an existing framework.
> That packet is also the parity oracle run back against every current language;
> the flow is audit -> neutral contract -> all implementations, never permanent
> promotion of one language as the master.
>
> **3.14.0 stability boundary:** breaking changes are permitted before 3.14.0
> to establish the correct, simple parity contract. They require conformance
> proof and migration notes, not automatic compatibility aliases. The resulting
> audited contracts become the stable baseline at 3.14.0.

## Why this map exists

Tina4 is one framework in four languages. A "spec" that lives only as prose
drifts the moment one implementation changes. So the real specification is being
built as **machine-checked contracts**: a shared JSON fixture per subsystem,
whose invariants are proven by a named test in every framework and gated by one
checker (`scripts/audit-contract-fixtures.py`, ADR-0024 rule 6). A contract that
is green is a behaviour all four frameworks are held to.

This file is the map from features to those contracts. It answers one question
per feature: **is its behaviour specified, decided, and proven in all four - or
still owed?** As each feature is audited it moves down the pipeline below, and
its row here is updated. Keeping this map current is how the audit work
accumulates into a language spec instead of scattering.

## The spec, in three layers

1. **[MASTER-SPEC.md](MASTER-SPEC.md)** - the prose API contract per feature
   (last full pass 2026-03-21). Readable, but it predates the contract fixtures,
   so where a fixture exists **the fixture is authoritative for behaviour** and
   MASTER-SPEC is the narrative around it. A future formal spec is produced by
   folding the fixtures + ADRs back into this document.
2. **Contract fixtures** (`fixtures/*_contract.json`) - the machine-checked,
   four-way-proven behavioural invariants. The authoritative layer.
3. **ADRs** (`decisions/ADR-*.md`) - the decisions behind the contracts (41
   allocated). An invariant cites the ADR that settled it.

## The pipeline (how a feature reaches the spec)

A feature is "specified" only when it has walked all seven steps. This mirrors the
audit method in [98-feature-audit.md](98-feature-audit.md).

1. **Audit** - measure LOC/CC/MI four-way, read all four, pick the best mechanism.
2. **Plan** - park it as `features/NNN-<name>.md` (133 exist).
3. **Decide** - any behaviour fork gets an `ADR-NNNN.md`.
4. **Fixture** - write `fixtures/<name>_contract.json` with the invariants + the
   conformance cases as data.
5. **Prove** - a named suite carrying those case names in ALL FOUR; the auditor
   green; the full suites green on the lab.
6. **Fold** - reflect the proven contract into MASTER-SPEC.
7. **Package for a new language** - complete the ten-part porting capsule in
   `PORTING-FORMULA.md` and prove that it contains no "copy runtime X" gaps.

Each public capability and selectable provider has one whole-number packet in
`features/`, based on `features/FEATURE-TEMPLATE.md`. The 3.14 catalog has no
decimal provider members. Combined historical plans remain archive evidence.

## Layer 2: machine-checked contract ledger

Source of truth for the counts: `python3 scripts/audit-contract-fixtures.py`.
Re-run it and re-sync this table whenever a fixture changes.

| Subsystem | Feature # | Fixture | Invariants | Proven | Owed | ADRs | Named suites (all 4) |
|---|---|---|---:|---:|---:|---|---|
| Structured logger | 2 | `logger_contract.json` | 8 | 0 | 8 | 0041 | owed; 59 cases not wired |
| Database adapter | 3 | `adapter_contract.json` | 8 | 0 | 8 | 0044 | owed; old structural runners superseded |
| Router + dispatch | 31 | `dispatch_contract.json` | 8 | 8 | 0 | 0010-0013 | yes |
| CSRF protection | 37 | `csrf_contract.json` | 11 | 11 | 0 | SEC-01, CSRF-DEC-01/02 | yes (real HS256 pipeline, no mocks; 2026-08-11) |
| Health check | 38 | `health_contract.json` | 5 | 5 | 0 | 0016 | yes |
| JWT + session | 64-65 | `session_contract.json` | 6 | 6 | 0 | 0021, 0024 | yes (5 carry a witness rule) |
| Cache backends | 72 | `cache_contract.json` | 8 | 8 | 0 | 0020, 0024 | yes |
| Queue backends | 89 | `queue_contract.json` | 7 | 7 | 0 | 0022-0024 | yes |
| Swagger / OpenAPI | 45 | `swagger_contract.json` | 10 | 10 | 0 | 0004, 0041 | yes (added 2026-08-07) |
| DocStore | 95 | `docstore_contract.json` | 9 | 9 | 0 | 0024, 0025, 0035, 0036 | yes |
| tina4-css | 62 | `tina4css_contract.json` | 1 | 1 | 0 | 0004 | yes |
| Messenger | 88 | `messenger_contract.json` | 14 | 14 | 0 | 0004, 0041, 0042 | yes (real GreenMail) |
| Paginated results | 24 | `pagination_contract.json` | 6 | 6 | 0 | 0043 | yes (real 250-row SQLite; incl. the AutoCrud REST endpoint) |
| Dev admin dashboard | 127 | `devadmin_contract.json` | 6 | 6 | 0 | DEVADMIN-DEC-01..06 | yes (real-dispatch, no mocks; 2026-08-11) |
| Static assets | 41 | `static_contract.json` | 5 | 5 | 0 | 0050, ST-DEC-01 | yes (real symlinks + temp dirs; 2026-08-11) |
| Request id / correlation | 43 | `requestid_contract.json` | 4 | 4 | 0 | RID-DEC-01/02 | yes (real pipeline + real HTTP; real log file; 2026-08-11) |
| Frond tag path confinement | 53 | `frondtags_contract.json` | 4 | 4 | 0 | TAG-DEC-01 | yes (real templates + real symlink + real dirs; one shared loader per lang; 2026-08-11) |
| MongoDB SQL provider | 14 | `mongosql_contract.json` | 3 | 3 | 0 | MONGO-DEC-01 | yes (real MongoDB; fail-closed parse + one shared filterless-write guard per lang; mutation-proved; 2026-08-11) |
| Security headers | 36 | `securityheaders_contract.json` | 2 | 2 | 0 | SECHDR-DEC-01, SECHDR-DEC-02 | yes (real pipeline: py `server.handle`, php `Router::dispatch`, ruby `RackApp#call`, node real HTTP; secure-by-default register + HTTPS-guarded HSTS + CSP `default-src 'self'`; PHP class renamed; mutation-proved; 2026-08-11) |
| Port takeover | 129 | `porttakeover_contract.json` | 2 | 2 | 0 | TAKEOVER-DEC-01, TAKEOVER-DEC-02, TAKEOVER-DEC-03 | yes (real processes on real ports, no mocks; ONE shared identity-checked helper per lang reused by the CLI + runtime paths; PID-file Tina4 identity + dev-gate + `TINA4_NO_TAKEOVER`/`--no-kill` opt-out; runtime path raises on a foreign holder; mutation-proved; 2026-08-11) |
| Development error overlay | 126 | `overlay_contract.json` | 4 | 4 | 0 | OVERLAY-DEC-01, OVERLAY-DEC-02, OVERLAY-DEC-03, OVERLAY-DEC-04 | yes (real dispatch / a real thrown 500, no mocks; dead `render_production_error` DELETED in all four + a wired-path prod-no-leak test replaces the dead-sibling unit test; ONE redaction helper per lang masks Authorization/Cookie/Set-Cookie + password-like body/param keys; PHP now renders headers deliberately; 50-frame cap; guarded overlay render falls back to the safe page; gate unified on `is_debug_mode`; mutation-proved; 2026-08-12) |
| Inline testing | 132 | `inlinetesting_contract.json` | 3 | 3 | 0 | INLINE-DEC-01, INLINE-DEC-02 | yes (real `tina4 <lang> test` child process, no mocks; ONE wired surface -- the `@tests`/expect_* descriptor model -- discovered + run with a real exit code, 0 on pass / non-zero on fail; PHP `Testing::discover()` eval() RCE REMOVED (literal-only parser) + confined to an explicit tests dir (no blanket require of src); descriptor builders renamed assert_*->expect_* so they no longer collide with the xUnit assert_*; Python meta-test snapshots/restores the global registry; mutation-proved; 2026-08-12) |
| File upload | 44 | `fileupload_contract.json` | 3 | 3 | 0 | UP-DEC-02, UP-DEC-03 | yes (real multipart bytes through the real parser + real temp files + a real over-limit body, no mocks; a REPEATED file field name -> a LIST in all four (no silent drop; Python `_parse_multipart`/`_is_file_value`, PHP `parseMultipartBody`, Ruby a raw-body hand-scan since Rack collapses repeats, Node already listed), single stays a scalar descriptor; ONE safe-save helper per lang (`save_upload`/`saveUpload`/`Request::saveUpload`) strips path components + realpath-confines so a `../` name is written INSIDE the target dir and an unusable name is refused; a RUNNING per-chunk size guard brings PHP (`Server::enforceRequestLimits` on actual bytes) and Ruby (`read_stream_capped` over `rack.input`) to Python/Node parity, refusing 413 as the bytes arrive; mutation-proved; 2026-08-12) |
| ORM result caching | 25 | `ormcache_contract.json` | 3 | 3 | 0 | CACHE-DEC-01 | yes (real SQLite, real rows, real ORM writes, no mocks; CACHE-DEC-01 owner-override: KEEP the explicit `Model.cached()` and FIX its invalidation, do NOT drop it. Three fixes identical in all four: BUST ON ALL WRITES -- save AND delete AND force_delete AND restore through the ORM invalidate the cached read (before: only Python's save() busted; PHP/Ruby never busted; Node's drifted-in cached() never busted); TAG BY EVERY TABLE the query touches -- the model's own table plus every FROM/JOIN table -- so a cross-table JOIN cached on one model is busted when the OTHER model writes, while a write to an UNRELATED table leaves it intact (tag-scoped, never a wholesale flush); `ttl<=0` = NO-CACHE, not infinite. Node's `cached()` (which had drifted into existence since the audit as a per-class, untagged, never-busted store) rebuilt onto the ONE process-wide tag-aware query cache shared by all models; PHP switched off the untagged SQLTranslator static cache onto the existing tag-aware `QueryCache` (zero new deps). Proven POSITIVELY that it caches -- a DIRECT non-ORM db write between two reads is invisible to the second within-TTL read; mutation-proved: drop the write-bust -> stale-after-write RED, make ttl=0 cache -> ttl-zero RED, wholesale-flush -> unrelated-table RED; 2026-08-12) |
| Race-safe database next-id | 16 | `nextid_contract.json` | 2 | 2 | 0 | NEXTID-DEC-01, NEXTID-DEC-02 | yes (real PostgreSQL + MySQL + MongoDB, real concurrent callers, no mocks; NEXTID-DEC-01 fixes the generic get_next_id TOCTOU + the PostgreSQL first-use race: the generic tina4_sequences fallback is now ONE atomic `UPDATE ... SET current_value = current_value + 1 ... RETURNING current_value` (was UPDATE then a SEPARATE SELECT -- two concurrent callers read the same value and returned a DUPLICATE id), and PostgreSQL bootstraps with `CREATE SEQUENCE IF NOT EXISTS` + always draws from `nextval()` so two concurrent first-callers share ONE counter instead of the loser drawing a duplicate from a second one; proven with N concurrent callers each on their OWN connection (Python threads, PHP `pcntl_fork` children, Ruby threads, Node `Promise.all` over N independent adapters) returning N DISTINCT ids on a fresh PG table, through the generic fallback directly, and on MySQL's LAST_INSERT_ID path. NEXTID-DEC-02 gives MongoDB ONE dedicated atomic path in all four -- `findOneAndUpdate({_id: seq}, {$inc:{current_value:1}}, {upsert, returnDocument:after})` keyed by `_id` (built-in unique index = race-safe first-use) -- replacing PHP's swallow-to-`return 1` (a duplicate-PK collision) and Ruby's/Node's fall-through to the relational path where the `+ 1` UPDATE was dropped and every call returned the SAME id; proven monotonic (id2 > id1) and concurrency-safe (N concurrent -> N distinct). ZERO new runtime deps. Mutation-proved: revert the fallback to UPDATE-then-separate-SELECT -> the generic-concurrency case goes RED (a duplicate); drop the `$inc` -> the mongo-monotonic case goes RED (id2 == id1); 2026-08-12) |
| Background tasks | 47 | `backgroundtasks_contract.json` | 3 | 3 | 0 | BG-DEC-01, BG-DEC-02 | yes (real runtime, no mocks; BG-DEC-01: a task scheduled via `background()` RUNS under the PRODUCTION runtime, not just a dev built-in -- Python now starts tasks from the ASGI lifespan startup so they tick under a REAL uvicorn (BG-PY-PROD-NOOP; one shared `_spin_up_background_tasks` on both servers) + drives the REAL lifespan protocol in-process; PHP runs them in the REAL persistent socket server child + a LOUD FPM/Swoole SAPI guard (`App::backgroundSapiWarning`) that warns with the remedy, never a silent drop; Ruby a REAL OS thread, Node the REAL event-loop timer; BG-DEC-02: ONE surface pinned all four -- `background(cb,interval)` -> a HANDLE with a boolean `stop()` plus a `count` (Ruby gains `Tina4::Background.count` + a Hash-accessible `Task` handle so old descriptor reads still work; PHP gains `Tina4\BackgroundTask`, BREAKING from fluent `$this`; Node `stop()`->bool); mutation-proved; 2026-08-12) |

**Totals: 145 invariants, 129 proven, 16 owed** (2026-08-12), 26 fixtures. Proven
subsystems remain held to their contract four-way. Logger and database adapter
now have decision-complete answer keys whose runners are honestly owed. Messenger closed
last: the read/send shapes were already unified by the 3.13.96 parity commits
(decisions G4-G7), so the suites prove shipped behaviour; ADR-0042 records the
uid-is-the-IMAP-UID rule. Both messenger follow-ups closed 2026-08-07 (#69/#70)
and are now GATED by `msg-read-item-shape`: attachment bytes fold into
`attachments[i].content` in all four (the Python-only `attachments_data` retired),
and PHP trimmed `msgno`/`message_id`/`seen`/`flagged`, so `read()` returns exactly
the ten canonical keys everywhere - proven against real GreenMail with a real
binary attachment.

## Layer 1 only: audited and decided, no fully proven machine-checked fixture yet

These closed through an audit + a `features/NNN` plan (+ an ADR where a fork
existed), but do not yet have a JSON contract fixture. They are specified by
their plan and ADR, and are the first candidates to promote to Layer 2.

| Feature | Plan | Decision / ADR | State |
|---|---|---|---|
| 1 DotEnv parser | `features/001-dotenv.md` | SYNTHESISE | **contract complete 2026-08-09; implementation pending after full audit** |
| 2 Structured logger | `features/002-structured-logger.md` | SYNTHESISE | **contract complete 2026-08-09; 59-case shared fixture exists, all 8 invariant groups owed in runners** |
| 3 DB adapter interface | `features/003-database-adapter-interface.md` | ADR-0044 REDESIGN | **contract complete 2026-08-10; 40 cases across 8 owed invariant groups; implementation pending** |
| 5 Database facade + safe write path | `features/005-database-write-facade.md` | GAP (P1) | closed, 1 deferred to Feature 24 |
| 4 DATABASE_URL parser | `features/004-database-url-parser.md` | PROMOTE php | shipped all 4 |
| 33 Middleware pipeline | `features/033-middleware-pipeline.md` | ADR-0014 | closed, merged to v3 |
| 39 Graceful shutdown | `features/039-graceful-shutdown.md` | ADR-0017 | closed, merged to v3 |
| 34 CORS middleware | `features/034-cors-middleware.md` | ADR-0018 | closed (deny by default) |
| 35, 30, 32 Rate limiter / response types / route groups | - | ADR-0019 | closed, merged to v3 |
| 17 ORM base class | `features/017-orm-base-class.md` | PROMOTE ruby | closed |
| 20 Soft delete | `features/020-soft-delete.md` | GAP | closed, 1 outstanding |
| 21 Relationships + eager load | `features/021-relationships.md` | PROVISIONAL | closed |
| 23 Scopes | `features/023-scopes.md` | SYNTHESISE | closed |
| 18 Field mapping | `features/018-orm-fields.md` | ADR-0008 | closed |
| 24 Paginated results | `features/024-paginated-results.md` | PROMOTE php | **RE-OPENED 2026-08-05** - `.count` means true-total in 2 of 4, rows-returned in the other 2; the envelope launders a truncation. Breaking fix pending. |
| 25 Result / ORM caching | `features/025-orm-result-caching.md` | CACHE-DEC-01 | **promoted to Layer 2 2026-08-12 -- `ormcache_contract.json`, 3 invariants proven all four** |
| 19 Input validation | `features/019-input-validation.md` | PROMOTE node | closed |
| 15 Migrations | `features/015-migrations.md` | SYNTHESISE (provisional) | **audit in progress 2026-08-08** - confirmed code-discovery, rollback-history, and four-way result-shape defects; fixture and fixes owed |
| 48 Frond lexer | `features/048-frond-lexer.md` | historical bundle promoted Python structure | reopened / queued |
| 49 Frond parser | `features/049-frond-parser.md` | historical bundle promoted Python structure | reopened / queued |
| 50 Frond compiler | `features/050-frond-compiler.md` | historical bundle promoted Python structure | reopened / queued |
| 51 Frond runtime | `features/051-frond-runtime.md` | historical bundle promoted Python structure | reopened / queued |
| 52 Frond filters | `features/052-frond-filters.md` | SYNTHESISE | closed |
| 57 Auto-escaping | `features/057-auto-escaping.md` | UNIFORM | closed, 1 owner call |
| 58 Sandboxing | `features/058-sandboxing.md` | PROMOTE php (P1) | shipped all 4 |
| 81 Api / HTTP client | `features/081-api-client.md` | frameworks-outrank-internal | `send_request` unified 2026-08-07 (Python was the outlier; Ruby cannot use bare `send`). No fixture yet. |

## Layer 0: not yet audited

Every audited feature so far found something broken and invisible - none came
back clean - so these are unexamined, not "probably fine" (98-feature-audit.md).
Each still owes the full pipeline: audit -> plan -> ADR -> fixture -> proven.

- **Feature 15 Migrations moved to Layer 1 on 2026-08-08.** See
  `features/015-migrations.md` for the in-progress audit.
- Every other queued packet is listed in numeric order in
  [01-FEATURE-MATRIX.md](01-FEATURE-MATRIX.md).

The authoritative live list is the flat feature matrix and catalog JSON.

## Keeping this map current (the discipline)

This map only earns its name if it stays synced. On each of these events, update
the matching row here in the SAME change:

- **A feature audit closes** -> add/move its Layer 1 row, cite its `features/NNN`
  plan and ADR.
- **A fixture is written or an invariant flips owed -> proven** -> re-run
  `scripts/audit-contract-fixtures.py`, copy its proven/owed counts into Layer 2.
- **An ADR is allocated** -> cite it on the invariant and the row.
- **A feature moves out of Layer 0** -> strike it from the not-yet-audited list.

The auditor's own numbers, never a hand count, are the source of truth for
proven/owed. A row here that disagrees with the auditor is a bug in this file.

## Snapshot (2026-08-07)

- 98 numbered rows, with 21-26 retired into database-adapter group 4; feature 27
  is now under audit. Do not derive a remaining count from the retired numbers.
- 12 contract fixtures, 90 invariants, **74 proven / 16 owed**. Logger and
  database adapter are the two decision-complete, implementation-red packets.
- 41 ADRs allocated (`decisions/`), highest ADR-0041; ADR-0042 authored this
  release for the messenger uid rule.
- The path to a formal language spec: every Layer-0 feature reaches Layer 2, the
  owed count reaches 0, and MASTER-SPEC is regenerated from the fixtures + ADRs.
