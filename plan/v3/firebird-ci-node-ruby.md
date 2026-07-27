# Systemic: wire live Firebird into Node + Ruby CI (close the coverage leak)

## Why
Every genuine behavioral bug this session clustered in Firebird — a DB engine with
NO live CI in Node/Ruby, so the no-mock firebird tests SKIP and the bug is only
found by hand. PHP got a dedicated firebird CI job this session (found 3 real bugs).
Node + Ruby still have none. Fix = give them the same job so the class of bug fails
in CI, not in production.

## Precise framing
The `EXCLUDED_KEYWORDS=["firebird"]` in the Node/Ruby service gates is NOT the leak
— it is CORRECT for the main multi-service job (Firebird isn't provisioned there, so
its skips must stay green). The leak is the ABSENCE of a dedicated provisioned
Firebird job. So this change is ADDITIVE: add a `firebird:` job per repo; leave the
main job + its exclusion untouched.

## Template (proven this session): tina4-php/.github/workflows/test.yml `firebird:` job
- own ubuntu runner; `docker run firebirdsql/firebird:5.0.2 -p 3050:3050`
- isql readiness loop (fail job if FB never comes up)
- TINA4_TEST_FIREBIRD_URL=firebird://SYSDBA:masterkey@localhost:3050//var/lib/firebird/data/test.fdb
- run ONLY the firebird test files
- NO-SILENT-SKIP GUARD (the key lesson): PHP does `php -m | grep interbase` so a
  broken driver build FAILS the job instead of green-skipping.

## Node job (tina4-nodejs/.github/workflows/test.yml — NEW `firebird:` job)
- [x] start FB5.0.2 + isql wait (fails job if FB never accepts a query)
- [x] install deps + `npm install node-firebird --no-save` (the driver the firebird adapter needs).
      NOTE: used `npm install` (not `npm ci`) to mirror the green main `test` job exactly and
      avoid a lockfile-drift failure in the workspace monorepo — same lifecycle scripts.
- [x] TINA4_TEST_FIREBIRD_URL set (firebird://SYSDBA:masterkey@localhost:3050//var/lib/firebird/data/test.fdb)
- [x] run firebird test files: test/firebirdRollback.test.ts (guarded, live) + firebirdCharset + firebirdUrl
- [x] GUARD: strip ANSI, then FAIL unless the rollback test printed the ROLLBACK-undoes-insert PASS
      line AND "4 passed, 0 failed, 0 skipped"; FAIL if any `SKIP` line appears. node-firebird
      missing / URL unset / server unreachable all print a firebird SKIP → job FAILS (never green-skip).
- keep EXCLUDED_KEYWORDS=["firebird"] in test/_serviceGate.ts (correct for main job) — UNTOUCHED

## Ruby job (tina4-ruby/.github/workflows/test.yml — NEW `firebird:` job)
- [x] start FB5.0.2 + isql wait (fails job if FB never accepts a query)
- [x] apt-get install firebird-dev (libfbclient) BEFORE setup-ruby; `bundle install` with the fb gem.
      NOTE: `fb` is added to a NEW optional Gemfile group `:firebird` (NOT `:databases`) and pulled in
      via `BUNDLE_WITH=firebird`. `bundle exec rspec` isolates to the bundle, so a bare `gem install fb`
      would be invisible to it — the gem MUST be in the Gemfile. Kept out of `:databases` so the main
      `test` job (BUNDLE_WITH=databases, no firebird-dev) never tries to compile fb and stays green.
- [x] TINA4_TEST_FIREBIRD_URL / _USER / _PASS set
- [x] run firebird specs: spec/firebird_rollback_spec.rb (guarded, live) + charset + url + reconnect
- [x] GUARD: an explicit `require 'fb'` step FAILS on LoadError; the rollback step FAILS unless rspec
      reports "3 examples, 0 failures" AND has zero pending examples. fb-gem load failure / unset URL /
      unreachable server → job FAILS (never green-pending).
- keep the spec_helper firebird exclusion (correct for main job) — UNTOUCHED

## Verify (independent, no-mock)
- [ ] Push each as a PR branch; the firebird job must show the firebird tests RUNNING
      (not skipped) and passing on the GH runner. Re-read the run logs myself.
- [ ] Confirm the existing `test` job still passes (not broken by the Gemfile/workflow change).

## Sequencing
Execute AFTER the PG `_inTransaction` fix merges to Node v3 (can't run a 2nd worker in
the Node tree; and do Node+Ruby together as one coherent systemic change). Branch per
repo off v3; commit; owner gates the tag as always.

## Status: IMPLEMENTED on feature/firebird-ci (both repos) — PRs open to v3, watching CI
