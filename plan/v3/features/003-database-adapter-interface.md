# Feature 3: Database adapter interface

Audited 2026-07-28. Part of `98-feature-audit.md`. **Planning only.**

**Status: CLOSED.** All four read from source; the interface declarations compared
method by method.

Scope note: the URL parsing that lives in these same files is feature 5 and is not
re-litigated here. This row is the **contract an adapter must satisfy** and the
facade that calls it.

## Files

| | interface | facade |
| --- | --- | --- |
| python | `database/adapter.py` (`DatabaseAdapter`) | `database/connection.py` (`Database`) |
| php | `Database/DatabaseAdapter.php` | `Database/Database.php` |
| ruby | **none** | `lib/tina4/database.rb` |
| node | `orm/src/types.ts` (`DatabaseAdapter`) | `orm/src/database.ts` |

## Measurements

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| python | 1573 | 121 | 353 | 2.92 | `_connection_path` (14) | **7.9** | 2 error, 9 warn |
| php | 872 | 75 | 221 | 2.95 | `createAdapter` (22) | **6.4** | 2 error, 4 warn |
| ruby | 828 | 70 | 263 | 3.76 | `get_next_id` (20) | **5.5** | 1 error, 5 warn |
| node | 897 | 71 | 254 | 3.58 | `parseDatabaseUrl` (43) | **4.5** | 2 error, 3 warn |

**The maintainability index is the story.** 4.5 to 7.9 against the scanner's floor
of 40 - the worst of any feature measured, in the subsystem every other feature
depends on. Python is 1.9x Ruby's size with 121 functions to 70, and still scores
the least-bad MI, which tells you the problem is not simply length.

## The interface, method by method

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| open a connection | `connect` | `open` | duck-typed | constructor |
| close | `close` | `close` | duck-typed | `close` |
| execute | `execute` | `execute` | duck-typed | `execute` |
| batch execute | `execute_many` | `executeMany` | duck-typed | `executeMany` |
| read many | `fetch` | `fetch` | duck-typed | `fetch` |
| read one | `fetch_one` | `fetchOne` | duck-typed | `fetchOne` |
| raw query | (absent) | `query` | duck-typed | `query` |
| insert / update / delete | all three | all three | duck-typed | all three |
| transaction | `start_transaction`, `commit`, `rollback` | same | duck-typed | same |
| list tables | `get_tables` | `getTables` | duck-typed | **`tables`** |
| list columns | `get_columns` | `getColumns` | duck-typed | **`columns`** |
| table exists | `table_exists` | `tableExists` | duck-typed | `tableExists` |
| last insert id | (absent) | `lastInsertId` | duck-typed | `lastInsertId` |
| last error | (absent) | `error` | duck-typed | (absent) |
| create table | (absent) | (absent) | duck-typed | `createTable` |
| add column | (absent) | (absent) | duck-typed | `addColumn?` (optional) |
| autocommit | `autocommit` | (absent) | duck-typed | (absent) |
| **SQL dialect translation** | **8 methods on the adapter** | separate trait | separate class | separate class |

## What differs

**D1. Ruby has no adapter interface at all.** `Database` calls exactly four things
on a driver - `connect`, `close`, `autocommit`, `respond_to?` - and guards the rest
behind six `respond_to?` checks. There is no abstract base, no
`NotImplementedError`, no declared method list. Consequences:

- A driver missing a method is discovered at runtime, on whichever engine nobody
  exercised. The `respond_to?` guards mean the failure is often a silent skip
  rather than an exception, which is worse.
- Nothing tells a contributor writing a fifth driver what to implement. The answer
  is "read `database.rb` and infer", and it is 828 lines.
- The audit itself could not compare Ruby's contract to the other three, because
  Ruby does not have one to compare. That is the finding.

**D2. Python's adapter base carries two responsibilities.** Alongside the
connection and CRUD contract it declares eight SQL-dialect translation methods:
`limit_to_rows`, `limit_to_top`, `concat_pipes_to_func`, `boolean_to_int`,
`ilike_to_like`, `placeholder_style`, `auto_increment_syntax`, `quote_identifier`.

