# CONTINUE - Tina4 maintainer handover (2026-08-18, updated during-session)

## Session log — 2026-08-18 second pass (added by Claude)

**Audit bug batch for 3.13.105 — Python master shipped, 3 sibling ports in
flight.** Answering the owner's question "why don't our test fixtures solve
for these bugs?" revealed the queue-contract fixture's 7 invariants all test
SURFACE (does this method exist and reach a backend) — none test cross-API
consistency between two spellings of the same intent. Every bug in this batch
lived in exactly that seam.

Python master commit `38b7bfd` on `feature/release3.13.105` fixes 4 of 5 audit
bugs test-first + mutation-proven, plus doc-parity docstrings on
`Queue.size()`/`failed()`/`dead_letters()`:

- **PY-06-22** — `Model.clear_cache()` now cascades to `db.cache_clear()` on
  the model's bound connection so an out-of-band write / deliberate refresh /
  race under `TINA4_AUTO_CACHING=true` + `TINA4_DB_CACHE=true` cannot leave
  stale rows in `db.fetch()`'s persistent cache. Regression:
  `tests/test_model_clear_cache_cascades_to_db.py` (2 cases, both mutation-
  proven).
- **PY-12-04** — `Queue.retry()` no-arg materialises the `retry_job()` call
  over every dead letter before reducing. The old
  `any(backend.retry_job(j.id) for j in dead)` generator inside `any`
  short-circuited on the first truthy result, so a queue with N dead letters
  revived exactly one and silently left N-1 in the store. Regression:
  `tests/test_queue_retry_all_revives_all.py` (2 cases, mutation-proven).
- **PY-12-05** — `LiteBackend.retry(job)` now unlinks the dead-letter file
  before requeuing. A caller iterating `dead_letters()` and calling
  `job.retry()` on each used to leave the store carrying every "revived"
  job, so the next `dead_letters()` re-returned them and consumers processed
  each twice. Regression: `tests/test_queue_job_retry_removes_dead_letter.py`.
- **MongoDB `retry_job(id)` + `purge(status)`** — `retry_job` now looks the
  doc up in the `.dead_letter` topic namespace by `data.id`, deletes the
  DL record, and upserts the original back to pending. Pre-fix the filter
  `{_id, self._topic, "failed"}` could never match a dead letter (three
  reasons: wrong `_id`, wrong topic, wrong status). `purge` now returns
  `deleted_count`, honours every status, and scopes the delete so
  `purge("pending")` no longer nukes completed/reserved docs under the same
  topic. Regression: `tests/test_queue_mongo_retry_and_purge.py` — real
  MongoDB, **skips-if-unreachable**, mutation-proven locally against a
  transient container that has been stopped (Docker was killing the
  workstation). Needs re-verification on the .99 lab.

- **PY-12-06/08 — RECLASSIFIED as API-naming semantics, not a bug.**
  `_DEAD_STATES = ("failed","dead","dead_letter")` is intentional:
  `size("failed")` counts the dead-letter store (matching `dead_letters()`
  length), while `failed()` returns retryable-but-attempted jobs that live
  in the pending queue. An attempted fix broke 4 dev-admin panel tests that
  lock in the historical semantics. **Owner decision received: keep the
  current behaviour and get documentation into strict parity across the 4
  frameworks.** Docstrings on `size()`/`failed()`/`dead_letters()` in
  Python (this commit) call out the alias grouping under `size()` and the
  fact that `failed()` results ALSO count under `size("pending")`. The 3
  sibling ports are propagating the same docstring text.

**Ports in flight (background, this session).** Three parallel `tina4-dev`
agents were launched to port the 4 fixes + docstring parity to
`.worktrees/release-3.13.105/tina4-{php,ruby,nodejs}` on
`feature/release3.13.105`. Each agent is briefed to: read Python master
`38b7bfd`, apply the 4 fixes test-first + mutation-proven with a
skip-if-unreachable Mongo test, propagate the docstring parity, and push
one atomic commit per framework. They will report back independently.

