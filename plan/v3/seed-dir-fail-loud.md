# Seed files fail loud (ADR-0108)

Started 2026-11-22. Implements `decisions/ADR-0108.md` in all four frameworks:
a seed file that raises stops the seed-directory runner, which raises an error
naming it, and the CLI `seed` command exits 1.

## Scope

- [x] Python: `FakeData.seed_dir` + `tina4python seed`
- [x] PHP: `FakeData::seedDir` + `tina4php seed`
- [x] Ruby: `Tina4.seed_dir` + `tina4ruby seed` + dev-admin `run_seeds_payload`
- [x] Node: `FakeData.seedDir` + `tina4nodejs seed`
- [ ] Full suite at HEAD in all four, red tests compared against `origin/v3` sources
- [ ] One PR per framework against `v3`

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
| Python | `tests/test_seed_dir_fail_loud.py` (+ real SQLite for `run(db)`) | 7 | swallow, no `run(db)`, ignore bound db, run `_` files, CLI exit 0 |
| PHP | `tests/SeedDirFailLoudTest.php` | 6 | swallow, no closure call, run `_` files, CLI exit 0 |
| Ruby | `spec/seed_dir_fail_loud_spec.rb` | 6 | swallow, run `_` files, missing folder `nil`, CLI exit 0, CLI without the seeder load (the v3 `NoMethodError`), dev-admin not naming the file |
| Node | `test/seedDirFailLoud.test.ts` | 14 assertions | swallow, run `_` files, no `run()`, CLI runs the rest, CLI exit 0, CLI runs `_` files |

Stale tests that asserted the old contract were corrected, not deleted: PHP
`SeederV3Test::testSeedDirValid` (the `'loaded'` map) and Ruby `seeder_spec`
"catches errors in seed files" (now asserts the raise).

## Bugs found while doing this

- [x] `tina4ruby seed` never ran a single seed file on v3: `seeder.rb` is
      autoloaded only through `Tina4::FakeData`, so `Tina4.seed_dir` did not
      exist when the CLI called it (`NoMethodError`, exit 1). The CLI and the
      dev-admin runner now load the seeder first; mutation-proved.
- [x] Node's `seedDir` never called the named `run()` that
      `tina4nodejs generate seeder` writes, so it reported a generated seeder
      as done without seeding. ADR-0108 amended to say so.

## Commits

- [ ] tina4-python: `fix/seed-dir-fail-loud` - 8dbe1045
- [ ] tina4-php: `fix/seed-dir-fail-loud` - 45d5eedf
- [ ] tina4-ruby: `fix/seed-dir-fail-loud` - 9c909e1
- [ ] tina4-nodejs: `fix/seed-dir-fail-loud` - 93c0e85
