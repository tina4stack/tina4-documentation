# Feature 004: Database URL parser

## Identity and status

- Matrix identity: 4 — Database URL parser
- Audit state: decision-ready
- Audit note: Decisions APPROVED 2026-08-10; implementation deliberately not started (build phase pending runner wiring)
- Dependencies: Feature 1 typed environment, Feature 3 adapter interface and
  Feature 5 provider contracts.
- Dependants: database factories, connection pools, cache identity, migrations,
  sessions, queues, dev-admin, doctor/status output and every provider adapter.
- Existing ADRs: see retained evidence and the central decision index
- Shared fixtures: not yet confirmed

- Original audit: 2026-07-28 to 2026-07-30.
- Adversarial re-audit: 2026-08-10.
- Release boundary: breaking corrections are permitted before 3.14.0.
- Existing fixture: four divergent copies of `database_url_corpus.json`.
- Proposed authority: `plan/v3/fixtures/database_url_contract.json`.

The old packet says Feature 4 shipped in all four with byte-identical fixtures.
That status is withdrawn. The copies now have different hashes and case counts,
and all four database factories still parse or reinterpret connection data after
the `DatabaseUrl` value has been constructed.

## Why this feature exists

One connection string must select the same provider, endpoint, credentials,
database and options in every Tina4 language without leaking its secrets or
silently connecting somewhere else.

## Boundary

Feature 4 owns:

- recognizing supported connection-string forms and canonical aliases;
- lossless conversion into one native value shape;
- percent decoding, default ports, IPv6 and multi-host authorities;
- URL, explicit-argument and environment precedence;
- connection options and safe rendering;
- a credential-free but authorization-aware connection identity;
- named failures for malformed, ambiguous and unsupported input.

The public database factory consumes this value once. An adapter receives the
resolved provider configuration and does not parse the raw URL again. Feature 3
owns connecting. Feature 5.x packets decide which retained options each provider
supports and how they map onto its driver.

The parser performs no I/O, imports no driver, resolves no DNS and opens no
socket. Pure parsing tests are necessary; factory and live provider tests prove
that the parsed value is actually used.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

### Current public value

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Dedicated `DatabaseUrl` | yes | yes | yes | yes |
| Canonical `engine` | yes | SQL engines only | yes | yes |
| MongoDB represented | partial | no | partial | partial |
| ODBC represented | yes | no | yes | yes |
| Environment credential fallback | yes | **no** | yes | yes |
| Factory consumes parsed value once | **no** | **no** | **no** | SQL fields only |
| Downstream raw reparse | adapters + SQLite path | factory + adapters | drivers | Mongo raw URI; Firebird helpers |
| Query options retained | no | no | no | no |

PHP has `MongoDBAdapter` and `ODBCAdapter` registrations but its public
`DatabaseUrl` rejects both schemes. The facade therefore accepts strings the
value object says are unsupported. A developer, doctor command and factory do
not share one answer.

### Fixture drift

The existing copies all claim to be byte-identical:

| Framework | SHA-1 | Positive cases | Material unique coverage |
| --- | --- | ---: | --- |
| Python | `64a5e64a3112b1b289aff5e3019aa05ec3a749ab` | 22 | two ODBC rows, including brace delimiter |
| PHP | `6b9183722f347b5678ac22d060377721df2169cf` | 19 | neither ODBC nor explicit-empty-password row |
| Ruby | `23d25dc62dd1fc52dc28eb55b4818838066a871c` | 20 | one differently named ODBC row |
| Node | `415d7b68475c2de491c92b3ed2cc0db866b48498` | 21 | differently named empty-password and ODBC rows |

Each runner executes its own copy, so every suite can be green while parity is
red. Stable case IDs, a central authority and fail-closed copy/hash checks are
required.

### Focused execution

The lab ran the current focused suites as root with live PostgreSQL and Firebird:

| Framework | Existing-suite result |
| --- | --- |
| Python | 108 passed |
| PHP | 84 tests, 335 assertions |
| Ruby | 94 examples, 0 failures |
| Node | all current parser, credential, path and Firebird checks passed |

Those green results establish a regression baseline only. The adversarial
cross-language probes below are outside the current answer keys.

### Provider URL forms

#### SQLite