**Still to do before .105 tags** (task 81):
1. Land sibling ports (waiting on the 3 agents).
2. Extend `plan/v3/fixtures/queue_contract.json` with 3 cross-API invariants
   once all 4 frameworks are green: `retry-all-revives-all`,
   `job-retry-clears-dead-letter`, `retry-job-round-trips`. NOTE:
   `size-per-status-agrees-with-list-per-status` was dropped from the
   original plan — the size/failed disagreement is API-naming, not a bug.
3. Lab-verify all 4 (MongoDB retry_job test needs the live Mongo the lab
   provisions under `TINA4_REQUIRE_SERVICES=1`).
4. Owner tag approval, merge to v3, cut `v3.13.105`.

## Session log — 2026-08-18 (added by Claude)

Work done during this session, on top of what the "Start here" section below
already records. All landed commits ride on the `.105` release branches; no
tag was cut, and nothing has flowed back into `v3`.

**Node PR #48 (rate limit) — CLOSED.** Owner decided to keep parity at 100/60s
across all four frameworks. Closed with a public comment explaining the
parity-preserving reasoning; the `TINA4_RATE_LIMIT_MAX` / `_WINDOW` overrides
remain the escape hatch for any deployment that needs more headroom.

**Python issue #103 (misleading `auth=required` log on `@noauth()` routes) —
FIXED on .105 and pushed.** Root cause: Python decorators apply bottom-up, so
`@post()` runs before the outer `@noauth()` and `_register_route` logs the
default auth value while the outer decorator flips it a microsecond later.
Fix in `tina4_python/core/router.py`: `@noauth()` and `@secured()` now emit a
corrective `Log.debug("Route auth updated: ... via @noauth|@secured")` line
whenever they flip the flag on an already-registered route. Real regression at
`tests/test_router_auth_log_honesty.py` (5 cases: positive per decorator,
negative "no corrective line when nothing changed", and the exact three-route
scenario from the issue). Proven a real gate by mutation. Cross-framework
audit: Ruby's registration log does not include an auth field, and PHP/Node
don't log at register time — this bug was Python-only, no sibling fix needed.
Commit `92f2884` on `feature/release3.13.105`.

**PHP PR #195 (CSP-clean dev toolbar) — LANDED on .105, PR left open for
release-time auto-close.** Owner scope: ship PHP only in `.105`, defer Python
+ Node parity to `.106`. Merged the PR's commit `ca670a84` into
`feature/release3.13.105` as commit `7966c55b`; the three failing tests
(`DualPortReloadTest::testMainPortInjectsReloadScript`,
`::testSuppressionTogglesPerRequest`,
`DevReloadWsTest::testInjectedClientIsWebSocketPrimary`) were updated to
assert against the new external-asset shape (`data-reload="1|0"` on the
toolbar root, `<script src="/__dev/toolbar.js">`, WS-primary spelling verified
inside the JS via reflection on the private `DevAdmin::toolbarJs()`). Two
previously-vacuous suppression tests (`testAiPortSuppressesReloadScript`,
`testInjectedClientSuppressedOnAiPort`) were also strengthened to assert on
`data-reload="0"`; without that, pinning `$reload = '1'` in `DevAdmin.php`
(broken suppression) would have left them green. Proven a real gate by
mutation. 11/11 pass in the two files, 181/181 across the broader
DevAdmin/reload/toolbar suite locally. Commit `7d7777cf`.

**PR #195 will close automatically when `feature/release3.13.105` merges to
`v3` at release time — do not close it manually.** A public comment on the PR
records the plan and credits @justin-k-bruce (co-authored on the merge
commit).

**Python + Node parity for the CSP-clean toolbar — TRACKED as
tina4-python#115 for `.106`.** Measurable drift filed with counts (Python 22
inline styles / 4 onclick / 6 inline scripts; Node 22 / 4 / 5; Ruby already
clean). References the PHP commits so the port has a working model.

