# Feature 139: Graph databases (Ultipa, Neo4j, Memgraph, ArangoDB)

## Identity and status

- Matrix identity: 139 - Graph databases (multi-engine graph data layer)
- Audit state: decision-ready (greenfield - no existing implementation to audit)
- Audit note: measured 2026-08-20. NONE of the four frameworks ship a graph-database
  layer. Projects that use Ultipa today hand-roll a client per app. This feature makes
  graph a first-class Tina4 data layer that looks and feels EXACTLY like the relational
  `Database` layer: one URL-selected factory, a common adapter interface, per-engine
  adapters, `fromEnv()`, and drivers that are optional dependencies loaded only when the
  engine is actually used.
- Dependencies: the env loader (`TINA4_GRAPH_URL`), the `DatabaseUrl` parser pattern
  (reused/mirrored for graph URLs), the logging layer, the connect-timeout contract
  (`TINA4_DATABASE_CONNECT_TIMEOUT` sibling: `TINA4_GRAPH_CONNECT_TIMEOUT`).
- Dependants: any project doing relationship-heavy work (knowledge graphs, fraud rings,
  recommendations, network/lineage). Later: a graph AutoCrud, a graph dev-admin panel.
- Existing ADRs: ADR-0059 (graph data layer - unified surface + raw pass-through,
  URL-selected adapters, Ultipa bespoke drivers).
- Catalog phase: Data layer / Persistence family
- Contract fixture: `fixtures/graph_contract.json` (owed; runs against every provisioned
  engine on the lab - provider substitutability, exactly like the relational engine matrix).

## Why this feature exists

Tina4 already gives one uniform, URL-selected surface over five SQL engines. Graph data
has no such home, so every project that reaches for Ultipa (or Neo4j) rebuilds a bespoke
client, a bespoke connection story, and a bespoke test harness - the same DRY failure the
relational `Database` layer already solved once. This feature does for graph engines what
`Database` did for SQL: `GraphDatabase.create("ultipa://...")` returns an adapter with one
common surface, the driver for that engine loads only when you use it, and switching engine
is a URL change. It is modelled on `Database` deliberately and precisely - same factory
shape, same `fromEnv()`, same optional-driver rule, same no-mocks provider matrix.

The audit questions this feature answers: is the graph surface uniform across engines with
a raw escape hatch, is engine selection URL-driven, are drivers optional-and-lazy, and do
the common operations mean the same thing on all four engines.

## Existing implementation evidence

Measured, all four: NONE. Greenfield. There is no reference language to promote; the
neutral contract in `fixtures/graph_contract.json` is authored from ADR-0059 first, then
implemented into all four (PORTING-FORMULA.md flow), engine by engine.

## Engines and drivers (the four backends)

Selected 2026-08-20 with the owner. Engine is chosen by URL scheme, exactly as
`Database` chooses a SQL adapter.

| Engine | URL scheme(s) | Wire / query language | Driver strategy |
| --- | --- | --- | --- |
| **Ultipa** | `ultipa://host:port/graph` | Ultipa server, **GQL** (ISO) + UQL | **Bespoke standalone drivers** under `tina4stack`, one per language (see below). Zero-dependency; speak Ultipa's protocol directly. Community edition runs on the lab. |
| **Neo4j** | `neo4j://`, `bolt://` | **Bolt** protocol, **Cypher** | Community Bolt driver per language, an **optional dependency loaded only when used**. |
| **Memgraph** | `memgraph://`, `bolt://?engine=memgraph` | **Bolt** protocol, **Cypher** | **Same Bolt driver + adapter as Neo4j** - Memgraph is Bolt/Cypher wire-compatible, so the Neo4j adapter serves both; the scheme only sets engine-specific defaults. Near-zero extra driver work. |
| **ArangoDB** | `arango://`, `arangodb://` | HTTP/JSON, **AQL** | Community HTTP driver per language, an optional dependency loaded only when used. |

### Ultipa driver repos (standalone, under `tina4stack`)

Ultipa lacks maintained community drivers across all four languages (notably PHP and Ruby),
so we own them - separate from the framework, reusable outside Tina4, versioned on their own:

- `tina4stack/ultipa-node` -> npm `@tina4stack/ultipa` (or `ultipa-client`)
- `tina4stack/ultipa-python` -> PyPI `tina4-ultipa`
- `tina4stack/ultipa-ruby` -> RubyGems `tina4-ultipa`
- `tina4stack/ultipa-php` -> Packagist `tina4stack/ultipa`

Each is a thin, zero-dependency client over Ultipa's wire protocol, with the SAME shaped
API in every language so the four framework adapters wrap them identically. The framework
declares them as **optional/suggested** dependencies - installed and loaded only when a
project actually opens an `ultipa://` connection. Neo4j/Memgraph/ArangoDB reuse existing
community drivers the same optional way (no bespoke repos for those three).

**Protocol reference (Ultipa v5).** The v5 JDBC driver docs
(https://www.ultipa.com/docs/v5/tools/jdbc-driver) pin the CONNECTION contract our drivers
mirror:

- DSN: `jdbc:ultipa://<host>:<port>/<graph>?user=<u>&password=<p>` -> our scheme is
  `ultipa://<host>:<port>/<graph>` with `user`/`password` from the URL or
  `TINA4_GRAPH_USERNAME`/`_PASSWORD`.
- **Default port `60061`.**
- **Query language is GQL** (ISO). The JDBC driver additionally auto-translates a SQL
  `SELECT` subset to GQL (`com.ultipa.sql2gql.SqlToGqlTranslator`) and offers GQL
  passthrough - our `query()`/`execute()` raw hatch sends GQL/UQL directly; a SQL->GQL
  convenience is OUT OF SCOPE for v1.
- Auth: username/password.
- The JDBC page does NOT disclose the on-the-wire transport; Ultipa's official SDKs are
  **gRPC + protobuf**, so the bespoke drivers target Ultipa's gRPC service definitions as
  the protocol source, not the JDBC/Java layer (JDBC is Java-only and Type-4). Confirm the
  exact `.proto`/endpoint set against the lab's community edition before writing the wire
  layer.

Lab provisioning example (Ultipa community edition, GQL, RBAC on):

```
ultipa-gqldb --db /path/to/data --rbac --admin-pass C8e1234!
```

## The contract in one paragraph

`GraphDatabase.create(url)` (mirroring `Database.create`) parses the scheme, picks the
adapter, and connects lazily; `GraphDatabase.fromEnv()` reads `TINA4_GRAPH_URL` (plus
`TINA4_GRAPH_USERNAME`/`_PASSWORD`, `TINA4_GRAPH_CONNECT_TIMEOUT`). Every adapter implements
ONE common surface - `addNode(label, props)`, `addEdge(fromId, toId, type, props)`,
`getNode(id)`, `updateNode(id, props)`, `deleteNode(id)`, `neighbors(id, opts)` and
`traverse(startId, opts)` for the portable node/edge/traversal core - PLUS a raw
pass-through, `query(text, params)` (read) and `execute(text, params)` (write), where
`text` is the engine's NATIVE language (GQL/UQL on Ultipa, Cypher on Neo4j/Memgraph, AQL on
ArangoDB). The unified core returns engine-neutral `GraphNode { id, labels, properties }`
and `GraphEdge { id, type, from, to, properties }`; raw queries return a `GraphResult`
(records + columns, same shape as the relational `DatabaseResult`). Writes fail loud (raise
on a bad statement, cause on `getError()`), connects are bounded by the timeout contract,
and the driver for an engine is imported only on first use of that engine - the zero-dep
core is preserved. Nothing about the surface changes when you switch the URL scheme; only
the raw-query dialect does.

## Methodology (how to implement, per PORTING-FORMULA.md)

1. Read ADR-0059 and this file. Author the neutral packet first; do not copy an app's
   existing Ultipa client.
2. Build the shared **standalone Ultipa driver** repos under `tina4stack` FIRST (they are
   the only bespoke wire work), one language at a time, each with its own real-Ultipa test
   suite against the lab's community edition. Publish pre-releases.