- `sqlite::memory:` and `sqlite:///:memory:` mean the in-memory database.
- `sqlite:///data/app.db` is relative.
- `sqlite:////var/data/app.db` and `sqlite:/var/data/app.db` are absolute on
  Unix-like systems.
- `sqlite:///C:/data/app.db` is an absolute Windows drive path.
- Percent-encoded path bytes are decoded once. A literal percent is `%25`.
- An empty SQLite target throws. A bare filename is not a `DatabaseUrl`; callers
  spell the provider explicitly.

Feature 8 resolves relative paths against the application root. The parsed
value retains relative versus absolute intent.

#### Single-host SQL and Firebird

- Host and database are required. Tina4 does not silently select a local Unix
  socket, OS username database or driver-specific default database.
- IPv6 literals require brackets in input; the stored host excludes brackets and
  canonical rendering adds them back.
- The database/path is percent-decoded once.
- Firebird strips exactly one URL path separator, so the documented double-slash
  absolute form retains one leading slash.

#### MongoDB

- Standard `mongodb://` accepts the complete ordered seed list.
- `mongodb+srv://` retains its protocol and single SRV hostname.
- Query options, including replica-set, TLS, authentication and read-preference
  options, are retained without being reinterpreted by this feature.
- An omitted MongoDB database normalizes to Tina4's conventional `tina4`.

Standard MongoDB deployment URLs require multi-host seed lists and query options,
and MongoDB recommends SRV URLs where possible. They are therefore part of a
production-ready parser, not provider-specific text to discard. References:

- <https://www.mongodb.com/docs/manual/reference/connection-string/index.html>
- <https://www.mongodb.com/docs/manual/reference/connection-string-options/>

#### ODBC

`odbc:///` is followed by the driver connection string. The parser retains it
losslessly for the driver and recognizes brace quoting, semicolon delimiters and
doubled `}}` escapes well enough to redact credential values completely.

### Options and percent encoding

- Query option names and values are percent-decoded exactly once.
- Option order and repeated values survive parsing. The options map uses a list
  for every key so no runtime silently keeps only the first or last duplicate.
- Fragments are rejected. They have no database connection meaning and silently
  dropping one can hide a malformed password or database name.
- Unknown options are retained by the parser. The selected provider either maps
  them through its Feature 5.x contract or throws an unsupported-option error;
  it never ignores them silently.
- Malformed percent encoding throws before adapter selection.
- `toSafeString` emits a canonical percent-encoded URL, not decoded delimiters.

The current implementations decode username/password but retain encoded database
names and SQLite paths. They also emit a decoded username such as `user@corp`
without re-encoding the `@`, producing an ambiguous safe URL. Both halves must
be corrected together.

### Canonical connection identity

`identity()` feeds database query caches and connection diagnostics. It contains:

- canonical protocol;
- every normalized host and port in order;
- resolved absolute SQLite path or normalized database name;
- username, because different roles can see different rows through grants,
  row-level security and session defaults;
- every non-secret connection option that can change routing or visibility.

It excludes passwords, tokens and secret option values. The identity may be
hashed before use as a cache key.

The current four-language cache identity deliberately excludes username on the
assumption that roles see the same data. That is false for row-level security.
It also uses a relative SQLite path, so two applications both configured as
`sqlite:///data/app.db` and sharing a persistent cache can collide. Feature 72
must consume this canonical identity rather than rebuild its own subset.

## Public surface contract

The audit has not yet extracted a language-neutral public surface and its idiomatic spellings.

## Inputs and outputs

### Canonical value contract

`DatabaseUrl` is an immutable native value with these concepts:

| Concept | Type | Rule |
| --- | --- | --- |
| `engine` | string | canonical provider: `sqlite`, `postgres`, `mysql`, `mssql`, `firebird`, `mongodb`, `odbc` |
| `protocol` | string | canonical connection protocol; normally the engine, with `mongodb+srv` retained distinctly |
| `hosts` | native list | ordered `{host, port}` records; empty for SQLite/ODBC; IPv6 host text excludes brackets |
| `database` | string | decoded database name or SQLite/Firebird path |
| `username` | string or null | decoded; null means absent, empty means explicitly empty |
| `password` | string or null | decoded; null means absent, empty means explicitly empty |
| `options` | native map | decoded option names to ordered native string lists; duplicates are retained |
| `connection_string` | string or null | ODBC driver string only; never displayed without redaction |