**Python issue #102 (hot-reload does not re-register ORM field metadata) —
FIXED on .105 and pushed.** Root cause: `_auto_discover` re-imported the
changed model module (`src.orm.Todo`) but left every OTHER `src/*` module
that did `from src.orm.Todo import Todo` holding a reference to the OLD
class object. Python's `from X import Y` binds by object, not name, so a
route module that captured `Todo` at ITS first import kept using the stale
class -- with the stale `_fields` list -- so a newly added column was
silently absent from `to_dict()` output. The DB write was correct; the API
just lied. Fix in `tina4_python/core/server.py`: new
`_cascade_reload_dependents` helper walks in-scope modules in `sys.modules`,
detects any attribute whose `__module__` matches the reloaded module (the
fingerprint of a `from X import Y` binding into an unchanged file), and
re-imports those dependents so their `from` bindings refresh. Recursive
with a visited-set (transitive dependents refresh, cycles safe), bounded
to the discovery scope, fail-loud. Regression at
`tests/test_hot_reload_cascade.py` (3 cases: direct dependent, transitive
across two hops, negative "no cascade when no dependent"). Proven a real
gate by mutation. 87/87 across the broader router+hot-reload+auto-discover
suites still green. Commit `3df8895` on `feature/release3.13.105`.

**Cross-framework note for #102 (do in .106):** PHP resolves classes by
name at call-time (`use App\Models\User` doesn't capture a class object),
and Ruby's constants go through the constant-lookup chain, so both are
safe. Node ESM `import` DOES capture by reference, same as Python, so
Node's hot-reload path may exhibit the same shape -- an audit is owed.
Tracked as a follow-up alongside the CSP-toolbar port in `.106`.

**Docs PR #50 (Python quick-reference + Chapter 1) — REBASED and updated.**
`main` had moved forward with SSO / GIS / IoT / mail-safety / metrics-baseline
work since the PR was branched, but nothing else touched the two files in
the PR (`docs/python/01-getting-started.md`, `docs/python/index.md`), so
the rebase produced a single-hunk conflict on the intro paragraph. Resolved
as a hybrid: kept the PR's zero-dependency emphasis AND the Chapter 38
link, plus `main`'s careful "135-entry feature catalog; inventory, not a
claim that every entry has reached parity" framing (the count is now 135,
not 97; `docs/python/38-feature-list.md` confirms the link resolves). Also
resolved the PR's open `assert_*` vs `expect_*` question against released
code: `tina4_python.Testing` on 3.13.104 exports only `expect_*` -- the
rename shipped after 3.13.98, so the PR's original `assert_*` snippets were
now wrong; four lines updated to `expect_*`. `audit-truth.py --strict`
passes cleanly on the result. Force-pushed to `MichaelC8E/tina4-documentation:
docs/python-consistency-fixes`, PR head is now `799dbef`, mergeable.

**Book PR #152 (Chapter 1 Python) — REBASED with the same hybrid fix.**
Same intro-paragraph conflict, same resolution. Book Chapter 1 doesn't
touch the Testing section so no `expect_*` change was needed here. Pushed
to `MichaelC8E/tina4-book:docs/python-consistency-fixes`, PR head
`82aaffe`, mergeable. Both PRs are ready for owner merge as a pair (per
the PR body's explicit "both PRs should land together" note --
`sync-books.sh` would otherwise overwrite the docs-site copy of Chapter 1).

**Critical tina4-python skill drift — FIXED on .105.** Owner reported: the
`tina4-developer-python` skill's `references/deployment.md` said
`JWT_SECRET` in three sites (docker-compose env block, `docker run -e ...`,
deployment checklist). The framework reads only `TINA4_SECRET`. Following
the skill produced a container that boots with `TINA4_SECRET` blank; the
v3.12 boot guard does NOT catch `JWT_SECRET` (the name was invented by the
skill and was never a legacy alias), and in production `Auth.ensureDevSecret`
only warns on a blank secret rather than refusing to boot. Result: JWTs
signed with the empty string -- **forgeable tokens shipped straight from
the deployment checklist**. Cross-framework audit: `deployment.md` in the
PHP, Ruby and Node developer skills does NOT carry the same drift; shared
skills (tina4-maintainer, tina4-js) are clean. Fix on
`feature/release3.13.105`: commit `86abc01`. The `tina4/install-skills.sh`
installer ref stays at `3.13.102` until `.105` tags, then bumps to
`3.13.105` so a `curl … | sh` reinstall picks the fix up.