The other three keep dialect translation in its own unit - PHP's
`SqlNormalizerTrait`, Ruby's `sql_translator.rb`, Node's `sqlTranslator.ts`. So
Python is the only framework where "how do I talk to this engine" and "how do I
rewrite SQL for this dialect" are the same abstraction. That is a textbook single-
responsibility violation, it is a large part of the 1573-versus-828 LOC gap, and it
means a new Python adapter must implement eight translation methods it may not
need.

**D3. Node names two introspection methods differently.** `tables()` and
`columns()` against `get_tables`/`getTables` and `get_columns`/`getColumns`
everywhere else. Straight naming-rule violation, on the interface that third-party
adapters implement.

**D4. Four different method sets.** Beyond the naming: `query` exists in PHP and
Node but not Python; `error` only in PHP; `lastInsertId` in PHP and Node but not
Python's adapter (Python puts `get_last_id` on the facade instead); `createTable`
only in Node; `autocommit` in Python and Ruby only. So "implement the Tina4
adapter interface" means four different jobs.

**D5. Node's interface has optional members.** `getTableColumns?` and `addColumn?`
are declared optional, which means the facade must feature-detect at every call
site - the same `respond_to?` pattern that makes Ruby's absence of an interface
hard to reason about, just written in TypeScript. An optional method on a contract
is not a contract.

**D6. The facade's worst functions are all doing adapter selection.** PHP's
`createAdapter` (CC 22), Python's `_connection_path` (14), Ruby's `get_next_id`
(20). Three of four have their worst function in the same job: deciding which
driver to use and how to reach it. Feature 5 already moves URL parsing out to a
value type, which takes a large bite out of this; what remains is a registry
lookup that should be data, not branches.

## D2 CORRECTED (2026-07-30): Python's separation already exists

D2 says Python's adapter base "declares eight SQL-dialect translation methods"
beside the connection and CRUD contract, making it "the only framework where
'how do I talk to this engine' and 'how do I rewrite SQL for this dialect' are
the same abstraction". Checked against the code before moving anything, per the
methodology's own instruction to look for per-adapter overrides first:

```
DatabaseAdapter: 26 methods; dialect ones = ['quote_identifier']
SQLTranslator:    7 methods; dialect ones = ['limit_to_rows', 'limit_to_top',
                  'concat_pipes_to_func', 'boolean_to_int', 'ilike_to_like',
                  'auto_increment_syntax', 'placeholder_style']
```

**Seven of the eight are already on a separate `SQLTranslator` class.** The
separation D2 says Python lacks is there. What is true is narrower: that class
lives in the same FILE as `DatabaseAdapter` (`database/adapter.py`), where
PHP, Ruby and Node each give it its own file. That is file organisation, not an
SRP violation of the abstraction, and it is worth a line in a tidy-up rather
than being the reason Python "has the worst separation".

**The eighth, `quote_identifier`, belongs exactly where it is.** It has three
definitions - `adapter.py`, `firebird.py`, `connection.py` - so it is OVERRIDDEN
PER ADAPTER. Identifier quoting genuinely differs by engine, and Firebird
overrides it. Moving it to the translator would flatten that override, which is
precisely the risk the methodology told us to check for:

> D2 is a pure extraction and should be behaviour-neutral. If it is not, the
> translation methods had per-adapter overrides that the extraction would
> flatten - check for overrides in every Python adapter before moving anything.

The check says: do not move it.

**So the prescribed fix for D2 is wrong in both directions** - seven methods are
already where the plan wants them, and the eighth must not go there. The only
action left on this row for Python is optionally giving `SQLTranslator` its own
file for parity with the other three.

This also weakens one input to the verdict below: "Python has the worst
separation (D2)" was a stated factor, and it does not hold. The verdict itself
still stands on PHP having the only readable one-responsibility interface and on
the conformance numbers, which were measured independently.

## Progress (2026-07-30)

**Done:**

- **The contract is DATA** (`adapter_contract.json`, byte-identical in all four)
  rather than four hand-maintained declarations - which is how the frameworks
  got four different answers in the first place.
