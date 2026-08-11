# Feature 12: Firebird provider

## Identity and status

- Matrix identity: 12 - Firebird provider (`tina4_python/database/firebird.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, first-class LOGIC but with real surface gaps and one no-mock violation.
  Measured 2026-08-11. Python `database/firebird.py` (`ebbab30`); PHP `FirebirdAdapter.php` +
  `PdoFirebirdAdapter` (`6faabac5`); Ruby `lib/tina4/drivers/firebird_driver.rb` (`6d5b1de`); Node
  `packages/orm/src/adapters/firebird.ts` (`27cf0f4`).
- Dependencies: the driver - `firebird.driver`/`fdb` (Python); `ext-interbase` + PDO `pdo_firebird` (PHP);
  `fb` gem (Ruby); `node-firebird` (Node) - OPTIONAL + lazy.
- Dependants: apps on Firebird 2.5-5; the ORM.
- Existing ADRs: none dedicated; issue #132 (PHP ORM vs real FB5), #160 (charset), the column-case + IBASE_WAIT
  memories.

- Catalog phase: database

## Why this feature exists

Firebird is the legacy/embedded engine Tina4 supports for existing installs. It is the hardest adapter: no
`RETURNING` (generators instead), asymmetric identifier case-folding, a C client (fbclient) that no socket
timeout reaches, and blob handles that must be read out. The provider absorbs all of that.

## Existing implementation evidence

First-class LOGIC in all four (connect, execute/fetch, transactions, get_columns with real PK introspection,
column-case handling), with these known behaviours HANDLED across the languages:

- Column-name case (the classic Firebird trap): unquoted `AS x` folds to `"X"`; the adapter folds ALL-CAPS
  back to lowercase for portability (Python `firebird.py:384`, PHP `:376`, Ruby `firebird_driver.rb:416`,
  Node `firebird.ts:185`). All four preserve a quoted mixed-case name.
- Watchdog connect (fbclient is a ctypes/native call no socket timeout reaches - Python `call_with_deadline`,
  PHP, Node's outer bound; Ruby admits the attach is un-boundable and only bounds reachability).
- Last-id via a generator (`GEN_{TABLE}_ID`) + `WHERE id = ?` (Python `firebird.py:301`, PHP) - or NOT
  provided (Ruby returns nil `:252`, Node returns null `:622`).
- Blob read-out (memoryview/handle -> bytes) - verified in Python; ASSERTED-not-verified in Node
  (`decodeBlobs` no-op claiming node-firebird returns Buffers).
- IBASE_WAIT lock policy for the long-lived read transaction (PHP `FirebirdAdapter.php:1034`).
- PHP has a silent PDO `pdo_firebird` fallback and a broken-native retry; NB `ext-interbase` has no PHP 8
  build, so on PHP 8 the native path is unreachable and pdo_firebird runs.

## Public surface contract

`Database("firebird://...")` -> execute/fetch/transactions/introspection. Last-id is generator-derived (Python/
PHP) or absent (Ruby/Node - see the register). Fail-loud on the main query.

## Inputs and outputs

- Input: a `firebird://` URL (+ `?charset=`), SQL + params. Output: rows (column-case-folded), a generator-
  based last-id or none, or a raised error.

## Lifecycle and operation graph

1. Lazy-import the driver (guarded); connect (charset resolution URL/env/UTF8; watchdog).
2. Translate SQL (Firebird `ROWS x TO y` / `SELECT FIRST/SKIP`), bind, execute; transparent reconnect on a
   dead connection (Python/PHP/Ruby).
3. Fold ALL-CAPS column names to lowercase; read blobs to bytes; derive last-id from the generator (or not).

## Configuration and precedence

- The `firebird://` URL + `?charset=` (or `TINA4_...` charset env). PHP: `TINA4_FIREBIRD_DRIVER` / `?driver=`
  forces native vs PDO.

## Failures, side effects and security

- Fail-loud main query; transparent reconnect on dead-connection markers. IBASE_WAIT blocks on a lock
  conflict rather than erroring (deliberate, PHP). Credentials from the URL, redacted. The known
  node-firebird SRP-login flakiness is NOT mitigated in-adapter (Node).

## Wire and persistence contract

Firebird wire via the driver. Column names are lowercased (one-way - see the register). Last-id contract is
generator-based where present.

## Providers and substitutability

PHP has native + PDO legs (native unreachable on PHP 8); the others use one driver. Firebird tests are
EXCLUDED from the require-services CI gate (lab-only enforcement).

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| FB-RUBY-MOCK | Ruby's `spec/firebird_reconnect_spec.rb:66-118` uses RSpec doubles + `allow(driver).to receive(:open_connection)` to avoid a real Firebird server - the reconnect/retry path (4 of 9 examples) is proven only against fakes. This VIOLATES the project's absolute no-mock rule; the reconnect behaviour is not actually verified. | Convert to a real Firebird reconnect test (kill/restore a real connection), or drop the mocked examples. This is a direct no-mock-rule violation and should be fixed regardless of the audit. |
| FB-LASTID-GAP | Ruby (`firebird_driver.rb:252`) and Node (`firebird.ts:622`) NEVER return a last-insert-id (nil/null), while Python/PHP derive it from the generator. So on Firebird, Ruby/Node writes cannot report the new id - a parity gap in the write contract. | Derive the last-id from the generator in Ruby/Node (as Python/PHP do), or document Firebird as not supporting last-id in those languages. |
| FB-AFFECTED-FAB | Node FABRICATES `affectedRows: 1` on every insert/update/delete (`firebird.ts:447`/`:473`/`:505`) regardless of rows touched; Ruby lacks `affected_rows` entirely (facade returns a best-effort default). So a Firebird write's affected-count is not real in Ruby/Node. | Return the real affected count from the driver (or document it as unavailable). |
| FB-COLUMN-CASE-TRAP | The ALL-CAPS->lowercase fold is one-way: a genuinely quoted ALL-CAPS `AS "MYCOL"` is indistinguishable from a folded one and gets lowercased too (documented in Ruby `:411`). The one spelling that cannot round-trip. | Document the limitation prominently (it is inherent to Firebird's case-folding); no clean fix without tracking quoting through the query. |
| FB-BLOB-SRP-UNVERIFIED | Node's blob-as-Buffer claim is a no-op ASSERTED not verified (`firebird.ts:387`), and node-firebird's SRP-login negotiation is left entirely to the driver (unmitigated flakiness, ~12% failure measured). Neither is proven in a read-only pass. | Verify blob handling against a live Firebird; add SRP-login retry/handling in-adapter (or pin a driver version) given the measured flakiness. |
| FB-GATE-EXCLUDED | Firebird real-DB tests are EXCLUDED from the require-services gate (Python conftest; Node `_serviceGate.ts:65` lists firebird in EXCLUDED_KEYWORDS), and the Node driver is declared only as a devDependency. So real-Firebird coverage is enforced only where the URL happens to be set (lab), not by CI - contradicting the CLAUDE.md "Firebird is not excluded" claim (true only for the lab run). | Provision Firebird in CI (or keep the lab-only policy but fix the CLAUDE.md claim - it currently over-states coverage). Declare the Node driver as an optional dependency, not devDependency. |

## Owner decisions

- FB-DEC-01 (proposed): fix the no-mock violation (FB-RUBY-MOCK) - non-negotiable per the project rule.
- FB-DEC-02 (proposed): close the write-contract gaps in Ruby/Node - generator last-id (FB-LASTID-GAP) and
  real affected-count (FB-AFFECTED-FAB).
- FB-DEC-03 (proposed): verify blob + add SRP-login handling (FB-BLOB-SRP-UNVERIFIED); fix the CI-gate/
  CLAUDE.md coverage claim (FB-GATE-EXCLUDED); document the case-fold trap (FB-COLUMN-CASE-TRAP).

## Proposed conformance fixture

Real Firebird 5, no mocks (the existing column-case/charset/url specs are the base): a real reconnect after a
dropped connection (replacing the mocked Ruby spec); an insert reports the generator last-id in ALL four; a
multi-row write reports the real affected count; a blob round-trips intact; a column-case round-trip. Gate it
so CI provisions Firebird (or document the lab-only policy accurately).

## Integration map

- Consumers: ORM, migrations, the Database facade, the SQL translator (feature 7). Related: the Firebird
  statement-leak parity check and the SRP-login flakiness (open items).

## Breaking changes and migration

- Adding the generator last-id and real affected-count in Ruby/Node changes those `DatabaseResult` fields
  (previously nil/fabricated) - a correctness fix; document it.

## Implementation backlog

1. FB-DEC-01: real reconnect test (fix the no-mock violation).
2. FB-DEC-02: generator last-id + real affected-count in Ruby/Node, with regressions.
3. FB-DEC-03: verify blob; SRP-login handling; fix the CI-gate/CLAUDE.md claim; document the case trap.

## Porting capsule

A Firebird adapter needs: a lazy/optional driver; a watchdog around the un-boundable native connect;
charset resolution; ALL-CAPS->lowercase column folding (documenting the one-way trap); blob read-out to
bytes (VERIFIED against a live server); a generator-based last-id AND a real affected-count in EVERY
language; transparent reconnect proven against a REAL dropped connection (never a mock); and, given the
measured node-firebird SRP flakiness, in-adapter login handling. Provision Firebird in CI or state plainly
that coverage is lab-only.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure and security rules complete.
- [x] Wire/type contracts complete (column-case, generator last-id, blobs).
- [x] Four-language behaviour recorded (column-case universal; last-id/affected gaps Ruby/Node; PHP legs).
- [x] Owner ambiguities decided (FB-DEC-01..03).
- [x] Conformance fixture (real reconnect, last-id, affected, blob) recorded.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