**All four .105 branches — VERSION BUMPED + CHANGELOG DRAFTED and pushed
to origin.** Python `86abc01` (was `44e149f` before the skill-drift fix
above), PHP `e16991a5`, Ruby `19f1381`, Node `d445b0f`. Each commit bumps the manifest / version constant / (Node
package-lock) / `CLAUDE.md` pointer to 3.13.105, and prepends the
framework-specific CHANGELOG entry (common intro + per-framework
extras). No other code touched. Ruby and Node .105 branches are now on
origin for the first time (previously local-only). Python's
`test_version_constant.py` still passes with the new literal.

Every .105 code fix landed this session is on the pushed branches:

| Framework | Branch HEAD | Ahead of origin/v3 |
| --- | --- | ---:|
| tina4-python | `86abc01` | 5 |
| tina4-php | `e16991a5` | 6 |
| tina4-ruby | `19f1381` | 2 |
| tina4-nodejs | `d445b0f` | 4 |

### What is left before .105 can ship

Only steps that need lab access (`andre@192.168.88.99`) or owner
approval. Per the "Recommended order" section below (steps 6-8):

1. **Merged-head lab suites** on the .105 branches under
   `TINA4_REQUIRE_SERVICES=1` on the lab, one framework at a time, and
   quote the summary line (never the exit code). Record any skips,
   warnings, and qualified infrastructure failures.
2. **Merge `feature/release3.13.105` -> `v3` in each repo**, then re-run
   lab suites on the merged commits to catch any semantic-merge issue.
3. **Request owner approval for tags.** `.105` on all four repos is a
   bug release; no breaking changes; but the "Do not cut tags or
   publish packages without Andre's approval" rule still stands.
4. **Bare tag `3.13.105`, publish** to PyPI / Packagist / RubyGems / npm
   (the tag triggers each repo's publish workflow), verify each
   registry lists 3.13.105, then update the docs release-notes
   chapter (`docs/<framework>/36-releases.md`) with the release date +
   framework-specific highlights.
5. **Close the shipped issues** once the release is live: tina4-python
   #104 (safe routes), #103 (auth log), #102 (hot-reload cascade).
6. **After .105 ships, the .106 backlog is:**
   - CSP-clean dev toolbar port to Python + Node (tina4-python#115 with
     measurable drift counts and PHP reference implementation).
   - Node hot-reload cascade parity for the same issue #102 mechanism
     (Node ESM `import` captures by reference like Python).
   - Docs PR #50 + book PR #152 landed post-release (they only touch
     Python docs, no code coupling).

**Branches pushed to origin (both were local-only before this session):**
`tina4-python/feature/release3.13.105` and
`tina4-php/feature/release3.13.105`. Ruby and Node .105 branches remain
local-only.

### Remaining .105 work (unchanged from the plan below, minus what shipped)

1. **Python #102** — reproduce the hot-reload ORM field-metadata staleness on
   a minimal real-file case, fix class/module invalidation, audit the same
   reload path in PHP, Ruby, Node.
2. **Docs PR #50** (`tina4-documentation`) + **book PR #152** — rebase against
   current `main` and fact-check each claim against released code.
3. **Version bumps + changelogs** — only once code scope stops moving.
4. **Merged-head lab suites** for all four frameworks under
   `TINA4_REQUIRE_SERVICES=1`.
5. **Merge `feature/release3.13.105` -> `v3` in each repo, retest, request
   Andre's approval, tag bare, publish.**

Ruby and Node .105 branches still have only the safe-routes commit locally
and need whatever `.106`-adjacent bug fixes the owner scopes in before merge
back to `v3`.

---

# CONTINUE - Tina4 maintainer handover (2026-08-18)

This file records the current release state. Read
`/Users/andrevanzuydam/.agents/skills/tina4-maintainer/SKILL.md` before changing a Tina4 repository.