- **A conformance RATCHET in all four.** Each pins today's implemented count per
  adapter, so it can go up but never down and a new adapter cannot ship at the
  old level. PHP 17/20 x10, Python 15/20 x6, Node 16-17/20 x7, Ruby 8-10/20 x7.
  PHP and Python also assert every adapter sits at the SAME level, which is the
  property a real interface buys.
- **Ruby has an interface.** `Tina4::DatabaseAdapter` declares all 20, each
  raising with the driver and method name; all seven drivers include it. The six
  `respond_to?` guards became `driver_implements?`, which asks whether the driver
  actually OVERRODE the method - because including the module makes every driver
  respond to everything, and answering that wrongly turns a working silent-skip
  path into a runtime NotImplementedError.
- **Python is finished.** D2's prescribed fix was wrong in both directions (see
  the correction above); the real action was giving `SQLTranslator` its own file,
  which is done. `quote_identifier` stays on the adapter, where its Firebird
  override lives.

**Remaining:**

- **Ruby: CRUD onto the seven drivers** (owner decision (a)), raising each
  driver's floor as it lands. The largest piece.
- **Node: rename `tables`/`columns`, make the two optional members required.**
  49 call sites across `devAdmin`, `mcp`, `cachedDatabase`, the adapters and the
  tests, so it is mechanical but wide.
- **PHP: `autocommit`, `createTable`, `addColumn`.** The ten adapters implement
  the interface directly with no shared base, so adding three to the interface is
  thirty implementations with engine-specific DDL. Worth considering a trait with
  a sensible `autocommit` default first, since that one is not engine-specific.

## OPEN: is this contract the right SHAPE, or just PHP's list?

Owner challenge, 2026-07-30: "Are we blindly copying PHP - did we check the
database adapter layout makes sense?"

Answering honestly: **partly yes, and the evidence is in this document.**

