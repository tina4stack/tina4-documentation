# Graph Databases

## 1. Graph, Shaped Like Database

Relational data lives in rows. Relationship-heavy data (knowledge graphs, fraud rings, recommendations, lineage) lives in nodes and edges. Tina4 gives graph engines the same home the relational `Database` layer gives SQL: one URL-selected factory, one portable surface, and an engine driver that loads only when you use it.

Learn `Database`, you already know `GraphDatabase`. `GraphDatabase.create("ultipa://...")` parses the scheme, picks the adapter, and connects. Switching engine is a URL change. Nothing about the surface moves when the scheme does; only the raw-query dialect changes.

Tina4 speaks four graph engines: Ultipa (GQL), Neo4j and Memgraph (Cypher, one Bolt adapter for both), and ArangoDB (AQL). Every method is async, matching the async graph drivers and the relational `Database` wrapper, so `await` each call.

---

## 2. Configuration

### TINA4_GRAPH_URL

Set the connection in `.env`, exactly as you set `TINA4_DATABASE_URL`:

```bash
TINA4_GRAPH_URL=ultipa://localhost:60061/mygraph
TINA4_GRAPH_USERNAME=root
TINA4_GRAPH_PASSWORD=secret
```

The engine is chosen by the URL scheme:

| Engine | URL scheme(s) | Default port | Query language | Driver package |
|--------|---------------|--------------|----------------|----------------|
| Ultipa | `ultipa://`, `ultipas://` | 60061 | GQL | `tina4-ultipa` |
| Neo4j | `neo4j://`, `bolt://` | 7687 | Cypher | `neo4j-driver` |
| Memgraph | `memgraph://` | 7687 | Cypher | `neo4j-driver` |
| ArangoDB | `arango://`, `arangodb://` | 8529 | AQL | `arangojs` |

Neo4j and Memgraph are Bolt/Cypher wire-compatible, so one adapter serves both. The `...s` schemes (`ultipas://`) select TLS.

### Installing Graph Drivers

Drivers are optional. Importing `tina4-nodejs/orm` pulls in no engine driver, and each engine's driver is dynamically imported only on the first connection to that engine. Install the one you need:

```bash
# Ultipa
npm install tina4-ultipa

# Neo4j or Memgraph
npm install neo4j-driver

# ArangoDB
npm install arangojs
```

Open a connection whose driver is missing and the error names the package and the command, never a bare module-not-found.

### TINA4_GRAPH_CONNECT_TIMEOUT

A connect is bounded, the same way `TINA4_DATABASE_CONNECT_TIMEOUT` bounds a SQL connect:

```bash
TINA4_GRAPH_CONNECT_TIMEOUT=10
```

Seconds a graph connect may block, default 10. Set it to `0` (or less) to wait indefinitely. An unreachable host raises within the bound, naming the host and port, instead of hanging the app with no signal.

---

## 3. Creating a Connection

```typescript
import { GraphDatabase } from "tina4-nodejs/orm";

const graph = await GraphDatabase.create("ultipa://localhost:60061/mygraph");
```

`create()` reads the scheme, selects the adapter, and imports its driver lazily. Pass credentials when the URL carries none:

```typescript
const graph = await GraphDatabase.create("neo4j://localhost:7687", {
  username: "neo4j",
  password: "secret",
});
```

Or build from the environment. `fromEnv()` reads `TINA4_GRAPH_URL` (plus `TINA4_GRAPH_USERNAME` / `TINA4_GRAPH_PASSWORD`) and returns `null` when the variable is unset:

```typescript
const graph = await GraphDatabase.fromEnv();
```

---

## 4. Nodes

`addNode()` creates a vertex and returns a `GraphNode` with a non-null `id`, its labels, and the stored properties echoed back:

```typescript
const alice = await graph.addNode("Person", { name: "Alice", age: 30 });
alice.id;          // engine-assigned id
alice.labels;      // ["Person"]
alice.properties;  // { name: "Alice", age: 30 }
```