## Start here

- Current public framework release: **3.13.104** for Python, PHP, Ruby, and Node.js.
- Current work: **3.13.105 bug release**.
- Release state: **not released, not tagged, and not pushed as release branches**.
- Release branches must start from each framework's `v3` branch and flow back into `v3` before tagging.
- Use isolated worktrees. The main documentation checkout contains unrelated, uncommitted SSO audit files.
- Run framework tests on `andre@192.168.88.99` with `sudo` or as root.
- Do not cut tags or publish packages without Andre's approval.

The release has three proven fixes: safe route inspection in all four frameworks, Firebird migration
ledger handling in Node.js and PHP, and removal of PHP's tracked `sqlite::memory:` file. Several open
pull requests still need decisions or more work. Do not merge them because they happen to be open.

## Public release history

| Version | State | Release fact |
| --- | --- | --- |
| 3.13.100 | Shipped | Frond fixes, skill installer retry/fallback work, and framework parity fixes. |
| 3.13.101 | Shipped | Provider-neutral application AI client in all four frameworks. Framework-owned metrics commands were removed. |
| 3.13.102 | Skills only | No framework runtime package was broken or republished for this number. |
| 3.13.103 | Shipped | Tina4 Metrics handoff, release truth guards, corrected skills and documentation. |
| 3.13.104 | Shipped | Provider-neutral OIDC SSO and GIS Point support at parity, with shared fixtures and lab proof. |
| 3.13.105 | In progress | Bug release. No tag, registry publication, or GitHub Release exists yet. |

Do not repeat the `.100` through `.104` release work. The old handover ended at `.100` and is no
longer a valid guide.

## 3.13.105 worktrees and commits

The isolated release root is:

`/Users/andrevanzuydam/IdeaProjects/.worktrees/release-3.13.105/`

| Repository | Branch | Current local HEAD | State |
| --- | --- | --- | --- |
| tina4-python | `feature/release3.13.105` | `1232afc` | One local route-inspection commit over `v3`. |
| tina4-php | `feature/release3.13.105` | `eca78c90` | Route fix plus merged PHP PRs #196 and #197 from `v3`; two commits ahead of `origin/v3`. |
| tina4-ruby | `feature/release3.13.105` | `b914531` | One local route-inspection commit over `v3`. |
| tina4-nodejs | `feature/release3.13.105` | `0454a7c` | Route fix plus merged Node PR #49 and its verification plan. |
| tina4-documentation | `feature/routes-safe-3.13.105` | `8bd38f5` | ADR, fixture, feature packet, matrix, and user docs for safe `tina4 routes`. |

Recheck these hashes before resuming. Remote merges can move `v3`.

## Completed and validated for 3.13.105

### Safe `tina4 routes`

Feature 115 and ADR-0058 define the rule: route inspection scans canonical route files without
executing the application entrypoint or starting its server.

| Framework | Commit | Result |
| --- | --- | --- |
| Python | `1232afc` | Uses route-only discovery; does not run `app.py`. |
| PHP | `7dc07a2c` | Uses `Router::getRoutes()` and does not include `index.php`. |
| Ruby | `b914531` | Uses route-only discovery; does not run `app.rb` or `index.rb`. |
| Node.js | `33f005d` | Uses route-only discovery; does not load `app.ts`. |

The shared fixture is `plan/v3/fixtures/cli_routes_contract.json`. The documentation commit is
`8bd38f5`. Human table columns and a possible `--json` form remain separate owner decisions; they
do not block the safety fix.

Python issue #104 describes the destructive old behavior. Close it only after the fix reaches `v3`
and the release is available.

### Firebird migration ledger

- Node.js PR #49 is merged into `v3` at `3651f11`.
- The Node.js `.105` branch merged that `v3` state at `fac49a2`.
- Node.js plan commit: `0454a7c`.
- PHP PR #196 is merged into `v3` at `0913adcc`.
- PHP PR #197 is merged into `v3` at `5bb20ebd`.
- The PHP `.105` branch merged both at `eca78c90`.