**1. The conformance number is partly circular.** `adapter_contract.json` is
substantially PHP's 18 methods plus `createTable`/`addColumn` from Node. So
"PHP scores 17/20, the highest" is close to a tautology - it scores highest
against a list derived from itself. What the measurement DOES show honestly is
CONSISTENCY (ten adapters identical, versus Ruby's three levels), and that
finding stands on its own. The ranking does not.

**2. Twenty methods on one interface is a lot, and interface segregation is the
principle this row was decided on.** The contract mixes five concerns:

| concern | methods |
| --- | --- |
| connection lifecycle | open, close, autocommit |
| CRUD | execute, executeMany, fetch, fetchOne, insert, update, delete |
| transactions | startTransaction, commit, rollback |
| introspection | getTables, getColumns, tableExists |
| DDL | createTable, addColumn |
| diagnostics | lastInsertId, error |

An adapter that only ever reads has to implement writes and DDL. That is the
same complaint the row makes about Node's optional members, one level up: the
answer to "an optional method is not a contract" might be SEVERAL contracts
rather than one fat required one.

**3. PHP's interface had a hole only found by trying to use it.** No adapter
could name its own dialect, so DDL could not be built from the adapter at all -
`ORM::detectDialect()` type-checked the concrete class from outside. The
framework that won this row on SOLID grounds contained a textbook
depend-on-the-concrete-class defect, and reading it did not surface that.
Implementing it did.

**4. Ruby's split may be better, and we chose against it partly on the plan's
say-so.** Ruby's facade builds the SQL and the driver executes it, which means
ONE SQL builder rather than seven. The owner chose (a) - CRUD onto the adapter -
but the DRY argument for Ruby's shape was never actually weighed, because the
audit recorded Ruby's lack of an interface as the finding and moved on.

**5. Two more decisions were taken from the plan without independent test.**
`query` was dropped because "nothing needs a second read path", and dialect
translation was placed off the adapter - and the D2 correction above shows the
reasoning behind that placement was itself wrong about the code.

### What this does NOT undermine

The work landed so far is defensible independent of the shape question, because
it is all about CONSISTENCY rather than about which list is right: Ruby having
any declared contract at all, the silent-skip guards becoming loud, the ratchets,
the naming convergence, autocommit existing in more than one framework, and an
adapter being able to name its own dialect. Every one of those is right whether
the final interface is one list of twenty or five smaller ones.

### What it should gate

`createTable` and `addColumn` are the two methods that most obviously belong to
a SEPARATE schema concern, and they are the two still unimplemented. Adding them
to a twenty-method required interface, across ten PHP adapters and five Node
ones, is the most expensive way to be wrong. **They should wait for a decision on
the shape**, not be pushed through because they are next on a list.

## VERDICT: REDESIGN (owner, 2026-07-30)

There is a fifth option the audit's verdict vocabulary does not contain, and it
is the right one here.

UNIFORM / PROMOTE x / SYNTHESISE / GAP / DEFER all pick from what already
exists. None of them can express "all four are wrong in the same direction",
which is why this row kept producing answers that had to be corrected: first
PROMOTE php (PHP's list is partly circular), then SYNTHESISE php+ruby (still
assembling from two existing shapes). **Add REDESIGN to the vocabulary** - a
verdict for when the audit has learned enough to design better than any of the
four, and use it here.

### What the learning actually is

Nine things came out of implementing this row, and together they describe a
different adapter than any framework has:

1. **DDL was NEVER an adapter concern.** PHP builds CREATE TABLE in
   `ORM.php:1697`, Node in `migration.ts`, Python in `model.py:906`. We were
   about to add `createTable`/`addColumn` to fifteen adapters for a job all four
   frameworks already do ABOVE the adapter. The "gap" was an artefact of the
   contract being written from Node's interface declaration rather than from
   where the work happens.
2. **CRUD is not engine-specific and costs 4.3x to duplicate.** Measured: Ruby
   1335 LOC / 142 functions against PHP's 5823 / 438, for the same job.
3. **The adapter could not name its own engine**, so callers type-checked the
   concrete class. Fixed today, but it shows the contract was never derived from
   what callers need.
4. **Optional members are feature-detection in disguise** - Node's `?`, Ruby's
   `respond_to?` - and both make a missing method a SILENT SKIP.
5. **Two shapes for one concept survive because one is load-bearing.**
   Collapsing `getTableColumns` into `getColumns` broke the legacy migration
   path: one reads PRAGMA raw, the other goes through schema splitting. That is
   not duplication to delete, it is two genuinely different questions wearing
   similar names.
6. **Dialect translation already lives outside the adapter in all four.** The
   one framework thought to be mixing them was not (D2 correction).
7. **The write path already has semantics the contract cannot express**: a write
   with no filter is an ERROR, not a full-table operation (feature 4), and
   `execute()` RAISES rather than returning false.
8. **Naming drifted precisely where nothing forced agreement** - tables/columns,
   open/connect, error/last_error.
9. **Consistency, not completeness, is what a contract buys.** PHP's ten
   adapters being identical mattered more than any of them being complete.

### The adapter that follows

An adapter should be ONLY what genuinely differs per engine. Everything
engine-agnostic - SQL building, DDL, pagination, translation, filters - lives
above it, once.

| contract | methods | why it is engine-specific |
| --- | --- | --- |
| **Connection** | `open`, `close`, `getDatabaseType` | driver handshake, and the engine must be able to name itself |
| **Execution** | `execute(sql, params)`, `fetch(sql, params, limit, offset)` | placeholder style, cursor handling, result shape |
| **Transaction** | `startTransaction`, `commit`, `rollback`, `autocommit` | genuinely per-driver |
| **Introspection** | `getTables`, `getColumns`, `tableExists` | system catalogs differ entirely |
| **Diagnostics** | `lastInsertId`, `error` | driver-specific retrieval |

**Fourteen methods, five contracts, and NOT on the list:** `insert`, `update`,
`delete`, `executeMany`, `fetchOne`, `createTable`, `addColumn`, `query`. Every
one is composable above the adapter from `execute` + `fetch` + the dialect name,
and every one is currently duplicated per adapter in three of four frameworks.

That is 20 required methods down to 14, and it deletes far more than it adds.

### What this means for work already done

All of it stands - it was consistency work, and consistency is right under any
shape: Ruby's declared contract, the loud-on-absence guards, the ratchets, the
naming convergence, `autocommit`, `getDatabaseType`. What changes is the
DIRECTION of the remaining work: **delete `insert`/`update`/`delete` from the
PHP, Python and Node adapters** rather than adding them to Ruby's seven drivers,
and **do not implement `createTable`/`addColumn` on any adapter at all**.

### Measured on DRY, SOLID, LOC, CC (2026-07-30)

The adapter layer in each framework, native engine, same scan shape:

| | files | functions | LOC | avg CC | MI |
| --- | --- | --- | --- | --- | --- |
| python | 12 | 287 | 3971 | 3.58 | 24.5 |
| php | 18 | **438** | **5823** | 3.14 | 26.1 |
| **ruby** | **8** | **142** | **1335** | 2.89 | **30.7** |
| node | 15 | 378 | 2677 | 2.29 | 28.6 |

**Ruby does the same job in 1335 lines and 142 functions that PHP does in 5823
and 438.** Four and a third times the code, three times the functions, for seven
drivers versus ten adapters - so it is not a driver-count effect. Ruby also has
the best maintainability index of the four (30.7 against PHP's 26.1) and the
second-best average complexity behind Node, on half Node's function count.

On the four axes this audit judges by:

- **LOC**: Ruby, decisively. "Maintainability means less code" is the north star
  and the tiebreak, and this is a 4.3x gap.
- **DRY**: Ruby, structurally. One SQL builder in the facade versus one per
  adapter. The 4.3x is largely that duplication made visible.
- **CC**: Node on average (2.29), Ruby second (2.89) - but Ruby reaches it with
  142 functions where Node needs 378, so Ruby carries less total complexity.
- **SOLID**: PHP had the only DECLARED interface, which is what won it the row.
  That is a real win and it is about having a contract, not about what is IN the
  contract - and the contract it holds mixes six concerns and could not name its
  own dialect.

**The verdict inverts once the numbers are in.** PHP won on having an interface;
Ruby wins on every axis that measures the code behind it. Promoting PHP's LIST
would move the family toward 438 functions per adapter layer and away from 142.
The right synthesis is PHP's DISCIPLINE (a declared, segregated contract, no
optional members, loud on absence) applied to RUBY's SHAPE (CRUD in the facade,
adapters thin).

