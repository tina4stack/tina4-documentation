# Feature 014: MongoDB SQL-translation provider

## Identity and status

- Matrix identity: 14 - MongoDB SQL-translation provider
- Audit state: decision-ready
- Dependencies: Feature 3 adapter interface, Feature 4 URL parser, Feature 5 write facade,
  Feature 6 query builder (its SQL is the parser's input), Feature 7 (`MAX_BIND_PARAMS = 0`)
- Dependants: ORM, pagination, MongoDB-backed session/cache/queue/docstore
- Existing ADRs: ADR-0044 (batch/first-row primitives, `connect` canonical name); the
  connect-timeout contract applies
- Shared fixtures: `write_path_contract.json`; a `mongodb_contract.json` is required
- Catalog phase: Database providers
- Audit note: measured from four-language source; no framework code changed. This is the
  highest-divergence-risk provider in the matrix.

## Why this feature exists

MongoDB is not a SQL database. This provider lets a Tina4 application built on the SQL ORM
run against MongoDB by parsing the ORM's generated SQL and translating it into MongoDB
operations. That translation is the whole feature, and it is where the four ports diverge
most.

## Boundary

This provider owns a SQL-to-MongoDB translator: it parses the `SELECT`/`INSERT`/`UPDATE`/
`DELETE` text Feature 6 produces and emits `find`, `insertOne`/`insertMany`, `updateMany`,
`deleteMany` and `aggregate` pipelines. It owns `_id`/primary-key mapping and the
document-vs-row shape. It does NOT own the SQL text itself (Feature 6) nor the write facade
(Feature 5).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Driver | `pymongo` | `mongodb` extension | `mongo` gem | `mongodb` package |
| Model | SQL text parsed to Mongo ops | SQL text parsed | SQL text parsed | SQL text parsed |
| `getDatabaseType` | `mongodb` | `mongodb` | `mongodb` | `mongodb` |
| Source size | 765 lines | 1282 lines | 577 lines | 703 lines |
| Translate/parse density | high (44 sites) | highest (53 sites) | high (50 sites) | high (34 sites) |
| Batch collapse | none (`MAX_BIND_PARAMS = 0`) | none | none | none |

Every port re-implements a SQL parser: it reads `WHERE`, `ORDER BY`, `LIMIT`/`OFFSET`,
`GROUP BY` and (where supported) `JOIN`, and builds the matching Mongo filter, sort, limit,
skip and aggregation. The source sizes vary more than two-to-one (Ruby 577 lines, PHP 1282
lines), which is direct evidence that the four parsers cover DIFFERENT subsets of SQL. The
same ORM query can therefore produce a correct find on one port, a different pipeline on a
second, and a parse failure on a third. No shared fixture yet proves the four translators
agree.

## Public surface contract

The provider implements the Feature 3 adapter interface: connection (`connect`, `close`,
`getDatabaseType` -> `mongodb`), execution (`execute`, `executeMany`, `fetch`, `fetchOne`),
transactions and introspection. The surface matches the SQL providers so the ORM does not
special-case Mongo; the translation happens entirely inside these methods.

## Inputs and outputs

- The input to execution is SQL text plus bound parameters; the output is rows shaped like
  a SQL result, projected from Mongo documents.
- A document `_id` (ObjectId) maps to the model's primary key; an integer or string PK the
  application defines is preserved, and a generated `_id` is returned as a string.
- `execute` on an INSERT returns a `DatabaseResult` carrying the new document's id.
- `getColumns` is inferred (MongoDB is schemaless), so it reports the fields the translator
  can see, best-effort; `getTables` lists collections.
- Native BSON types (embedded documents, arrays, dates, binary) round-trip as native
  structures where the ORM can carry them.

## Lifecycle and operation graph

1. Feature 4 resolves the `mongodb:` URL to hosts, database and credentials.
2. `connect` opens the client with a bounded connect timeout.
3. Feature 6 builds SQL; the provider parses it and runs the matching Mongo operation.
4. A multi-document transaction uses a Mongo session on a replica set where the deployment
   supports it; otherwise writes are single-document atomic (stated, not silently dropped).
5. `close` releases the client and is idempotent.

## Configuration and precedence

- The connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT` (default 10) mapped to the
  Mongo client's `serverSelectionTimeoutMS`/connect timeout, with a caller-set value
  winning.
- A configurable collection/database mapping follows Feature 4; there are no other
  Mongo-specific environment variables in the provider itself.

## Failures, side effects and security

- Parameters are bound into the Mongo filter as values, never concatenated into a string,
  so there is no query injection through the translated filter.
- A SQL construct the translator does not support fails LOUDLY with the offending SQL and
  the unsupported construct named; it never silently returns an empty result or a partial
  translation.
- The connect is bounded, so an unreachable replica set fails within the timeout naming the
  hosts, elapsed seconds and the timeout variable.
- Transaction support is stated per deployment; a single-node deployment does not pretend to
  offer multi-document atomicity.

## Wire and persistence contract

Communication is the MongoDB wire protocol through the host driver. The persistence model
is documents, not rows; the provider projects documents into row shape on read and maps
row writes into documents. The contract that matters is SEMANTIC EQUIVALENCE: the same ORM
operation must produce the same observable result on Mongo as on a SQL provider, for the
subset of SQL the translator supports.

## Providers and substitutability

This provider is itself a translation shim; there is no second Mongo implementation per
language. Substitutability runs the OTHER way: an application written against the SQL ORM
substitutes MongoDB underneath, within the translator's supported SQL subset. That subset
must be identical across the four ports.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| MG-01 | Four independent SQL parsers with >2x source-size variance cover different SQL subsets; the same ORM query can succeed differently or fail per port. | Define ONE supported-SQL subset and prove all four translators produce the same Mongo operation and the same rows for every case in it. |
| MG-02 | An unsupported SQL construct's behavior (loud failure vs silent empty vs partial) is not proven uniform. | Every unsupported construct fails loudly and identically in all four; gate it. |
| MG-03 | `_id`/ObjectId to primary-key mapping (generated id as string, app-defined PK preserved) is not gated as parity. | Gate id mapping on insert and read in all four. |
| MG-04 | JOIN/`$lookup` and GROUP BY/`aggregate` coverage differs by port (the size variance). | Pin which joins and aggregations are in the subset; prove or reject each identically. |
| MG-05 | Multi-document transaction semantics depend on the deployment and are not stated uniformly. | State transaction support per deployment identically; gate single-node vs replica-set behavior. |
| MG-06 | Mongo-backed subsystems have shipped real defects (the Node Mongo queue redelivered every completed job for two releases). | The provider fixture must exercise real read-write-delete cycles, not shapes, so a lifecycle bug cannot hide. |
| MG-07 | No shared MongoDB fixture exists. | Add `mongodb_contract.json` proving semantic equivalence. |

## Owner decisions

1. There is ONE supported-SQL subset for the Mongo translator, identical across the four
   ports, and it is written down. SQL outside it fails loudly and identically.
2. Semantic equivalence is the contract: every supported ORM operation returns the same
   observable rows on Mongo as on a SQL provider.
3. A generated `_id` is returned as a string; an application-defined PK is preserved.
4. Transaction support is stated per deployment; a single node does not fake multi-document
   atomicity.
5. The fixture exercises real read-write-delete lifecycles against a live MongoDB, because
   a shape-only test has already let a data-loss bug ship.

## Proposed conformance fixture

Add `mongodb_contract.json` (with `write_path_contract.json`) against a live lab MongoDB
with stable ids for: a bounded connect and an unreachable-host timeout; INSERT returning a
string id and an app-defined PK preserved; a `WHERE`/`ORDER BY`/`LIMIT`/`OFFSET` SELECT
returning the same rows as the SQL providers; a GROUP BY translated to `aggregate`; an
unsupported construct failing loudly and identically; a full insert-update-read-delete
lifecycle proving no stale document survives; `getTables` listing collections. Every
behavioral case uses a live lab MongoDB; a mock is explicitly forbidden here because a
mock-based Mongo test already masked a redelivery bug.

## Integration map

- The registry selects this provider from `mongodb:`; the factory constructs it with
  Feature 4's parameters.
- Feature 6 produces the SQL the translator consumes; Feature 5 composes CRUD.
- ORM, pagination and any Mongo-backed session/cache/queue/docstore depend on the
  translator's supported subset being complete and identical.
- Central fixtures, four runners, CI matrix, release notes and docs update together.

## Breaking changes and migration

- The supported-SQL subset becomes explicit; an application using a construct outside it now
  gets a loud, identical failure instead of a per-port surprise.
- Id mapping and unsupported-construct behavior converge across the four ports.
- No change to application ORM calls within the supported subset.

## Implementation backlog

1. Define and document the one supported-SQL subset for the Mongo translator.
2. Add `mongodb_contract.json` and wire four runners against a live lab MongoDB.
3. Prove semantic equivalence for every subset case; converge the four parsers.
4. Make every unsupported construct fail loudly and identically (MG-02).
5. Gate id mapping (MG-03) and full read-write-delete lifecycles (MG-06).
6. State transaction support per deployment identically (MG-05).
7. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Build a SQL-to-Mongo translator over the host's MongoDB driver. Parse the ORM's SQL into
`find`/`insert`/`update`/`delete`/`aggregate`, bind parameters as filter VALUES (never
string-concatenated), map `_id`/ObjectId to the model primary key (generated id as a
string), and project documents into row shape. Support exactly the one written-down SQL
subset and fail loudly on anything outside it. Bound the connect, state transaction support
per deployment, and prove the port against a live MongoDB with real read-write-delete
lifecycles, never a mock.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
