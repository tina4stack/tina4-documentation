# Feature 5: DATABASE_URL parser

Audited 2026-07-28. Part of `98-feature-audit.md`. **Planning only.**

Core Principle 6 names connection strings as something that must be *literally
identical* across the four frameworks. This is the feature that decides that, so
it gets a stricter reading than most.

## Files

| | path | shape |
| --- | --- | --- |
| python | `tina4_python/database/connection.py` | **inline** in `Database.__init__` / `_select_adapter` |
| php | `Tina4/DatabaseUrl.php` | a value object with readonly properties |
| ruby | `lib/tina4/database.rb` | **inline** in `Database#initialize` |
| node | `packages/orm/src/database.ts` | `parseDatabaseUrl()` returning `ParsedDatabaseUrl` |

## Measurements

Rolled into feature 3's numbers (the parser is not separable in two of four).
The one measurement that stands alone:

| | worst function | CC |
| --- | --- | --- |
| node | `parseDatabaseUrl` | **43** |

43 in a single pure function whose entire job is string-to-struct. For comparison,
the whole PHP `DatabaseUrl` class - constructor, `fromEnv`, `getDriverClass`,
`getDsn`, `toSafeString` - has no function above the warn threshold.

## What differs

Nine connection strings through both parsers that can run without opening a
connection. Verified by execution.

| url | PHP | Node |
| --- | --- | --- |
| `sqlite:///app.db` | db=`app.db` | path=`app.db` |
| `postgres://user:pass@localhost:5432/mydb` | port=5432 user=user | port=5432 user=user |
| `postgresql://localhost/mydb` | **port=5432** | **port=(unset)** |
| `pgsql://localhost:5432/mydb` | postgres | postgres |
| `mysql://root:secret@localhost:3306/db` | ok | ok |
| `mssql://sa:pw@localhost:1433/db` | ok | ok |
| `sqlserver://localhost:1433/db` | mssql | mssql |
| `firebird://localhost:3050//path/to/db` | db=**`path/to/db`** | db=**`//path/to/db`** |
| `postgres://u:p%40ss@localhost:5432/db` | pass=`p@ss` | pass=`p@ss` |

**D1. There is no parser to compare in Python or Ruby.** Both inline URL handling
into the `Database` constructor, so a URL cannot be parsed without building a
connection object. Consequences, in order of severity: the parse cannot be unit
tested on its own; the four cannot be compared without standing up a database;
and `tina4 doctor` / the setup wizard / any tooling that wants to validate a URL
before using it has nothing to call. Python compounds it by parsing twice in two
ways - `urlparse` in `_select_adapter`, then a deliberate raw-string strip for
sqlite because "urlparse collapses" the path (its own comment).

**D2. A URL with no port parses differently.** `postgresql://localhost/mydb`
yields port 5432 on PHP and no port at all on Node. The downstream `pg` driver
defaults to 5432 itself, so this probably does not break a connection today -
which is precisely why it is worth recording now: the parsed struct for one input
differs between frameworks, and the thing hiding it is a third-party default, not
our contract.