The same data keys are visible in every language. Method spelling remains
idiomatic:

| Concept | Python | PHP | Ruby | Node / another camelCase language |
| --- | --- | --- | --- | --- |
| construct | `DatabaseUrl(url, ...)` | `new DatabaseUrl($url, ...)` | `DatabaseUrl.new(url, ...)` | `new DatabaseUrl(url, ...)` |
| from environment | `from_env(key=...)` | `fromEnv($key)` | `from_env(key)` | `fromEnv(key?)` |
| safe form | `to_safe_string()` | `toSafeString()` | `to_safe_string` | `toSafeString()` |
| driver target | `dsn()` | `getDsn()` | `dsn` | `dsn()` |
| connection identity | `identity()` | `getIdentity()` | `identity` | `identity()` |

`dsn` is driver-facing and is not safe to log: ODBC necessarily includes its
credential keywords. `toSafeString` is the display form.

## Lifecycle and operation graph

```text
explicit config / typed environment / default
  -> construct DatabaseUrl once
  -> validate protocol, authority, path, port and encoding
  -> resolve credentials and options
  -> registry selects adapter from canonical engine
  -> adapter receives resolved provider config
  -> connect and verify provider identity
  -> safe status/log rendering or credential-free cache identity
```

Doctor, migrations, session database handlers, cache database backends and
dev-admin use the same parser and registry path. None carries a private scheme
switch or `parse_url` / `urlparse` / `URI.parse` copy.

## Configuration and precedence

The public database factory resolves the URL source in this order:

1. explicit URL argument;
2. typed `TINA4_DATABASE_URL` from Feature 1;
3. the framework's explicit default SQLite URL.

Legacy `DATABASE_URL` and `DB_URL` are not fallback aliases. Feature 1's legacy
guard names `TINA4_DATABASE_URL` and fails outright.

Credentials resolve component by component (Decision 8, amended 2026-08-10 so an
explicit argument outranks the URL, per ADR-0041):

1. an explicit constructor/factory argument, including an explicitly empty value;
2. the URL component, including an explicitly empty value;
3. `TINA4_DATABASE_USERNAME` / `TINA4_DATABASE_PASSWORD`;
4. a documented provider default, if that provider has one.

Omitted arguments are null, not empty-string defaults, because the distinction
controls fallback. PHP `DatabaseUrl::fromEnv()` currently ignores the separate
credential environment variables; the other three apply them.

Provider options follow the same pattern: URL option, explicit provider option,
engine-specific typed environment, documented default. A URL value is never
silently discarded downstream.

## Failures, side effects and security

### Safe rendering and failures

- Empty, malformed, unsupported and incomplete URLs throw a named
  `DatabaseUrl` category before driver import or network I/O.
- Error and log messages never contain the raw URL, password, ODBC credential,
  token or secret option value.
- The error names safe fields such as canonical protocol, bracketed host and
  invalid port category. If safe extraction is impossible, it names no substring
  from the input.
- `toSafeString`, normal string conversion, debug inspection and JSON/debug
  serialization replace every credential with `***` while retaining useful
  endpoint and option information.
- The live `password` and ODBC connection string remain available only because
  the adapter needs them. Automatic framework persistence to caches, sessions,
  queues or logs is forbidden.
- A general `redactCredentials(raw)` is best-effort for recognizable URL and DSN
  grammar. An invalid-URL error does not rely on best-effort redaction; it omits
  the raw value.

Malformed userinfo containing an unencoded `/` currently exposes a password
fragment in Python, PHP and Node exception text. Ruby is correct. ODBC doubled
brace escapes currently expose the password tail in PHP, Ruby and Node; Python
is correct. Both shapes are release-blocking security cases.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

## Providers and substitutability

### Supported protocols and aliases

| Accepted input | Canonical engine | Canonical protocol |
| --- | --- | --- |
| `sqlite`, `sqlite3` | `sqlite` | `sqlite` |
| `postgres`, `postgresql`, `pgsql` | `postgres` | `postgres` |
| `mysql`, `mariadb` | `mysql` | `mysql` |
| `mssql`, `sqlserver` | `mssql` | `mssql` |
| `firebird` | `firebird` | `firebird` |
| `mongodb` | `mongodb` | `mongodb` |
| `mongodb+srv` | `mongodb` | `mongodb+srv` |
| `odbc` | `odbc` | `odbc` |

