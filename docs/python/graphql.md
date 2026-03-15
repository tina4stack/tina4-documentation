# GraphQL
::: tip Hot Tips
- Auto-generate a full GraphQL API from your [ORM classes](orm.md) with a single `schema.from_orm(User)` call
- Zero external dependencies — Tina4 Python ships its own recursive-descent parser and executor
- Register the `/graphql` endpoint in one line
- Supports queries, mutations, variables, fragments, and aliases out of the box
:::

## Quick Start

The fastest way to get a working GraphQL API is to point it at an existing ORM class.

```python
from tina4_python import run_web_server
from tina4_python.GraphQL import GraphQL
from tina4_python.Database import Database
from tina4_python import orm

db = Database("sqlite3:app.db")
orm(db)

from src.orm.User import User

gql = GraphQL()
gql.schema.from_orm(User)
gql.register_route("/graphql")

if __name__ == "__main__":
    run_web_server("0.0.0.0", 7145)
```

That single `from_orm` call creates:

| Generated | Name | Description |
|-----------|------|-------------|
| Type | `User` | Object type with fields from ORM field definitions |
| Query | `user(id: ID)` | Fetch a single record by ID |
| Query | `users(limit: Int, offset: Int)` | Paginated list (default limit 10) |
| Mutation | `createUser(input: UserInput)` | Insert a new record |
| Mutation | `updateUser(id: ID!, input: UserInput)` | Update an existing record |
| Mutation | `deleteUser(id: ID!)` | Delete a record, returns Boolean |

You can now POST to `/graphql` and start querying. A GET request to `/graphql` serves the GraphiQL interactive IDE.

## Setting Up the Endpoint {#endpoint}

`register_route` creates both a `POST /graphql` handler and a `GET /graphql` GraphiQL UI:

```python
gql = GraphQL()

# Default path
gql.register_route("/graphql")

# Custom path
gql.register_route("/api/graphql")
```

If you need more control (authentication, custom context, etc.), wire the route yourself:

```python
from tina4_python.Router import post, noauth
from tina4_python.GraphQL import GraphQL

gql = GraphQL()

@noauth()
@post("/graphql")
async def graphql_endpoint(request, response):
    context = {"user": request.session.get("user")}
    result = gql.handle_request(request.body, context=context)
    return response(result)
```

## Defining a Schema Manually {#manual-schema}

When auto-generation does not fit your needs, build the schema by hand.

### Register a type

```python
from tina4_python.GraphQL import GraphQLSchema

schema = GraphQLSchema()

# Define an OBJECT type with named fields
schema.add_type("Product", {
    "id": "ID",
    "name": "String",
    "price": "Float",
    "inStock": "Boolean",
})
```

### Register a query

```python
schema.add_query("product", {
    "type": "Product",
    "args": {"id": "ID"},
    "resolve": lambda root, args, context: {
        "id": args["id"], "name": "Widget", "price": 9.99, "inStock": True
    },
})
```

### Register a mutation

```python
schema.add_mutation("updateProductPrice", {
    "type": "Product",
    "args": {"id": "ID!", "price": "Float!"},
    "resolve": lambda root, args, context: {
        "id": args["id"], "name": "Widget", "price": args["price"], "inStock": True
    },
})
```

## Auto-Generating Schema from ORM {#from-orm}

Given a Tina4 ORM class, `from_orm()` introspects its field definitions, maps field types to GraphQL scalars, and registers CRUD queries and mutations automatically.

### How it works

1. ORM field definitions (e.g. `StringField()`) become fields on the GraphQL type.
2. Field types are mapped: `IntegerField` → `Int`, `NumericField` → `Float`, `StringField`/`TextField` → `String`.
3. The primary key field is mapped to `ID`.
4. The class name is used as the type name. Lower-case is used for query names.

### Example ORM class

```python
# src/orm/Product.py
from tina4_python import ORM, IntegerField, StringField, NumericField

class Product(ORM):
    id    = IntegerField(primary_key=True, auto_increment=True)
    name  = StringField()
    price = NumericField()
    category_id = IntegerField()
```

### Register it

```python
from tina4_python.GraphQL import GraphQL

gql = GraphQL()
gql.schema.from_orm(Product)
gql.schema.from_orm(Category)

gql.register_route("/graphql")
```

You can call `from_orm` multiple times to register as many ORM classes as you like on the same schema.

### Type mapping reference

| ORM Field Type | GraphQL Type |
|---------------|-------------|
| `IntegerField` | `Int` |
| `NumericField` | `Float` |
| `StringField` | `String` |
| `TextField` | `String` |
| `DateTimeField` | `String` |
| `BlobField` | `String` |
| `JSONBField` | `String` |
| Primary key field | `ID` |

## Writing Queries {#queries}

Send a JSON POST request to your endpoint:

```json
{
  "query": "{ users(limit: 5) { id name email } }"
}
```

### Named query

```graphql
query GetProduct($productId: ID) {
  product(id: $productId) {
    id
    name
    price
  }
}
```

With variables:

```json
{
  "query": "query GetProduct($productId: ID) { product(id: $productId) { id name price } }",
  "variables": { "productId": "42" }
}
```

### Aliases

Request the same field multiple times with different arguments using aliases:

