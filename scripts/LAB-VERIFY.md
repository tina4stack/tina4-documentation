# Lab test verification recipe

Run the full test suite for all four Tina4 frameworks green on the .99 lab in
minutes, not an afternoon. `lab-verify.sh` provisions the services and runs each
suite as root with the correct environment. This file records WHY each step
exists, so the next person does not rediscover it the hard way.

## Run it

On the lab (a user with passwordless sudo):

```bash
cd ~/rel-3.13.132/tina4-documentation/scripts   # or wherever this repo is checked out
sudo ./lab-verify.sh all                          # provision + run all four
sudo ./lab-verify.sh python                       # or one framework
sudo ./lab-verify.sh provision                     # just (re)provision services
```

Expected result: `PASS` for all four. The only skips are environment-gated
(graph databases, an OIDC provider, an absent optional extension). There must be
zero failures.

Inputs (override via env):

| Var | Default | What |
| --- | --- | --- |
| `TINA4_LAB_ENV` | `~/tina4-test-env-126.sh` | service credentials + `TINA4_TEST_*` vars |
| `TINA4_REL_DIR` | `~/rel-3.13.132` | directory holding the four framework clones |
| `TINA4_FB_CONTAINER` | `tina4-lab-firebird` | Firebird docker container name |

Run as root: the session and permission tests drop `CAP_DAC_OVERRIDE`, so they
only assert correctly under a real root process.

## The provisioning steps, and why

### Firebird WireCrypt (the Node killer)

Firebird 5 defaults to a ChaCha wire-encryption negotiation that `node-firebird`
2.x cannot complete. Its connect then HANGS for the full connect timeout, which
looks exactly like a dead Firebird. The native Python, PHP and Ruby clients
negotiate the same handshake fine, so only Node breaks. The recipe sets
`WireCrypt = Disabled` in the container's `firebird.conf` and restarts it. Every
client then connects in plaintext (fine on a localhost lab); node-firebird
connects in about 40 ms.

This resets whenever the Firebird container is recreated (`fb-recreate.sh` writes
Firebird 5 defaults), so `lab-verify.sh` reapplies it every run.

### PostgreSQL per-framework databases

The four frameworks do NOT share one Postgres database. Python and PHP use
`tina4_py`, Ruby `tina4_rb`, Node `tina4_node`, and the two-database routing
tests use `tina4_analytics`. A missing one surfaces as
`database "tina4_node" does not exist`. The recipe creates all four (idempotent).

### Per-framework Firebird database

Each framework has its own file so parallel history never crosses:
`tina4_py.fdb`, `tina4_php.fdb`, `tina4_rb.fdb`, `tina4_node.fdb`. The env file
does not set `TINA4_TEST_FIREBIRD_URL`; the recipe sets it per framework.

### MinIO on port 9100

MinIO is published on host port 9100 (container 9000). The env file may still say
`:9000`; the recipe overrides `TINA4_TEST_S3_ENDPOINT` / `_URL` to `:9100`. A
closed 9100 means the S3 storage tests fail.

### Fresh Mongo per run

All four frameworks share one Mongo (`mongodb://localhost:27017`, database
`tina4`). A leftover queue index from another framework or an older version used
to collide (`IndexKeySpecsConflict`). The recipe drops the `tina4` database
before each framework runs. (The PHP MongoBackend also now tolerates a
pre-existing same-keys index, so this is belt and braces.)

### MySQL over TCP, not a socket

`mysql2`/`libmysqlclient` connects over a UNIX socket whenever the host is
`localhost`, ignoring the port, and the lab MySQL is a TCP-only container with no
socket. The recipe exports `TINA4_TEST_MYSQL_HOST=127.0.0.1` to force TCP.

### PHP: grpc and openswoole are fork-hostile

Neither is a tina4-php dependency; they were added to the lab PHP for other work.
`grpc` runs background threads whose mutexes `pcntl_fork` copies in their locked
state, so forked test children deadlock on `futex_wait` before doing anything and
the suite wedges. `openswoole` (with `enable_coroutine=On`) breaks the fork-based
worker pool so `ServerWorkerPoolTest` reports one worker. The recipe runs the main
suite with a filtered `conf.d` that excludes both, then runs `AppInvokeSwooleTest`
alone with openswoole loaded (it skips cleanly without it).

### Ruby: optional bundler groups

The `fb` (Firebird) and `ruby-odbc` gems live in OPTIONAL bundler groups. Two
traps: a local `.bundle/config` `with` value beats the `BUNDLE_WITH` env var, and
`BUNDLE_WITH` must be COLON-separated (a space-separated value is read as one
nonexistent group). The recipe sets the groups in `.bundle/config` directly
(`bundle config set --local with "databases:firebird:odbc"`), which survives a
`git reset --hard` because `.bundle/config` is untracked, then `bundle install`.

## Code fixes that shipped in 3.13.132 alongside this recipe

These were real bugs found while getting the suites green; they live in the
framework repos, not here:

- tina4-python: `FirebirdAdapter.execute` read `cursor.rowcount` unconditionally,
  and the modern firebird-driver raises `InterfaceError` on a DDL statement (no
  row count), so every `CREATE`/`DROP TABLE` blew up and the run appeared to hang.
  Guarded so DDL yields 0 affected.
- tina4-php: the concurrent `getNextId` test forked with `pcntl_fork` (deadlocks
  under grpc/openswoole); rewritten to spawn fresh processes with `proc_open`. And
  `MongoBackend.ensureIndexes` now tolerates a pre-existing index on the same keys
  under a different name.
- tina4-ruby: the session-engines spec's out-of-band mysql2 reader now rewrites
  `localhost` to `127.0.0.1` to force TCP.

## Known-good result (2026-09-04, run as root)

| Framework | Result |
| --- | --- |
| Python | 6028 passed, 0 failed |
| PHP | 0 failed, 0 errors |
| Ruby | 5733 passed, 0 failed |
| Node | 9070 passed, 0 failed, typecheck clean |