`getNode()` round-trips a stored node, and returns `null` for an id that does not exist (a miss is not an error):

```typescript
const person = await graph.getNode(alice.id);
const missing = await graph.getNode("does-not-exist");  // null
```

`updateNode()` merges properties, `deleteNode()` removes the node and its edges:

```typescript
await graph.updateNode(alice.id, { age: 31 });   // merge, verified by re-read
await graph.deleteNode(alice.id);                  // returns true
await graph.getNode(alice.id);                      // null
```

---

## 5. Edges

`addEdge()` links two existing nodes and returns a `GraphEdge` carrying its type and the from/to ids you passed:

```typescript
const alice = await graph.addNode("Person", { name: "Alice" });
const bob = await graph.addNode("Person", { name: "Bob" });

const edge = await graph.addEdge(alice.id, bob.id, "KNOWS", { since: 2020 });
edge.type;         // "KNOWS"
edge.from;         // alice.id
edge.to;           // bob.id
edge.properties;   // { since: 2020 }
```

---

## 6. Neighbours and Traversal

`neighbors()` returns the directly-connected nodes for a direction and optional edge type. Direction is `"out"`, `"in"`, or `"both"`:

```typescript
const friends = await graph.neighbors(alice.id, {
  direction: "out",
  edgeType: "KNOWS",
  limit: 50,
});
for (const friend of friends) {
  console.log(friend.properties.name);
}
```

An unmatched filter returns an empty array, not an error.

`traverse()` returns the set of nodes reachable within `depth` hops from the start:

```typescript
const network = await graph.traverse(alice.id, {
  depth: 3,
  direction: "out",
  edgeType: "KNOWS",
});
```

Bounded multi-hop traversal is the portable stand-in for each engine's native path query. The reachable set agrees across all four engines for the same graph.

---

## 7. Raw Queries

The portable core stays small. Anything engine-specific rides the raw pass-through, where `text` is the engine's native language and params are bound (never interpolated):

```typescript
// Ultipa (GQL)
const result = await graph.query("MATCH (n:Person) WHERE n.age > $min RETURN n.name", { min: 25 });

// Neo4j / Memgraph (Cypher)
const result = await graph.query("MATCH (n:Person) WHERE n.age > $min RETURN n.name AS name", { min: 25 });

// ArangoDB (AQL)
const result = await graph.query("FOR p IN persons FILTER p.age > @min RETURN p.name", { min: 25 });
```

`query()` runs a read, `execute()` runs a write. Both return a `GraphResult` (records + columns), the same shape as the relational `DatabaseResult`:

```typescript
result.records;     // array of row objects
result.columns;     // column names
result.toArray();   // the records
result.scalar();    // first value of the first record, or null

for (const row of result) {   // a GraphResult is iterable
  console.log(row);
}
```

---

## 8. Neutral Shapes

Every engine returns the same neutral shapes, so a graph read feels identical no matter which engine answered.

`GraphNode` carries `id`, `labels`, and `properties`:

```typescript
node.toDict();   // { id: ..., labels: [...], properties: {...} }
```

`GraphEdge` carries `id`, `type`, `from`, `to`, and `properties`:

```typescript
edge.toDict();   // { id: ..., type: ..., from: ..., to: ..., properties: {...} }
```

`GraphResult` carries `records` and `columns`, exposes `length`, and is iterable.

---

## 9. Failing Loud

A malformed or failing raw statement rejects, never a falsy return. Wrap writes in `try/catch`; read the cause with `getError()`:

```typescript
import { GraphError } from "tina4-nodejs/orm";

try {
  await graph.execute("THIS IS NOT VALID CYPHER");
} catch (e) {
  if (e instanceof GraphError) {
    console.log(graph.getError());   // the engine's cause
  }
}
```

A swallowed graph write is the same silent-data-loss footgun the SQL layer already outlawed. Errors surface.

When you are done with a connection, close it:

```typescript
await graph.close();
```