### The answer, derived rather than asked

Applying the principles already on record instead of putting another fork to the
owner:

- **"Maintainability means less code"** is the stated north star, and the
  tiebreak.
- **Interface segregation** is the axis this row was explicitly decided on.
- **ADR-0004: the best implementation prevails**, and parity flows both ways.

Run those over the evidence and the answer is not "PHP's list, completed":

**1. CRUD belongs in the FACADE, not on the adapter. Ruby was right.**
Building `INSERT INTO x (a, b) VALUES (?, ?)` is not engine-specific work. Ruby
does it once in the facade and hands the driver a statement; the other three do
it in every adapter. Adopting PHP's split means writing that builder SEVEN more
times in Ruby; adopting Ruby's means DELETING it from PHP, Python and Node.
One of those directions is less code by a wide margin, and the north star names
which. Only the parts that genuinely differ per engine stay per-adapter -
Postgres' `RETURNING *`, which Ruby already models as an opt-in seam.

**2. The contract splits by concern.** Twenty required methods on one interface
fails the principle the row was judged on. The split follows the concerns
already visible in the table above:

| contract | methods | who implements |
| --- | --- | --- |
| **Connection** | open, close, autocommit, getDatabaseType | every adapter |
| **Execution** | execute, executeMany, fetch, fetchOne | every adapter |
| **Transaction** | startTransaction, commit, rollback | every adapter |
| **Introspection** | getTables, getColumns, tableExists | every adapter |
| **Schema** | createTable, addColumn | every adapter |
| **Diagnostics** | lastInsertId, error | every adapter |

CRUD (insert/update/delete) leaves the adapter contract entirely. That is 20
required methods down to 16, and seven fewer SQL builders in the family.

**3. `getDatabaseType` joins the contract.** It is a Connection concern and the
prerequisite for Schema; leaving it off is what made `createTable` impossible to
put on the adapter in the first place.