Implementation names such as `pymongo`, `DataPostgresql` and driver class names
are never connection schemes. Ruby's current `mongo` shorthand is removed rather
than creating an undocumented alias in the other languages. Unknown schemes
throw and never fall back to SQLite.

Default ports are applied during parsing: PostgreSQL 5432, MySQL/MariaDB 3306,
MSSQL 1433, Firebird 3050 and standard MongoDB 27017. An explicit port must be
between 1 and 65535. Port zero is invalid, not an instruction to use the default.
An SRV MongoDB URL does not carry an explicit port.

## Contradictions and defects

| ID | Finding | Required correction |
| --- | --- | --- |
| DBU-01 | Four fixtures claim identical bytes but have four hashes and 19-22 cases | One central versioned fixture, exact-copy/hash guard and stable case IDs |
| DBU-02 | Factories/adapters parse connection strings again in every runtime | Parse once; adapters consume resolved config |
| DBU-03 | PHP value rejects registered MongoDB and ODBC adapters | Cover every Feature 3 provider in the value and registry |
| DBU-04 | Query options disappear in all four; Node Firebird contaminates `database` with the query before later stripping it | Retain typed option data and pass it to the provider |
| DBU-05 | PHP `fromEnv` drops separate username/password fallbacks | Apply the shared component precedence |
| DBU-06 | Missing hosts/databases and port zero are accepted differently | Enforce provider-required fields and port range before connection |
| DBU-07 | Python IPv6 rendering loses brackets; other runtimes store brackets in the host value | Store unbracketed host; bracket only during rendering |
| DBU-08 | Database names and SQLite paths are not percent-decoded | Decode once and reject malformed escapes |
| DBU-09 | Safe strings emit decoded user delimiters without re-encoding | Canonically percent-encode every rendered component |
| DBU-10 | Python/PHP/Node malformed slash-password errors expose a credential fragment | Omit raw malformed input; add the adversarial sentinel case |
| DBU-11 | PHP/Ruby/Node ODBC doubled-brace redaction leaks the password tail | Parse `}}` escape and redact the complete value |
| DBU-12 | Mongo seed lists and `mongodb+srv` are not representable | Add ordered hosts and canonical protocol |
| DBU-13 | Ruby accepts `mongo`; PHP facade accepts `pymongo`; neither is shared contract data | Remove implementation/private aliases |
| DBU-14 | Cache identity excludes authorization role and resolved SQLite location | Use `DatabaseUrl.identity()` in Feature 72 |
| DBU-15 | Current tests assert parsed fields but do not prove the factory connects using them | Add factory trace and live mutation witnesses |

## Owner decisions

The recommended rules for owner approval are:

1. The public factory parses exactly once; adapters never reinterpret raw URLs.
2. The canonical value adds `protocol`, ordered `hosts`, option lists and
   credential-free `identity` rather than preserving a single-host-only shape.
3. MongoDB seed lists and `mongodb+srv` are required production forms.
4. Query options are lossless parser data and may never be silently ignored.
5. SQL/Firebird URLs require host and database; Mongo without a database uses
   `tina4`; SQLite requires an explicit file or memory target.
6. Ports are 1-65535 and IPv6 hosts are stored without brackets.
7. Database names, paths, credentials and options are percent-decoded once and
   canonically encoded when rendered.
8. Explicit arguments, including empty values, outrank URL values; URL values
   outrank environment; environment outranks provider defaults. (Amended
   2026-08-10 from URL-outranks-argument, per ADR-0041; see the APPROVED block.)
9. Accepted aliases are exactly the table in this packet. `mariadb` is added;
   `mongo` and `pymongo` are removed; `mongodb+srv` is a protocol, not an alias.
10. Fragments and malformed percent escapes fail outright.
11. Cache identity includes username, all endpoints, resolved SQLite location
    and non-secret routing/visibility options, but never credentials.
12. Invalid input is never echoed, even after best-effort redaction.

The packet remains decision-ready until these are accepted or amended.

### Owner decisions APPROVED (finalized 2026-08-10)

Andre stepped through the twelve owner decisions with the four genuine calls
surfaced separately. Eleven stand as written; Decision 8 is amended.