**D3. The documented Firebird absolute-path form parses three ways, and neither
result is the path.** `firebird://localhost:3050//path/to/db` is the form the
CLAUDE.md files document for an absolute Firebird database path. PHP returns
`path/to/db` (relative - both leading slashes gone). Node returns `//path/to/db`
(both kept). Neither returns `/path/to/db`. Whether either is correct depends on
what the driver does next, and that is exactly the problem: the audit cannot tell
from the parse alone, and neither can a user. This one needs a real Firebird
server to settle (task #312 already has one) before the pattern is fixed.

**D4. The parsed struct uses different field names for the same concepts.** The
owner's naming rule, applied to a data shape rather than a method:

| concept | php | node |
| --- | --- | --- |
| engine | `driver` (+ separate `scheme`) | `type` |
| user | `username` | `user` |
| sqlite file | `database` | `path` |
| server db name | `database` | `database` |

`driver` on PHP is not even the scheme - it holds an internal class name
(`DataPostgresql`, `DataSQLite3`, `DataMySQL`), a v2-era naming that leaks
implementation into a public readonly property.

**D5. Only PHP has the useful extras.** `DatabaseUrl::fromEnv()`,
`getDsn()`, and `toSafeString()` (a redacted form for logs). The last one matters:
without it, every other framework that wants to log a connection target has to
redact the password itself, and the audit of the logger will find out whether they
all do.

## Verdict: PROMOTE php (the shape), then fix it

Decided on **SOLID (single responsibility)**. A parsed connection URL is a value,
and PHP is the only framework that models it as one. Its class has no
above-threshold function, it is unit-testable without a database, and it carries
the two derived accessors the others lack.

Node has the right idea (a pure function returning a struct) with a 43-CC body.
Python and Ruby have no seam at all.

So: adopt PHP's shape everywhere, and while adopting it, fix PHP's own defects -
the leaked `DataXxx` class name in `driver`, and the Firebird path handling.

## Pattern

**A `DatabaseUrl` value type in all four, constructed from a string, with nothing
else in it.**

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| parse | `DatabaseUrl(url)` | `new DatabaseUrl($url)` | `DatabaseUrl.new(url)` | `new DatabaseUrl(url)` |
| from env | `DatabaseUrl.from_env(key=...)` | `DatabaseUrl::fromEnv($key)` | `DatabaseUrl.from_env(key:)` | `DatabaseUrl.fromEnv(key?)` |
| engine | `.engine` | `->engine` | `.engine` | `.engine` |
| host | `.host` | `->host` | `.host` | `.host` |
| port | `.port` | `->port` | `.port` | `.port` |
| database | `.database` | `->database` | `.database` | `.database` |
| username | `.username` | `->username` | `.username` | `.username` |
| password | `.password` | `->password` | `.password` | `.password` |
| dsn | `.dsn()` | `->getDsn()` | `.dsn` | `.dsn()` |
| redacted | `.to_safe_string()` | `->toSafeString()` | `.to_safe_string` | `.toSafeString()` |

Field decisions, each settling a divergence found above:

- **`engine`**, not `driver` and not `type`. It holds the canonical engine name
  (`sqlite`, `postgres`, `mysql`, `mssql`, `firebird`, `mongodb`, `odbc`) after
  alias resolution. The adapter class is looked up FROM the engine by the
  registry; a public property never holds a class name (kills D4's leak).
- **`username`**, not `user`, matching the `TINA4_DATABASE_USERNAME` env var that
  already exists in all four. The env var is the tie-breaker: the property should
  read the same as the setting it comes from.
- **`database` for every engine, including sqlite.** A sqlite file IS the
  database. `path` becomes an alias at most; one concept, one field name.
- **Default ports are applied at parse time** and are part of the contract, not
  the driver's business: postgres 5432, mysql 3306, mssql 1433, firebird 3050. A
  URL with no port must yield the same struct in all four (kills D2).
- **Alias resolution happens once, at parse.** `postgresql`/`pgsql` to `postgres`;
  `sqlserver` to `mssql`; `sqlite3` to `sqlite`. The alias table is data, shared,
  and asserted by the fixture below.
- **Percent-decoding applies to username and password.** Both PHP and Node
  already do it; making it contractual keeps it from regressing.
- **`toSafeString()` is mandatory in all four**, and it is the ONLY form allowed
  in a log line or an error message.

## Methodology

1. Settle D3 first, on real Firebird (task #312 has the server). Decide what
   `firebird://host:3050//path/to/db` must yield, write it down, and only then
   build the parser. Building first and deciding later is how the current
   three-way split happened.
2. Build the shared fixture: a committed table of URL to expected-struct, one file,
   read by all four suites. Same bytes, one answer key - the Frond corpus pattern.
3. Write the tests below in all four against the fixture. Confirm red.
4. PHP first this time, not Ruby: it already has the class, so the work is a rename
   (`driver` to `engine`, drop the class-name leak) plus the Firebird fix. It
   becomes the reference the other three are ported from.
5. Node next: extract `parseDatabaseUrl`'s 43 CC into the value type, one branch
   per engine, each engine's parse under CC 10. The `type`-to-`engine` and
   `user`-to-`username` renames are breaking on a public interface, so they need a
   `Breaking:` note.
6. Python and Ruby: add the type, then make `Database.__init__` / `#initialize`
   consume it instead of parsing inline. Python's sqlite raw-string special case
   moves inside the type, where its comment can finally be tested.
7. Re-measure. `parseDatabaseUrl` must be gone as an offender.

## Tests to write

Identical names in all four, driven off the shared fixture. Pure functions over
strings - no database, no mocks, nothing to stand up.

| pair | positive | negative |
| --- | --- | --- |
| parse without connecting | `database_url_parses_without_opening_a_connection` | `parsing_a_url_does_not_require_a_database` - no driver import, no socket |
| default port | `a_url_without_a_port_gets_the_engine_default` (5432/3306/1433/3050) | `a_url_without_a_port_does_not_leave_the_port_unset` |
| aliases | `postgresql_and_pgsql_resolve_to_postgres`, `sqlserver_resolves_to_mssql` | `an_unknown_scheme_raises_a_named_error` - not a silent fallback to sqlite |
| credentials | `percent_encoded_password_is_decoded` (`p%40ss` to `p@ss`) | `credentials_in_the_url_do_not_appear_in_to_safe_string` |
| sqlite | `sqlite_file_url_populates_database` | `sqlite_url_does_not_leave_database_empty` |
| sqlite memory | `sqlite_memory_forms_all_resolve_to_memory` (`sqlite::memory:`, `sqlite:///:memory:`) | `sqlite_memory_is_not_treated_as_a_file_named_memory` |
| firebird path | `firebird_double_slash_yields_the_agreed_absolute_path` (per step 1) | `firebird_absolute_path_is_not_silently_made_relative` |
| engine field | `engine_holds_a_canonical_engine_name` | `engine_never_holds_an_adapter_class_name` - the D4 leak cannot return |
| redaction | `to_safe_string_keeps_host_port_and_database` | `to_safe_string_never_contains_the_password` |
| fixture parity | `all_four_frameworks_agree_on_the_url_fixture` | `no_framework_has_a_field_the_others_lack` |

The redaction negative pair is worth its weight: a connection URL in a log is a
credential leak, and the only framework that currently has the tool to prevent it
is PHP.

## Risks

- **D4's renames are breaking on Node's public `ParsedDatabaseUrl`.** `type` to
  `engine`, `user` to `username`, `path` to `database`. Needs a `Breaking:` entry
  plus a migration note; keeping the old names as deprecated aliases is the
  tempting shortcut and it is against the no-aliases rule, so rename and note it.
- **D3 is not decidable from source.** Do not guess the Firebird answer; the
  parser is cheap to change once and expensive to change three times.
- **D2 looks harmless because a third-party default hides it.** Fix it anyway: the
  contract is the parsed struct, not what `pg` happens to assume.

## Parked

Not implemented. Blocked on the owner's go-ahead plus the Firebird decision (D3),
which needs the live server from task #312.