The Firebird fix handles generated migration-ledger IDs without assuming one database-specific
result-column case. PHP PR #197 also removes a tracked file named `sqlite::memory:`. The colon made
Windows checkouts fail.

### Lab evidence

Node.js merged-head gate:

- Full suite: **8,302 passed, 0 failed, 33 skipped across 325 files**.
- Live Firebird ledger: **3/3 passed**.
- Firebird column-case coverage: **2/2 passed**.
- Verification plan:
  `/Users/andrevanzuydam/IdeaProjects/.worktrees/release-3.13.105/tina4-nodejs/plan/firebird-migration-ledger-3.13.105.md`.

PHP PR #196 and #197 combined gate:

- Live Firebird ledger: **1 test, 4 assertions, passed**.
- Route safety: **1 test, 4 assertions, passed**.
- Full suite: **5,456 tests, 18,999 assertions, 3 failures, 57 skipped**.
- All three failures are the unchanged baseline `SessionDatabaseEnginesTest` MSSQL connection
  failures against `127.0.0.1`. The same failures occur without these PRs. Do not report this run as
  fully green; report it as qualified by the unavailable MSSQL service.

Lab review copies used during validation can be removed after confirming no process uses them:

- `/home/andre/php-pr196-197-review-20260818`
- local review worktree `/tmp/tina4-php-pr196-197-review-20260818`

## Open pull requests that need work or a decision