**This REVERSES decision (a).** (a) was the wrong question to have asked - it
offered "adopt the reference's shape" versus "keep Ruby's" without weighing that
Ruby's shape is the one that produces less code across all four. The DRY
argument for it was never put, which is the defect in how the choice was framed,
not in the choice the owner made from it.

**Sequencing that follows:** split the contract first (declaration only, no
behaviour change), then implement Schema on the fifteen adapters, then delete
per-adapter CRUD from PHP, Python and Node rather than adding it to Ruby's
seven drivers.

## Verdict: PROMOTE php on the interface, then complete it from node

Decided on **SOLID (single responsibility and interface segregation)**.

PHP has the best contract: a declared 18-method interface holding exactly one
responsibility, with dialect translation kept in a separate trait. It is also the
only one whose interface a contributor can read in one screen.

Node has the most *complete* contract (it declares `createTable`, which the others
leave implicit) and the cleanest facade separation, but it weakens the contract
with optional members and mis-names two methods.

Python has the worst separation (D2) and Ruby has no contract at all (D1), so both
gain the most.

So: PHP's shape, Node's completeness, no optional members, and Python's dialect
helpers move to the translator that already exists in all four.

## Pattern

**One declared interface, one responsibility, no optional members, in all four.**

The adapter contract - every method required, no exceptions:

```
  open()                          connect and become usable
  close()                         release the connection
  execute(sql, params)            write; raises on error
  executeMany(sql, paramsList)    batch write in one transaction
  fetch(sql, params, limit, offset)   read many -> DatabaseResult
  fetchOne(sql, params)           read one -> row or null
  insert(table, data)             -> write result
  update(table, data, filter, params)  -> write result
  delete(table, filter, params)   -> write result
  startTransaction() / commit() / rollback()
  getTables()                     -> list of table names
  getColumns(table)               -> list of column descriptors
  tableExists(name)               -> bool
  createTable(name, columns)      -> bool
  addColumn(table, name, definition)  -> bool
  lastInsertId()                  -> id or null
  error()                         -> last error message or null
  autocommit(on)                  set per-statement commit
```

Four decisions in that list:

1. **`getTables` / `getColumns`**, not `tables` / `columns`. Node renames; the
   majority and the `get`-prefix convention already used for `getColumns`
   everywhere else win.
2. **`addColumn` and `createTable` are required, not optional.** Every engine can
   do both; an adapter that cannot is not finished. This removes the
   feature-detection branches from the facade.
3. **`error()` and `lastInsertId()` are required in all four.** Python's facade
   already needs both; it currently reaches around the interface to get them.
4. **`autocommit` is required in all four.** PHP and Node gain it, which matters
   because the autocommit contract (autocommit on for standalone writes, suppressed
   inside an explicit transaction) is already agreed behaviour and is currently
   enforced in only half the family.

**SQL dialect translation is NOT on the adapter.** It lives in the `SQLTranslator`
unit that PHP, Ruby and Node already have; Python's eight methods move there. An
adapter declares its dialect name and the translator does the rewriting.

Surface table for the facade, which is what application code touches:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| interface name | `DatabaseAdapter` | `DatabaseAdapter` | `DatabaseAdapter` (new) | `DatabaseAdapter` |
| declare a driver | `register_driver(scheme, cls)` | `registerDriver($scheme, $class)` | `register_driver(scheme, klass)` | `registerDriver(scheme, cls)` |
| dialect helpers | `SQLTranslator.*` | `SQLTranslator::*` | `SQLTranslator.*` | `SQLTranslator.*` |

Ruby's new interface is a module with every method raising
`NotImplementedError`, and each of the six existing drivers includes it. That turns
"read 828 lines and infer" into "implement this module", and it turns a missing
method from a silent runtime skip into a loud failure at the point of the call.

## Conformance baseline (2026-07-30)

Step 2 done, before any interface is touched. `adapter_contract.json` is the
20-method contract as DATA, byte-identical in all four (md5 `a2bcf0d4`) - rather
than four hand-maintained interface declarations, which is exactly how the
frameworks ended up with four different answers to "implement the Tina4 adapter
interface". Every adapter in every framework reflected against it:

| framework | adapters | conformance | consistent with each other? |
| --- | --- | --- | --- |
| **php** | 10 | **17/20** | yes - all ten identical |
| python | 6 | 14/20 | yes - all six identical |
| node | 7 | 14-15/20 | nearly - odbc and sqlite have one more |
| **ruby** | 7 | **9-11/20** | **no** |

**PHP is confirmed as the reference by measurement, not just by reading.** Ten
adapters, all missing exactly the same three (`createTable`, `addColumn`,
`autocommit`). A contract that every implementation satisfies identically is a
contract; that is what having one produces.

**Ruby is not merely lower, it is INCONSISTENT WITH ITSELF.** Firebird and
Mongodb 9/20, Sqlite/Mysql/Mssql 10/20, Postgres 11/20. Seven drivers, three
different levels of completeness. That is the D1 finding as a number: with no
interface, each driver implements whatever its facade path happened to need, and
the six `respond_to?` guards in `database.rb` paper over the rest. Nothing tells
a contributor writing an eighth driver what to implement, and nothing tells a
user which of the seven will silently skip.

**CORRECTION (same day).** The first run of this probe reported 5-7/20 because it
looked only for the contract's canonical names. Ruby spells several of them
idiomatically - `connect` for `open`, `query` for `fetch`, `tables`/`columns`,
`last_error` for `error`, `autocommit=`, `table_exists?` - and re-running with
those variants gives 9-11/20. The corrected number is the one above. The shape of
the finding is unchanged (lowest, and inconsistent with itself); the magnitude was
overstated.

**The corrected run surfaces something the raw count hid, and it changes the
work.** Every Ruby driver is missing `fetch`, `fetch_one`, `insert`, `update` and
`delete` - not because they were forgotten, but because **the FACADE does that
work**. `Database#insert` builds the SQL and calls the driver's `execute`, and
only consults `drv.insert` when a driver chooses to own it (PostgreSQL does, via
`RETURNING *`). So Ruby splits responsibility between facade and driver
differently from the other three, and the `respond_to?(:insert)` guard is not
papering over a missing method - it is a deliberate opt-in seam.

That means Ruby's step is NOT "add eleven missing methods to seven drivers". It
is a genuine architectural decision that has to be made first, and the plan did
not anticipate it:

- **(a)** adopt the other three's split - CRUD lives on the adapter - which is a
  large move touching all seven drivers, or
- **(b)** keep the facade-builds-SQL split and make the contract state that CRUD
  is facade-level in Ruby with the driver seam optional, which means the contract
  is no longer one list for all four.

**(a) is what the row's verdict implies** and (b) is what the code does today.
This needs the owner before any Ruby driver is touched, because it decides
whether the shared contract is genuinely shared.

Common gaps worth naming:

- **`autocommit` is missing from THREE frameworks** (php, node, ruby). The
  autocommit contract - on for standalone writes, suppressed inside an explicit
  transaction - is already agreed behaviour and is enforced in one framework.
- **`createTable` / `addColumn` are missing almost everywhere**, which is what
  makes them "optional" in Node's declaration. Every engine can do both.
- **`error()` is missing from python, node and ruby.** Only PHP lets a caller ask
  the adapter what went wrong.
- **`open` is missing from python, node and ruby** because they spell it
  `connect` or do it in the constructor. A naming divergence on the first method
  anyone implements.

This list IS the parity gap the methodology asks to capture. Nothing has moved
yet.

## Methodology

Order matters more here than in any other row, because everything else depends on
this layer.

1. **Land feature 5 first.** It moves URL parsing into a value type, which removes
   the largest single contributor to `createAdapter` (CC 22) and
   `parseDatabaseUrl` (CC 43) before this row touches them. Doing 3 before 5 means
   doing the same surgery twice.
2. **Write the conformance suite before changing any interface** - one shared set
   of contract tests that every adapter in every framework must pass (below). Run
   it against all six engines in all four frameworks and record the baseline. Some
   adapters will fail today; that list IS the parity gap and must be captured
   before anything moves.