```graphql
{
  first: product(id: "1") { name price }
  second: product(id: "2") { name price }
}
```

## Writing Mutations {#mutations}

Mutations follow the same POST format. Use the `mutation` keyword:

```graphql
mutation {
  createProduct(input: { name: "Gadget", price: 19.99, categoryId: 3 }) {
    id
    name
  }
}
```

Update:

```graphql
mutation {
  updateProduct(id: "42", input: { price: 24.99 }) {
    id
    price
  }
}
```

Delete:

```graphql
mutation {
  deleteProduct(id: "42")
}
```

## Resolvers {#resolvers}

Every query and mutation field needs a `resolve` callable. The signature is:

```python
def resolve(root, args, context):
    ...
```

| Parameter | Description |
|-----------|-------------|
| `root` | The parent value. `None` for root-level fields. |
| `args` | Arguments passed in the query, with variables already resolved. |
| `context` | Whatever you passed as context when calling `execute()` or `handle_request()`. |

For nested fields, the executor resolves automatically by reading dict keys from the parent value. You only need explicit resolvers for root-level queries and mutations.

```python
schema.add_query("topProducts", {
    "type": "[Product]",
    "args": {"limit": "Int"},
    "resolve": lambda root, args, context: Product().select(
        filter="1=1",
        limit=args.get("limit", 5)
    ).records,
})
```

## Variables and Fragments {#variables-fragments}

### Variables

Declare variables in the operation definition and pass their values in the `variables` JSON field:

```graphql
query ListProducts($limit: Int, $offset: Int) {
  products(limit: $limit, offset: $offset) {
    id
    name
  }
}
```

```json
{
  "query": "query ListProducts($limit: Int, $offset: Int) { products(limit: $limit, offset: $offset) { id name } }",
  "variables": { "limit": 10, "offset": 20 }
}
```

### Fragments

Fragments let you reuse field selections across queries:

```graphql
fragment ProductFields on Product {
  id
  name
  price
}

query {
  product(id: "1") {
    ...ProductFields
  }
  products(limit: 3) {
    ...ProductFields
  }
}
```

## Directives {#directives}

The built-in `@skip` and `@include` directives control field inclusion at query time:

```graphql
query ($showEmail: Boolean!) {
  user(id: "1") {
    name
    email @include(if: $showEmail)
    age @skip(if: true)
  }
}
```

## GraphiQL IDE {#graphiql}

A GET request to the GraphQL endpoint serves the GraphiQL interactive IDE, giving you a browser-based query editor with auto-complete and documentation.

```
http://localhost:7145/graphql
```

## Programmatic Usage {#programmatic}

You do not have to use the HTTP endpoint. The `GraphQL` class can be called directly in your code:

```python
from tina4_python.GraphQL import GraphQL

gql = GraphQL()
gql.schema.from_orm(User)

result = gql.execute('{ users(limit: 3) { id name } }')
# result = {"data": {"users": [...]}}
```

Pass variables as the second argument:

```python
result = gql.execute(
    'query ($id: ID) { user(id: $id) { id name } }',
    variables={"id": "42"},
)
```

Pass context (e.g. current user) as the third argument:

```python
result = gql.execute(
    '{ me { name } }',
    context={"user_id": current_user.id},
)
```

## Error Handling {#errors}

Errors are returned in the standard GraphQL `errors` array alongside `data`:

```json
{
  "data": { "user": null },
  "errors": [
    { "message": "Field 'user' not found in query", "path": ["user"] }
  ]
}
```

If the query itself fails to parse, the response will have `data: null` and the parser error in `errors`. Resolver exceptions are captured and returned as errors without crashing the server.

## Full Working Example {#full-example}

```python
# app.py
from tina4_python import run_web_server, orm
from tina4_python.Database import Database
from tina4_python.GraphQL import GraphQL

db = Database("sqlite3:shop.db")
orm(db)

# ORM classes (normally in src/orm/)
from tina4_python import ORM, IntegerField, StringField, NumericField

class Category(ORM):
    id   = IntegerField(primary_key=True, auto_increment=True)
    name = StringField()

class Product(ORM):
    id          = IntegerField(primary_key=True, auto_increment=True)
    name        = StringField()
    price       = NumericField()
    category_id = IntegerField()

# Build GraphQL schema
gql = GraphQL()
gql.schema.from_orm(Category)
gql.schema.from_orm(Product)

# Add a custom query alongside the auto-generated ones
gql.schema.add_query("cheapProducts", {
    "type": "[Product]",
    "args": {"maxPrice": "Float"},
    "resolve": lambda root, args, context: Product().select(
        filter="price <= ?",
        params=[args.get("maxPrice", 10.0)],
    ).records,
})

gql.register_route("/graphql")

if __name__ == "__main__":
    run_web_server("0.0.0.0", 7145)
```

Now you can query:

```graphql
{
  # Auto-generated
  categorys(limit: 100) { id name }

  # Auto-generated
  product(id: "7") { id name price }

  # Custom
  cheapProducts(maxPrice: 5.00) { id name price }
}
```

## Further Reading

- [ORM](orm.md) — the ORM classes that power `from_orm`
- [Basic Routing](basic-routing.md) — how Tina4 routing works under the hood
- [REST API](rest-api.md) — for traditional REST-style endpoints
