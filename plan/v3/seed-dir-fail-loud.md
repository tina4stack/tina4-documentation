# Seed files fail loud (ADR-0108)

Started and finished 2026-11-22. Implements `decisions/ADR-0108.md` in all four frameworks:
a seed file that raises stops the seed-directory runner, which raises an error
naming it, and the CLI `seed` command exits 1.

## Scope

- [x] Python: `FakeData.seed_dir` + `tina4python seed`
- [x] PHP: `FakeData::seedDir` + `tina4php seed`
- [x] Ruby: `Tina4.seed_dir` + `tina4ruby seed` + dev-admin `run_seeds_payload`
- [x] Node: `FakeData.seedDir` + `tina4nodejs seed`
- [x] Full suite at HEAD in all four, red tests compared against `origin/v3` sources
- [x] One PR per framework against `v3`

## Parity

| Behaviour | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| First failing file stops the run and raises | `SeedError` | `Tina4\SeedError` | `Tina4::SeedError` | `SeedError` |
| Error fields | `seed_file`, `completed`, `__cause__` | `seedFile`, `completed`, `getPrevious()` | `seed_file`, `completed`, `cause` | `seedFile`, `completed`, `cause` |
| Message | `Seed file failed: <file>: <cause>` | same | same | same |
| Success returns the executed paths in order | yes | yes (was a `'loaded'` map) | yes (was `nil`) | yes |
| Skips `_`-prefixed files | yes | yes (new) | yes | yes (new) |
| Calls the entry point `generate seeder` writes | `run(db)` (new) | returned closure (new) | file body | `default()` or `run()` (new) |
| CLI `seed` exits 1 naming the file | yes | yes (was a fatal 255) | yes (never ran a seed before) | yes (stops instead of running the rest) |

`seed_file` / `seedFile` rather than `file`: PHP's `Exception` already owns a
`$file` property (the source file of the throw), so the field takes the same
non-clashing name in all four.

## Tests (no mocks; each proven red by mutation)

Real seed folders on disk with `001_ok`, `002_raises`, `003_ok`, a `_`-prefixed
helper that raises if loaded, the generated-seeder shape, and the real CLI run
as a subprocess.

| Framework | Test | Tests | Mutations (all red) |
|---|---|---|---|
| Python | `tests/test_seed_dir_fail_loud.py` (+ real SQLite for `run(db)`) | 7 | swallow, no `run(db)`, ignore bound db, run `_` files, any extension, CLI exit 0 |
| PHP | `tests/SeedDirFailLoudTest.php` | 6 | swallow, no closure call, run `_` files, any extension, CLI exit 0 |
| Ruby | `spec/seed_dir_fail_loud_spec.rb` | 6 | swallow, run `_` files, any extension, missing folder `nil`, CLI exit 0, CLI without the seeder load (the v3 `NoMethodError`), dev-admin not naming the file |
| Node | `test/seedDirFailLoud.test.ts` | 15 assertions | swallow, run `_` files, any extension, no `run()`, CLI runs the rest, CLI exit 0, CLI runs `_` files |

Every framework's clean-folder test also drops a `README.txt` that raises if
executed: the Node "accept any extension" mutation survived the first version
of the test, and the same gap was in all four. Added and mutation-proved in
each (PHP #376, Ruby #188 as test-only follow-ups; Python and Node in their
PRs).

Stale tests that asserted the old contract were corrected, not deleted: PHP
`SeederV3Test::testSeedDirValid` (the `'loaded'` map) and Ruby `seeder_spec`
"catches errors in seed files" (now asserts the raise).

## Bugs found while doing this

- [x] `tina4ruby seed` never ran a single seed file on v3: `seeder.rb` is
      autoloaded only through `Tina4::FakeData`, so `Tina4.seed_dir` did not
      exist when the CLI called it (`NoMethodError`, exit 1). The CLI and the
      dev-admin runner now load the seeder first; mutation-proved.
- [x] Node's metrics regression gate flagged `core/src/fakeData.ts` (cc 5 -> 8).
      `seedDir` was split into `isSeedFile` / `seedEntry` / `errorText`; the
      file now scores 4, below v3. The refactor also caught a lost backslash
      in the extension check (`/.(ts|js)$/`), replaced by `endsWith`.
- [x] Node's `seedDir` never called the named `run()` that
      `tina4nodejs generate seeder` writes, so it reported a generated seeder
      as done without seeding. ADR-0108 amended to say so.

## Commits

- [x] tina4-python: `fix/seed-dir-fail-loud` - 8dbe1045, 4abd1543 - tina4-python#331, merged 461cdb44
- [x] tina4-php: `fix/seed-dir-fail-loud` - 45d5eedf - tina4-php#375, merged c430317f
- [x] tina4-ruby: `fix/seed-dir-fail-loud` - 9c909e1 - tina4-ruby#186, merged e9c8753c
- [x] tina4-nodejs: `fix/seed-dir-fail-loud` - 93c0e85, b454696 - tina4-nodejs#214, merged 2ea3d111
- [x] tina4-php: `test/seed-dir-extension-filter` - tina4-php#376, merged 9f9d27e9
- [x] tina4-ruby: `test/seed-dir-extension-filter` - tina4-ruby#188, merged 30e13d58

## Verification (Windows 11, 2026-11-22)

Every red test in each full suite was re-run in the same worktree twice: with
the touched framework files put back to `origin/v3`, and at HEAD. Linux CI on
each PR (services provisioned) is the full-suite gate.

| Repo | Full suite on Windows | Red only at HEAD |
|---|---|---|
| Python | 138 failed + 84 errors over 50 files (`preexec_fn`, services) | 0 (221 red ids, identical on v3 sources) |
| PHP | could not finish on Windows: v3 itself aborts at the 128 MB limit (`Frond.php`), and at 1 GB a server-spawning test hangs (`proc_open(/dev/null)`) | Linux CI full suite green |
| Ruby | 7139 examples, 495 failures (`pgroup`, negative-pid kill, symlink, services) | 0 (495 identical on v3 sources) |
| Node | 449 files, 33 red (services not provisioned) | 0 (33 identical on v3 sources) |