| PR | Current state | Required action |
| --- | --- | --- |
| [tina4-nodejs#48](https://github.com/tina4stack/tina4-nodejs/pull/48) | Targets stale `main`; raises only Node's default request limit from 100 to 1,000. | **Do not merge as written.** All four frameworks use 100 requests per 60 seconds. Andre must choose: keep 100 and close the PR, or define a shared contract and move all four to 1,000. Keeping 100 is the parity-preserving recommendation. |
| [tina4-php#195](https://github.com/tina4stack/tina4-php/pull/195) | CSP-clean dev-toolbar assets, but the main PHP test job is red. The same CSP concern may exist in the other frameworks. | Repair the three stale reload tests, audit all four dev toolbars, add a parity fixture, then merge only after the shared behavior is proven. |
| [tina4-documentation#50](https://github.com/tina4stack/tina4-documentation/pull/50) | Python quick-reference corrections; conflicts with current `main`. | Rebase and reconcile each claim against released code. Do not resolve conflicts by choosing one side wholesale. |
| [tina4-book#152](https://github.com/tina4stack/tina4-book/pull/152) | Companion Chapter 1 corrections; conflicts with current `main`. | Reconcile with documentation PR #50 and current generated-book source. Keep the website, books, and PDFs aligned. |

PHP PRs #196 and #197 and Node.js PR #49 are already merged. Do not repeat those merges.

Other open organization PRs are outside the four-framework `.105` line unless Andre expands the
scope: `tina4delphi` #1 and #7, `tina4php-postgresql` #3, `tina4php-shopify` #18, and `tina4-cms` #6.
Audit their age and target branches before touching them.

## Open issues relevant to the release audit

| Issue | State | Next step |
| --- | --- | --- |
| [tina4-python#104](https://github.com/tina4stack/tina4-python/issues/104) | Fixed on the local `.105` route branch. | Land, release, verify, then close. |
| [tina4-python#103](https://github.com/tina4stack/tina4-python/issues/103) | Reproduced on current `v3`: an outer `@noauth()` route can log `auth=required` during registration even though the route is public. | Fix the misleading log and add a regression. Check visible logging behavior in the other frameworks before calling it parity. |
| [tina4-python#102](https://github.com/tina4stack/tina4-python/issues/102) | Still unresolved: hot reload can retain stale ORM field metadata through an unchanged route module's old model import. | Build a minimal real reload reproduction, fix class/module invalidation, and check the equivalent reload path in every framework. |
| [tina4-book#148](https://github.com/tina4stack/tina4-book/issues/148) | Documentation discrepancy around `tina4 serve -p/--port` and project launchers. | Verify current CLI behavior and correct all affected chapters and quick references. |
| [tina4-book#144](https://github.com/tina4stack/tina4-book/issues/144) | Old queue audit findings. Some may already be fixed. | Reproduce each claim against 3.13.104 before closing or scheduling work. |
| [tina4-book#142](https://github.com/tina4stack/tina4-book/issues/142) | Old ORM audit findings. Some may already be fixed. | Reproduce each claim against 3.13.104 before closing or scheduling work. |

The Tina4 client clustering/tuning issue is backlog work, not an automatic `.105` blocker.

## Recommended order of work

1. Ask Andre for the rate-limit decision on Node.js PR #48.
2. Reproduce and fix Python issues #103 and #102. Audit the same contracts in PHP, Ruby, and Node.js.
3. Decide whether the CSP toolbar repair belongs in `.105`. If yes, repair PHP PR #195 and implement
   one shared behavior across all four frameworks.
4. Rebase and fact-check documentation PR #50 and book PR #152. Regenerate and verify PDFs when the
   source chapters change.
5. Add versions and changelogs only after the `.105` code scope stops moving.
6. Run clean, merged-head lab suites for all four frameworks. Use live database services and record
   skips, warnings, and qualified infrastructure failures without hiding them.
7. Merge the release branches into `v3`, retest the exact merge commits, and request Andre's release
   approval.
8. Tag, publish, verify public registries and GitHub Releases, update website release notes, then
   close only the issues proven fixed by the public release.

## Release gates

Before tagging `.105`, prove all of the following:

- Package and runtime versions agree in every framework.
- The shared fixtures pass in all four framework runners.
- `tina4 routes` lists a canonical route and never executes the application entrypoint.
- Firebird migration ledgers work against the real lab service.
- Full suites run from the exact merged release commits.
- Docker images start and report the release version.
- Changelogs, four language release chapters, quick references, landing-page notes, and PDFs state
  the same facts.
- The framework source does not regain a second metrics engine. Dev Admin hands analysis to the
  signed Tina4 client.
- No package list calls a language extension a dependency. A dependency is an extra package that a
  developer must install for the feature to work.
- Tags are bare framework tags such as `3.13.105`; do not invent a `v3.13.105` package tag.

## Lab recipe

Connect with:

```sh
ssh andre@192.168.88.99
sudo -i
```

Use `/root/tina4-lab/lab-env-for.sh <py|php|rb|node>` for the framework service environment. Add the
ODBC DSN variables when testing ODBC; the helper does not set them. Use
`TINA4_REQUIRE_SERVICES=1` when a gate must fail instead of skipping unavailable services.

For PHP Firebird ledger validation, the proven URL was:

```sh
TINA4_TEST_FIREBIRD_URL='firebird://SYSDBA:masterkey@localhost:3050//var/lib/firebird/data/tina4test.fdb'
```

Do not run four network-heavy skill-installer tests in parallel. GitHub Raw has produced transient
503 responses under that load. The installer has retry and jsDelivr fallback logic, but a release
gate should still record which endpoint failed.

## Documentation checkout warning

`/Users/andrevanzuydam/IdeaProjects/tina4-documentation` is on local `main`, 19 commits behind
`origin/main`, and contains unrelated uncommitted SSO audit work under `plan/v3`. Do not pull,
rebase, reset, clean, or commit the whole checkout. Preserve these files:

- modified feature matrix, contract map, decisions, catalog, and generator files;
- untracked `plan/v3/decisions/ADR-0056.md`;
- untracked `plan/v3/features/136-oidc-sso.md`;
- untracked `plan/v3/fixtures/sso_contract.json`.

Use an isolated worktree for `.105` documentation. This `CONTINUE.md` replacement is the only
intentional change in the main checkout for this handover.

## Commit discipline

- Keep one subject per commit.
- Include tests or recorded verification with each runtime fix.
- Use the Tina4 trailer on maintainer commits:
  `Co-Authored-By: Tina4 <82961293+tina4stack@users.noreply.github.com>`.
- Never call a release complete until the public package registries and GitHub Releases agree.

One branch. One gate. One set of facts. The tag comes last.