**Ratified as written (1-7, 9-12):** parse exactly once (1); the value adds
`protocol`, ordered `hosts`, option lists and credential-free `identity` (2);
Mongo seed lists and `mongodb+srv` are required forms (3); query options are
lossless (4); SQL/Firebird require host and database, Mongo without a database
uses `tina4`, SQLite requires an explicit target (5); ports are 1-65535 and IPv6
hosts store unbracketed (6); every component is percent-decoded once and
canonically encoded on render (7); the alias table is exact - `mariadb` added,
`mongo`/`pymongo` removed, `mongodb+srv` a protocol not an alias (9); fragments
and malformed escapes fail outright (10); cache identity includes username, all
endpoints, resolved SQLite location and non-secret routing options, never
credentials (11); invalid input is never echoed (12).

**Decision 8 AMENDED - explicit argument outranks the URL.** The plan had the URL
component (including an explicitly empty value) outrank an explicit
constructor/factory argument. That contradicts ADR-0041 (an explicit argument is
the highest authority everywhere else in the framework) and silently ignores a
passed credential. The final credential precedence is:

1. an explicit constructor/factory argument, including an explicitly empty value;
2. the URL component, including an explicitly empty value;
3. `TINA4_DATABASE_USERNAME` / `TINA4_DATABASE_PASSWORD`;
4. a documented provider default.

So `postgres://user:@host/db` constructed with `password='secret'` resolves to
`secret`, not empty. A null argument is absent and falls through to the URL; an
explicitly empty argument is a value and wins. One precedence rule now governs the
whole framework. The URL-source order (explicit URL argument, then
`TINA4_DATABASE_URL`, then the default SQLite URL) is unchanged - only the
per-component credential order flips.

The four genuine calls, stepped through with the owner:

- **A (value shape): ordered `hosts` list.** Ratifies Decision 2. The value carries
  an ordered `{host, port}` list for every engine; single-host engines get a
  one-element list; Mongo carries its full seed list. Breaks callers reading
  singular `.host` / `.port` (migration note already recorded); a first-endpoint
  helper eases the pre-3.14 transition.
- **B (credential precedence): explicit argument wins.** The Decision 8 amendment
  above.
- **C (cache identity): corrected identity adopted.** Ratifies Decision 11. Identity
  gains username and the resolved absolute SQLite path; the old username-excluding,
  relative-path identity is dropped. Old cached results invalidate on upgrade
  (in-memory, trivial), fixing wrong-user cache collisions and relative-versus-
  absolute SQLite fragmentation.
- **D (Mongo no-database default): `tina4`.** Ratifies Decision 5. A Mongo URL
  without a database resolves to `tina4`, identical in all four; the parser records
  "absent" and the adapter applies `tina4` when an operation needs one.
  Deterministic and parity-safe; the driver's own default (often `test`) is
  rejected because it diverges across drivers.

This closes the DESIGN half of the FINAL bar for Feature 4. Remaining to reach
FINAL: materialize `database_url_contract.json` and wire the four fail-closed
runners (build phase).

## Proposed conformance fixture

The replacement central fixture uses stable IDs and at least these groups:

| Group | Required cases and witnesses |
| --- | --- |
| `DBU-S` schemes | every canonical scheme/alias, uppercase scheme, unknown/private aliases; registry selection witness |
| `DBU-P` paths | SQLite relative/absolute/Windows/memory, encoded space/percent, Firebird relative/absolute/alias; actual opened target |
| `DBU-H` hosts | default/explicit ports, zero/out-of-range, IPv4, IPv6, Mongo seed list and SRV; factory adapter config |
| `DBU-C` credentials | encoded delimiters, absent versus empty, URL/argument/env precedence, wrong-password live failure; driver authentication result |
| `DBU-O` options | Firebird charset, PostgreSQL TLS/search options, Mongo replica/TLS/read preferences, duplicates and empty values; provider-observed option |
| `DBU-R` redaction | safe render, malformed slash password, multiple `@`, ODBC spaces/semicolons/doubled braces, secret query options; sentinel absent from message/log/dump |
| `DBU-E` errors | empty, no scheme, missing host/database, fragment, malformed percent and port; no driver import/socket and no raw value |
| `DBU-I` identity | different role, host list, database, option and resolved SQLite path produce different identities; password rotation does not |
| `DBU-F` factory | parser called once, exact parsed fields reach selected adapter, no downstream raw parse; deliberate mutation of one parsed field changes live target |

