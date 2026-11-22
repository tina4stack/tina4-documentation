# Windows framework bugs (found by the Node Windows test run)

Started 2026-11-18. Source: the Windows portability run in tina4-nodejs#210, which
left 8 framework bugs red on Windows. Each was then checked against Python, PHP
and Ruby on `origin/v3` (spawn and filename behaviour run for real on Windows 11;
the rest read from source), and the tests written for the fixes then confirmed
or corrected that reading (Python's bug 2 is live, not latent; PHP has bug 7).

## Scope

| # | Bug | Node | Python | PHP | Ruby |
|---|---|---|---|---|---|
| 1 | Framework template dir from `import.meta.url.replace("file://", "")` | fixed | ok (`Path(__file__)`) | ok (`__DIR__`) | ok (`__FILE__`) |
| 1b | Route and model modules imported as a hand-built `file://` + path (breaks on `#`, `?`, `%` in the path, any OS) | fixed | ok | ok | ok |
| 2 | Broken-import marker name keeps the `:` of a drive letter, so NTFS writes a hidden stream and no `data/.broken/*.broken` listing finds it (Python's `/health` reads that listing; Node, PHP and Ruby only write it today, the open gap D12) | fixed | fixed (live: auto-discover passes an absolute path; the existing `test_import_failure_writes_a_broken_sentinel` was red on Windows) | fixed | fixed (the existing `.broken` spec was red on Windows) |
| 3 | `npm` / `npx` spawned without a shell: Windows only finds `.exe` that way, and Node refuses to start a `.cmd` (EINVAL). Four call sites: `tina4nodejs lint`, dev-admin package install, dev-admin `generate`, and the MCP `.ts` syntax check (which read the ENOENT as "tsc not installed" and silently skipped) | fixed | ok | ok | ok |
| 4 | `delegateToClient()` accepts `tina4.cmd` / `.bat`, then spawns them with no shell (EINVAL) | fixed | ok (ran) | ok (ran) | ok (ran) |
| 5 | Production cluster never sets `SCHED_RR`; Node's Windows default is OS scheduling | fixed | n/a | n/a | n/a |
| 6 | `FakeData.seedDir()` imports a raw path (`D:\...`, or any path with `#`) | fixed | ok (`spec_from_file_location`) | ok (`require`) | ok (`load`) |
| 7 | Database session handler opens its own connection and cannot release it | fixed (new `close()`) | ok (uses the ORM's shared db, owns nothing) | fixed (`close()` was a no-op) | fixed (new `close()`) |
| 8 | ProjectIndex keys use the OS separator (`src\routes\x`) | fixed | fixed | ok (normalises to `/`) | ok (Ruby paths use `/`) |

## Parity

- **2 (marker name)**: one rule in all four: the slug replaces `/`, `\` and `:`
  with `_`. Same marker JSON as before.
- **7 (session close)**: one rule where a handler can own a connection: `close()`
  releases a connection the handler OPENED ITSELF, never one that was injected;
  it is idempotent, and the next use reopens lazily. Python's handler never owns
  one, so it needs no change.
- **8 (ProjectIndex)**: keys, entry paths and the reported index path are always
  `/`-separated, on every OS (PHP's rule). Lookups are not rewritten (PHP does not
  rewrite them either).
- **1, 1b, 3, 4, 5, 6** are Node-only: they come from the ESM loader needing a
  URL, Node refusing to spawn batch files without a shell (its 2024 BatBadBut
  hardening), and Node's cluster module. The other three take paths directly and
  their process APIs start `.cmd` files.

## Design notes

- **3, 4 (batch-file spawn)** must not reopen BatBadBut. `packages/core/src/batchSpawn.ts`
  runs a `.cmd`/`.bat` as `cmd.exe /d /s /c "<cmd> <args>"` with
  `windowsVerbatimArguments`, each argument quoted (qntm.org/cmd rules) and every
  cmd metacharacter caret-escaped twice (once for the `/c` line, once for the
  batch file's own re-parse of `%*`). This is the cross-spawn algorithm, owned as
  ~30 lines rather than a dependency. `findExecutable()` resolves a bare `npm` to
  `npm.cmd` with PATHEXT. Everything else, and every non-Windows platform, spawns
  exactly as before.
- **5**: set `cluster.schedulingPolicy = SCHED_RR` before the first fork, unless
  the operator set `NODE_CLUSTER_SCHED_POLICY` (an explicit choice wins).

## Tests (no mocks; each proven by mutation)

| # | Test | Mutation that turns it red | Fails on Linux CI when broken? |
|---|---|---|---|
| 1, 1b, 2, 6 | Node `modulePathPortability.test.ts`: a real project under a directory named with `#`, `%41` (and `:` on Linux): routes, models and `seedDir()` load; the broken-import marker has no `:` and is listed; `getFrameworkFrond()` finds its templates; no framework source hand-builds a `file://` URL | original source: 8/8 red; slug only: the 3 marker checks red | yes, except `getFrameworkFrond` |
| 1 | errorPagesContract, errorNegotiation401Middleware500 | were red on Windows | Windows only |
| 2 | Python `test_broken_import_marker_name_drops_the_drive_colon`, PHP `testBrokenImportMarkerNameDropsTheDriveColon`, Ruby `names the broken-import marker without the drive-letter colon` | original slug: red in all three | yes (the name check) |
| 3 | cliLint 28/28 | was red on Windows (EINVAL) | Windows only |
| 4 | cliDelegatedCommands + hostile arguments (`&`, `%PATH%`, `"`, `^`, `|`, `<`, `(`, `!`, empty, trailing `\`) arrive verbatim through a real `tina4.cmd` and nothing runs | single escape: red; no batch handling: red; naive `shell: true`: red AND the injected command really ran | Linux runs the same args through a shell script |
| 5 | Node `clusterSchedulingPolicy.test.ts`: primary is RR after forking; `NODE_CLUSTER_SCHED_POLICY=none` stays NONE | drop the line: red; force RR: the `none` case red | negative case yes |
| 7 | Node `sessionHandlerClose.test.ts`, PHP `DatabaseSessionHandlerCloseTest`, Ruby `session_handler_close_spec.rb`: owned SQLite `-wal` gone after `close()`, reopens on next use, file deletable; PHP/Ruby: an injected connection's TEMP table survives `close()` | no-op close: red; close ignoring ownership: red (PHP, Ruby) | yes |
| 8 | Node projectIndex 19/19, Python `test_project_index_keys.py` (new; Python had no ProjectIndex test) | original key code: red | Windows only |

## Bugs found while doing this (not in the original 8)

- [x] Bug 3 had three more Node call sites (dev-admin install, dev-admin
      `generate`, MCP syntax check) - fixed with the same helper.
- [x] Python's bug 2 was live, not latent - fixed.
- [x] PHP's session `close()` was a no-op over an owned connection - fixed.
- [x] Node's core barrel grew to 90 modules with `batchSpawn.ts`; the
      `lazyFeatureLoading` ceiling is raised 89 -> 90 deliberately, with the
      measurement in the test and the commit.
- [x] Ruby `spec/import_helper_spec.rb` restored the stashed
      `lib/tina4/import_helper.rb` in text mode, so on Windows every full run left
      it rewritten with CRLF. It now restores by bytes and asserts byte-identity
      (red on Windows with the old write).
- [ ] Python's suite is not Windows-portable: most of its 120 failures + 84
      errors on Windows come from `preexec_fn`, which Windows does not support
      (the same class of work as tina4-nodejs#210). Pre-existing on v3; separate task.
- [x] seedDir error handling differs: Python and Node swallow a failing seed file,
      Ruby logs it and `tina4ruby seed` exits 0, PHP throws. Decided in ADR-0108
      (tina4-documentation#220): fail loud, stop at the first failing file, CLI
      exits 1. Implementation is owed in all four as its own task.

## Commits

- [x] tina4-nodejs: `fix/windows-framework-bugs` (stacked on #210) - 2345a8d, tina4-nodejs#211
- [x] tina4-python: `fix/windows-path-bugs` - c2b09eba, tina4-python#328
- [x] tina4-php: `fix/windows-path-bugs` - 3942adaf, tina4-php#372
- [x] tina4-ruby: `fix/windows-path-bugs` - 2f929ee, tina4-ruby#183

## Verification (Windows 11, 2026-11-19)

Every red test in each full suite was checked against the code without these
changes. A test that passes there and fails on the branch would be a regression.
There were none. PHP and Ruby: re-run in the same worktree with the touched
framework files put back to `origin/v3`, then at HEAD. Python: re-run on a
pristine `origin/v3` worktree. Node: compared with the tina4-nodejs#210 run.

| Repo | Full suite on Windows | Without these changes |
|---|---|---|
| Node | 24 red files, all service-dependent | all 24 already red in the #210 run |
| Python | 120 failed + 84 errors (`preexec_fn`) | all fail on pristine v3 too |
| PHP | 6817 tests, 160 errors + 84 failures, 82 files | same exit code for all 82 |
| Ruby | 7119 examples, 467 failures (`pgroup`, negative-pid kill, symlink) | same 467 |

Linux CI on each PR is the gate.