3. In each framework, add a `graph/` module mirroring `database/`: a `GraphDatabase`
   factory + `GraphUrl` parser + a `GraphAdapter` interface + one adapter file per engine
   (`ultipa`, `bolt` [Neo4j+Memgraph], `arango`). Selection is by URL scheme; the driver
   import is lazy and guarded ("driver not installed for `<scheme>`: run `<install cmd>`").
4. Implement the portable core (addNode/addEdge/getNode/updateNode/deleteNode/neighbors/
   traverse) on every adapter, and the raw `query`/`execute` pass-through in the native
   dialect. Keep the neutral `GraphNode`/`GraphEdge`/`GraphResult` shapes identical to the
   relational analogues.
5. Provision the engines on the lab for real-service testing (NO MOCKS): Ultipa community
   edition is already up; add Neo4j, Memgraph and ArangoDB (Docker) behind the
   require-services gate, each with its own `TINA4_TEST_<ENGINE>_URL`.
6. Write the contract suite from `fixtures/graph_contract.json` with the case names below,
   parameterised over EVERY provisioned engine (provider substitutability), each exercising
   a REAL connection and REAL round-trips, NO mocks. Prove each negative can fail by
   mutating the adapter.
7. Flip the fixture `status` owed -> proven per framework+engine, run
   `scripts/audit-contract-fixtures.py`, update the CONTRACT-MAP row. Ship
   `feature/release<ver>` -> `v3` -> tag, lockstep across all four (parity feature).

## Tests to write (the answer key)

From `fixtures/graph_contract.json` - identical case names in all four suites, run against
each provisioned engine:

- `graph-connect-by-url` - a URL scheme selects the right adapter and connects
- `graph-add-node` - addNode returns a node with an id, labels and properties
- `graph-add-edge` - addEdge links two nodes; the edge carries type + properties
- `graph-get-node` - getNode round-trips the stored properties
- `graph-update-node` / `graph-delete-node` - mutate + remove, verified by re-read
- `graph-neighbors` - neighbors(id) returns the connected nodes for a direction/edge-type
- `graph-traverse-depth` - traverse(start, {depth}) returns the reachable set to N hops
- `graph-raw-query` - the native dialect (GQL/Cypher/AQL) round-trips through query()
- `graph-write-fails-loud` - a bad raw statement RAISES (never a falsy return), cause on getError()
- `graph-driver-optional` - a missing engine driver raises an actionable "install" error, and
  the zero-dep core still imports without any graph driver present
- `graph-connect-timeout` - an unreachable host throws within `TINA4_GRAPH_CONNECT_TIMEOUT`,
  naming host/port/elapsed (mirrors the relational connect-timeout contract)

## Documentation home

- **Primary reference, per framework:** a new `docs/<lang>/graph-databases.md` mirroring the
  existing `docs/<lang>/database.md` - the `GraphDatabase.create`/`fromEnv` factory, the URL
  scheme table, the unified node/edge/traverse surface, the raw `query`/`execute` escape
  hatch, and the optional-driver install note per engine. `<lang>` = `python`, `php`, `ruby`,
  `nodejs`.
- **Quick reference, per framework:** a `### Graph` block in `docs/<lang>/index.md` (anchor
  `#graph`) next to the `### Database` block, with one `create` + one `addNode`/`addEdge`
  example.
- **Standalone driver docs:** each `tina4stack/ultipa-<lang>` repo carries its own README +
  API reference (these are independent packages, so they are documented at the package, not
  in the framework docs, which only reference them as an install dependency).
- **Cross-framework contract (this planning set, NOT developer docs):**
  `plan/v3/decisions/ADR-0059.md`, `features/139-graph-databases.md`,
  `fixtures/graph_contract.json`.
- **Book (optional follow-up):** a "Working with graph data" chapter once the docs-site
  pages are stable.

## Out of scope (deferred)

A graph ORM / active-graph model, a graph AutoCrud, a graph dev-admin visualiser, GraphQL->
graph resolvers, cross-engine query translation (each engine keeps its own raw dialect - we
do NOT build a universal graph query language on top), and migrations for graph schema. The
portable core stays deliberately small (nodes, edges, neighbours, traversal, raw); anything
engine-specific goes through the raw pass-through. Revisit each on real demand. See ADR-0059
"Out of scope".