Every runtime discovers every ID exactly once. Pure cases use no service. Provider
cases use real SQLite and the live PostgreSQL, MySQL, MSSQL, Firebird and MongoDB
services on the lab. A service skip is not conformance.

## Integration map

Implementation must update together:

- `DatabaseUrl` and its public exports;
- database constructors, factories and registries;
- every SQL, MongoDB and ODBC adapter constructor;
- connection pooling and timeout diagnostics;
- Feature 72 query-cache identity;
- migration, session, cache and queue database consumers;
- CLI migrate/status/doctor and project scaffolding;
- dev-admin environment editing and display;
- AI/framework reference text and all connection examples;
- central fixture, four fail-closed runners and live lab gates;
- release notes and the 3.14 migration guide.

## Breaking changes and migration

- Code reading singular `.host` / `.port` migrates to the ordered `hosts` value;
  a helper may expose the first endpoint during pre-3.14 migration but is not the
  clean-room contract.
- Bare filenames become explicit `sqlite:` URLs.
- Missing host/database, port zero, fragments and malformed encoding now throw.
- Database and path fields return decoded native strings.
- Safe rendering re-encodes delimiters and retains redacted query options.
- Ruby `mongo://` becomes `mongodb://`; PHP `pymongo://` becomes `mongodb://`.
- Node/other runtimes can use `mongodb+srv://` and multi-host URLs through the
  same value instead of driver-only raw strings.
- Cache keys change because authorization role and resolved location are added;
  old cached database results must be invalidated during upgrade.
- Credential precedence flips: an explicit username/password argument now outranks
  the URL component (previously the URL won, even when explicitly empty). A caller
  that passed an argument expecting the URL to override should drop the redundant
  argument; a caller relying on the old order to blank a credential must now do so
  in the URL, not the argument.

## Implementation backlog

1. Approve or amend the twelve owner decisions.
2. Materialize the central fixture and exact-copy manifest.
3. Rewire the current runners to that fixture without parser implementation
   changes and capture the complete red matrix.
4. Implement the value and safe redaction in the leanest runtime first, then
   port the contract idiomatically.
5. Make every factory and adapter consume the parsed value exactly once.
6. Move provider option interpretation into the corresponding Feature 5.x
   packet and remove downstream URL parsing.
7. Change Feature 72 to the canonical identity and invalidate old cache data.
8. Run pure, factory and live provider gates in all four.
9. Update documentation/migrations and only then mark Feature 4 stable.

## Porting capsule

A new language implements one immutable, no-I/O `DatabaseUrl`. It recognizes the
approved protocols, parses a complete ordered authority and option set, decodes
each component once, preserves absent versus empty credentials, applies explicit
precedence, validates required provider fields and renders only a canonical
redacted display. It generates an authorization-aware identity without secrets.
The database factory parses once, selects from `engine`, and passes resolved
native configuration to the Feature 3 adapter. No adapter reads the URL again.

The implementer uses this packet, Feature 1, Feature 3, the selected Feature 5.x
provider packet and the central fixture. Another runtime's parser is evidence,
not authority.

## Audit closure checklist

- [ ] Boundary and public surface complete.
- [ ] Lifecycle and every producer/consumer edge complete.
- [ ] Configuration, failure, side-effect and security rules complete.
- [ ] Wire/storage and provider contracts complete.
- [ ] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.
- [ ] Proposed shared cases and mutation witnesses complete.
- [ ] Integration map and breaking migrations complete.
- [ ] Implementation backlog dependency-ordered.
- [ ] Porting capsule is clean-room sufficient.

- [x] Boundary, value shape, lifecycle, precedence and failures drafted.
- [x] Existing fixture drift and four-language contradictions recorded.
- [x] Security and connection-identity effects recorded.
- [x] Pure and live baseline measured.
- [x] Owner decisions approved or amended (2026-08-10; Decision 8 amended, others ratified).
- [ ] Central fixture materialized after approval.
- [ ] Provider option mappings completed in Features 8-13.
- [x] Integration, migration and clean-room porting formula drafted.