3. **Ruby first**: add the `DatabaseAdapter` module with every method raising, make
   all six drivers include it, then delete the `respond_to?` guards one at a time.
   Each deleted guard either passes (the method exists) or surfaces a real gap.
4. **Python second**: move the eight dialect methods to `SQLTranslator`. Pure
   extraction, no behaviour change, and it should visibly move the LOC and MI
   numbers. Then add `lastInsertId`, `error`, `query` to the interface.
5. **Node third**: rename `tables`/`columns`, make the two optional members
   required, implement them where missing.
6. **PHP last**: add `autocommit` and `createTable`/`addColumn`. Smallest change,
   because PHP's interface is the model.
7. Re-measure. The MI floor of 40 is not reachable in one pass on a 1573-line
   file; the target for this row is **no regression and a measurable improvement in
   Python** (from the D2 extraction). Getting all four to 40 is a separate,
   larger plan and should be filed as such rather than pretended at here.

## Tests to write

A **conformance suite**, not per-framework unit tests: one contract, run against
every adapter. This is the pattern that already worked for the migration bookkeeping
table and the Frond corpus.

Real engines only. SQLite always; PostgreSQL, MySQL, MSSQL, Mongo from the live
infra; Firebird from the server in task #312. No mocks - an adapter test that does
not touch its engine tests nothing.

| pair | positive | negative |
| --- | --- | --- |
| contract completeness | `every_adapter_implements_every_interface_method` - reflect over the interface and the class | `no_interface_method_is_optional` - kills Node's `?` members and Ruby's duck-typing |
| loud absence | `an_incomplete_adapter_raises_not_implemented` | `an_incomplete_adapter_is_never_silently_skipped` - the Ruby `respond_to?` reproduction |
| naming | `introspection_is_named_get_tables_and_get_columns` | `no_framework_exposes_tables_or_columns_unprefixed` |
| separation | `the_adapter_declares_no_sql_translation_method` | `sql_translation_is_reachable_only_through_the_translator` - the Python D2 reproduction |
| read contract | `fetch_returns_a_result_with_records_and_count`, `fetch_one_returns_null_when_no_row_matches` | `fetch_raises_on_bad_sql_and_records_the_cause` |
| write contract | `insert_reports_a_last_insert_id`, `execute_many_is_atomic` | `execute_never_returns_false_on_error` |
| introspection | `get_tables_lists_a_created_table`, `get_columns_describes_every_column` | `table_exists_is_false_for_a_missing_table` |
| schema | `create_table_then_add_column_both_report_success` | `create_table_on_an_existing_table_does_not_raise_already_exists` |
| transaction | `a_rolled_back_write_is_not_visible` | `a_committed_write_is_never_lost` |
| autocommit | `a_standalone_write_is_durable_without_an_explicit_commit` | `a_write_inside_a_transaction_is_not_committed_early` |
| engine parity | `every_engine_returns_the_same_shape_for_the_same_query` | `no_engine_returns_a_field_the_others_lack` |

The contract-completeness pair is the one that makes this stick: it reflects over
the declared interface and asserts the class implements it, so a future adapter
cannot ship half-finished and a future interface addition cannot be quietly
skipped by three of six drivers.

## Risks

- **This is the highest-risk row in the audit.** Every feature reaches the
  database through this layer, so a mistake here surfaces everywhere at once. That
  is the argument for the conformance suite landing before any interface edit.
- **Ruby's `respond_to?` removal will surface real gaps.** Expect drivers missing
  methods the facade quietly worked around. Each one is a genuine bug that has been
  invisible; do not fix it inside the interface change, file it and fix it with its
  own test.
- **D2 is a pure extraction and should be behaviour-neutral.** If it is not, the
  translation methods had per-adapter overrides that the extraction would flatten -
  check for overrides in every Python adapter before moving anything.
- **Making optional members required is breaking for any third-party adapter.**
  Unlikely to exist outside the repo, but it is a public interface, so it needs a
  `Breaking:` entry.

## Parked

Not implemented. Sequenced **after feature 5** (which removes the URL parsing this
row would otherwise refactor twice) and after feature 4 (the write-path P1, which
touches the same facade methods). Recommend: 6, 4, 5, then 3.
