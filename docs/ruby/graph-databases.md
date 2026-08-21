# Graph Databases

## 1. Graph, Shaped Like Database

Relational data lives in rows. Relationship-heavy data (knowledge graphs, fraud rings, recommendations, lineage) lives in nodes and edges. Tina4 gives graph engines the same home the relational `Database` layer gives SQL: one URL-selected factory, one portable surface, and an engine driver that loads only when you use it.

Learn `Database`, you already know `GraphDatabase`. `Tina4::GraphDatabase.create("ultipa://...")` parses the scheme, picks the adapter, and connects. Switching engine is a URL change. Nothing about the surface moves when the scheme does; only the raw-query dialect changes.

Tina4 speaks four graph engines: Ultipa (GQL), Neo4j and Memgraph (Cypher, one Bolt adapter for both), and ArangoDB (AQL).

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

| Engine | URL scheme(s) | Default port | Query language | Driver |
|--------|---------------|--------------|----------------|--------|
| Ultipa | `ultipa://`, `ultipas://` | 60061 | GQL | `tina4-ultipa` gem |
| Neo4j | `neo4j://`, `bolt://` | 7687 | Cypher | built in (stdlib socket) |
| Memgraph | `memgraph://` | 7687 | Cypher | built in (stdlib socket) |
| ArangoDB | `arango://`, `arangodb://` | 8529 | AQL | built in (stdlib Net::HTTP) |

Neo4j and Memgraph are Bolt/Cypher wire-compatible, so one adapter serves both. The `...s` schemes (`ultipas://`) select TLS.

### Installing Graph Drivers

The Bolt (Neo4j and Memgraph) and ArangoDB drivers are pure Ruby over stdlib, so they ship with tina4ruby with zero third-party gems. Only Ultipa needs a gem, and it loads only on the first `ultipa://` connection:

```bash
gem install tina4-ultipa
```

Or add `gem "tina4-ultipa"` to your Gemfile. Open an `ultipa://` connection without the gem and the error names the package and the command, never a bare `LoadError`.

### TINA4_GRAPH_CONNECT_TIMEOUT

A connect is bounded, the same way `TINA4_DATABASE_CONNECT_TIMEOUT` bounds a SQL connect:

```bash
TINA4_GRAPH_CONNECT_TIMEOUT=10
```

Seconds a graph connect may block, default 10. Set it to `0` (or less) to wait indefinitely. An unreachable host raises within the bound, naming the host and port, instead of hanging the app with no signal.

---

## 3. Creating a Connection

```ruby
graph = Tina4::GraphDatabase.create("ultipa://localhost:60061/mygraph")
```

`create` reads the scheme, selects the adapter, and connects lazily. Pass credentials when the URL carries none:

```ruby
graph = Tina4::GraphDatabase.create("neo4j://localhost:7687", username: "neo4j", password: "secret")
```

Or build from the environment. `from_env` reads `TINA4_GRAPH_URL` (plus `TINA4_GRAPH_USERNAME` / `TINA4_GRAPH_PASSWORD`) and returns `nil` when the variable is unset:

```ruby
graph = Tina4::GraphDatabase.from_env
```

---

## 4. Nodes

`add_node` creates a vertex and returns a `GraphNode` with a non-nil `id`, its labels, and the stored properties echoed back:

```ruby
alice = graph.add_node("Person", { "name" => "Alice", "age" => 30 })
alice.id          # engine-assigned id
alice.labels      # ["Person"]
alice.properties  # { "name" => "Alice", "age" => 30 }
```

`get_node` round-trips a stored node, and returns `nil` for an id that does not exist (a miss is not an error):

```ruby
person = graph.get_node(alice.id)
missing = graph.get_node("does-not-exist")  # nil
```

`update_node` merges properties, `delete_node` removes the node and its edges:

```ruby
graph.update_node(alice.id, { "age" => 31 })   # merge, verified by re-read
graph.delete_node(alice.id)                      # returns true
graph.get_node(alice.id)                          # nil
```

---

## 5. Edges

`add_edge` links two existing nodes and returns a `GraphEdge` carrying its type and the from/to ids you passed:

```ruby
alice = graph.add_node("Person", { "name" => "Alice" })
bob = graph.add_node("Person", { "name" => "Bob" })

edge = graph.add_edge(alice.id, bob.id, "KNOWS", { "since" => 2020 })
edge.type         # "KNOWS"
edge.from         # alice.id
edge.to           # bob.id
edge.properties   # { "since" => 2020 }
```

---

## 6. Neighbours and Traversal

`neighbors` returns the directly-connected nodes for a direction and optional edge type. Direction is `"out"`, `"in"`, or `"both"`:

```ruby
friends = graph.neighbors(alice.id, direction: "out", edge_type: "KNOWS", limit: 50)
friends.each { |friend| puts friend.properties["name"] }
```

An unmatched filter returns an empty array, not an error.

`traverse` returns the set of nodes reachable within `depth` hops from the start:

```ruby
network = graph.traverse(alice.id, depth: 3, direction: "out", edge_type: "KNOWS")
```

Bounded multi-hop traversal is the portable stand-in for each engine's native path query. The reachable set agrees across all four engines for the same graph.

---

## 7. Raw Queries

The portable core stays small. Anything engine-specific rides the raw pass-through, where `text` is the engine's native language and params are bound (never interpolated):

```ruby
# Ultipa (GQL)
result = graph.query("MATCH (n:Person) WHERE n.age > $min RETURN n.name", { "min" => 25 })

# Neo4j / Memgraph (Cypher)
result = graph.query("MATCH (n:Person) WHERE n.age > $min RETURN n.name AS name", { "min" => 25 })

# ArangoDB (AQL)
result = graph.query("FOR p IN persons FILTER p.age > @min RETURN p.name", { "min" => 25 })
```

`query` runs a read, `execute` runs a write. Both return a `GraphResult` (records + columns), the same shape as the relational `DatabaseResult`:

```ruby
result.records    # array of row hashes
result.columns    # column names
result.to_a       # the records
result.scalar     # first value of the first record, or nil

result.each { |row| p row }   # a GraphResult is Enumerable
```

---

## 8. Neutral Shapes

Every engine returns the same neutral shapes, so a graph read feels identical no matter which engine answered.

`GraphNode` carries `id`, `labels`, and `properties`:

```ruby
node.to_h   # { "id" => ..., "labels" => [...], "properties" => {...} }
```

`GraphEdge` carries `id`, `type`, `from`, `to`, and `properties`:

```ruby
edge.to_h   # { "id" => ..., "type" => ..., "from" => ..., "to" => ..., "properties" => {...} }
```

`GraphResult` carries `records` and `columns`, and mixes in `Enumerable`.

---

## 9. Failing Loud

A malformed or failing raw statement raises, never a falsy return. Wrap writes in `begin/rescue`; read the cause with `get_error`:

```ruby
begin
  graph.execute("THIS IS NOT VALID CYPHER")
rescue Tina4::GraphError
  puts graph.get_error   # the engine's cause
end
```

A swallowed graph write is the same silent-data-loss footgun the SQL layer already outlawed. Errors surface.

When you are done with a connection, close it:

```ruby
graph.close
```
