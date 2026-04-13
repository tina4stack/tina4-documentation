# Chapter 22: GraphQL and SOAP

## 1. The Problem GraphQL Solves

Your mobile app needs a product list. Each product carries a name, price, 20 image URLs, a full description, 15 review objects, and 8 fields you do not need. REST sends all of it -- 50KB of JSON when you needed 2KB. On a mobile connection, that waste stings.

Now your web dashboard needs the same products plus category, stock status, and supplier info. REST forces you to make three requests and stitch them together, or build a custom endpoint with query parameter parsing.

GraphQL ends both problems. The client asks for the fields it needs. The server returns those fields. One endpoint. One request. One response shaped to fit.

Tina4 includes a built-in GraphQL engine. No external gems. No Apollo Server. No graphql-ruby gem. Part of the framework.

---

## 2. GraphQL vs REST -- A Quick Comparison

| Aspect | REST | GraphQL |
|--------|------|---------|
| Endpoints | One per resource (`/products`, `/users`) | One endpoint (`/graphql`) |
| Data shape | Server decides | Client decides |
| Over-fetching | Common (get all fields) | Never (get only requested fields) |
| Under-fetching | Common (multiple requests needed) | Never (get related data in one query) |
| Versioning | `/api/v1/`, `/api/v2/` | Schema evolves, no versioning needed |
| Caching | HTTP caching works naturally | Requires client-side cache management |
| Learning curve | Low | Moderate |

REST is still great for simple APIs. GraphQL shines when clients have diverse data needs -- mobile apps, dashboards, third-party integrations.

---

## 3. Enabling GraphQL

GraphQL is available by default in Tina4. Set up a schema and register the route in `src/routes/graphql.rb`:

```ruby
schema = Tina4::GraphQLSchema.new
gql = Tina4::GraphQL.new(schema)
gql.register_route  # POST /graphql, GET /graphql (playground)
```

To change the endpoint path:

```ruby
gql.register_route("/api/graphql")
```

To verify it is working, start the server and send a test query:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { queryType { name } } }"}'
```

```json
{
  "data": {
    "__schema": {
      "queryType": {
        "name": "Query"
      }
    }
  }
}
```

If you see that response, GraphQL is running.

---

## 4. Defining Queries

Register queries on a `GraphQLSchema` instance. Each query has a name, return type, optional arguments, and a resolver block. The block receives three arguments: `root` (parent value), `args` (query arguments), and `ctx` (context hash).

Create `src/routes/graphql.rb`:

```ruby
schema = Tina4::GraphQLSchema.new

# List all products
schema.add_query("products", type: "[Product]") do |root, args, ctx|
  db = Tina4.database
  products = db.fetch("SELECT * FROM products ORDER BY name")
  products
end

# Get a single product by ID
schema.add_query("product", type: "Product",
                 args: { "id" => { type: "Int!" } }) do |root, args, ctx|
  db = Tina4.database
  db.fetch_one("SELECT * FROM products WHERE id = ?", [args["id"].to_i])
end

gql = Tina4::GraphQL.new(schema)
gql.register_route
```

### Testing the Queries

List all products:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ products { id name price inStock } }"}'
```

```json
{
  "data": {
    "products": [
      {"id": 1, "name": "Wireless Keyboard", "price": 79.99, "inStock": true},
      {"id": 2, "name": "USB-C Hub", "price": 49.99, "inStock": true},
      {"id": 3, "name": "Standing Desk", "price": 549.99, "inStock": false}
    ]
  }
}
```

The response contains only the four fields you asked for (`id`, `name`, `price`, `inStock`), not `category` or `createdAt`. That is GraphQL in action.

Get a single product with all fields:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ product(id: 1) { id name category price inStock createdAt } }"}'
```

```json
{
  "data": {
    "product": {
      "id": 1,
      "name": "Wireless Keyboard",
      "category": "Electronics",
      "price": 79.99,
      "inStock": true,
      "createdAt": "2026-03-22 14:30:00"
    }
  }
}
```

Request a product that does not exist:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ product(id: 999) { id name } }"}'
```

```json
{
  "data": {
    "product": null
  }
}
```

---

## 5. Mutations

Mutations are how clients create, update, or delete data. Register them with `add_mutation` on the schema.

```ruby
schema.add_mutation("createProduct", type: "Product",
                    args: {
                      "name"     => { type: "String!" },
                      "category" => { type: "String" },
                      "price"    => { type: "Float!" },
                      "inStock"  => { type: "Boolean" }
                    }) do |root, args, ctx|
  db = Tina4.database

  db.execute(
    "INSERT INTO products (name, category, price, in_stock) VALUES (:name, :category, :price, :in_stock)",
    {
      name: args["name"],
      category: args["category"] || "Uncategorized",
      price: args["price"].to_f,
      in_stock: args["inStock"] ? 1 : 0
    }
  )

  db.fetch_one("SELECT * FROM products WHERE id = last_insert_rowid()")
end

schema.add_mutation("updateProduct", type: "Product",
                    args: {
                      "id"       => { type: "Int!" },
                      "name"     => { type: "String" },
                      "category" => { type: "String" },
                      "price"    => { type: "Float" },
                      "inStock"  => { type: "Boolean" }
                    }) do |root, args, ctx|
  db = Tina4.database
  id = args["id"].to_i

  sets = []
  params = []

  if args.key?("name")
    sets << "name = ?"
    params << args["name"]
  end
  if args.key?("category")
    sets << "category = ?"
    params << args["category"]
  end
  if args.key?("price")
    sets << "price = ?"
    params << args["price"].to_f
  end
  if args.key?("inStock")
    sets << "in_stock = ?"
    params << (args["inStock"] ? 1 : 0)
  end

  unless sets.empty?
    params << id
    db.execute("UPDATE products SET #{sets.join(', ')} WHERE id = ?", params)
  end

  db.fetch_one("SELECT * FROM products WHERE id = ?", [id])
end

schema.add_mutation("deleteProduct", type: "Boolean",
                    args: { "id" => { type: "Int!" } }) do |root, args, ctx|
  db = Tina4.database
  id = args["id"].to_i
  db.execute("DELETE FROM products WHERE id = ?", [id])
  true
end
```

### Testing Mutations

Create a product:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createProduct(name: \"Desk Lamp\", category: \"Office\", price: 39.99) { id name price } }"
  }'
```

```json
{
  "data": {
    "createProduct": {
      "id": 4,
      "name": "Desk Lamp",
      "price": 39.99
    }
  }
}
```

Update a product:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { updateProduct(id: 4, price: 44.99, inStock: false) { id name price inStock } }"
  }'
```

```json
{
  "data": {
    "updateProduct": {
      "id": 4,
      "name": "Desk Lamp",
      "price": 44.99,
      "inStock": false
    }
  }
}
```

Delete a product:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { deleteProduct(id: 4) }"
  }'
```

```json
{
  "data": {
    "deleteProduct": true
  }
}
```

---

## 6. Nested Types and Relationships

The real power of GraphQL: traversing relationships in a single query. Authors, posts, comments -- all in one request.

```ruby
schema.add_query("posts", type: "[Post]") do |root, args, ctx|
  db = Tina4.database
  posts = db.fetch("SELECT * FROM posts WHERE published = 1 ORDER BY created_at DESC")

  posts.each do |post|
    post["author"] = db.fetch_one(
      "SELECT id, name, email FROM users WHERE id = ?",
      [post["user_id"]]
    )
    post["comments"] = db.fetch(
      "SELECT * FROM comments WHERE post_id = ? ORDER BY created_at",
      [post["id"]]
    )
    post["commentCount"] = post["comments"].length
  end

  posts
end

schema.add_query("post", type: "Post",
                 args: { "id" => { type: "Int!" } }) do |root, args, ctx|
  db = Tina4.database
  post = db.fetch_one("SELECT * FROM posts WHERE id = ?", [args["id"].to_i])

  return nil if post.nil?

  post["author"] = db.fetch_one(
    "SELECT id, name, email FROM users WHERE id = ?",
    [post["user_id"]]
  )
  post["comments"] = db.fetch(
    "SELECT * FROM comments WHERE post_id = ? ORDER BY created_at",
    [post["id"]]
  )
  post["commentCount"] = post["comments"].length

  post
end

schema.add_query("user", type: "User",
                 args: { "id" => { type: "Int!" } }) do |root, args, ctx|
  db = Tina4.database
  user = db.fetch_one("SELECT id, name, email FROM users WHERE id = ?", [args["id"].to_i])

  return nil if user.nil?

  user["posts"] = db.fetch(
    "SELECT id, title FROM posts WHERE user_id = ?",
    [user["id"]]
  )

  user
end
```

Now clients can query across relationships in a single request:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ posts { id title author { name email } comments { authorName body } commentCount } }"
  }'
```

```json
{
  "data": {
    "posts": [
      {
        "id": 1,
        "title": "My First Post",
        "author": {
          "name": "Alice",
          "email": "alice@example.com"
        },
        "comments": [
          {"authorName": "Bob", "body": "Great post!"}
        ],
        "commentCount": 1
      }
    ]
  }
}
```

One request. The fields the client needs. No over-fetching. No under-fetching.

---

## 7. Auto-Generating Schema from ORM Models

If your ORM models exist, Tina4 can auto-generate GraphQL types and CRUD resolvers from them. Call `from_orm` on the schema:

```ruby
schema = Tina4::GraphQLSchema.new
schema.from_orm(Product)
schema.from_orm(User)

gql = Tina4::GraphQL.new(schema)
gql.register_route
```

With `from_orm`, each model gets:

- A GraphQL type with fields matching the model properties
- A query to list all records (e.g., `products(limit: Int, offset: Int)`)
- A query to get one by ID (e.g., `product(id: ID!)`)
- A mutation to create (e.g., `createProduct(input: ProductInput!)`)
- A mutation to update (e.g., `updateProduct(id: ID!, input: ProductInput!)`)
- A mutation to delete (e.g., `deleteProduct(id: ID!)`)

The `from_orm` method reads field definitions from your model class. It maps Ruby types to GraphQL types:

| Ruby field type | GraphQL type |
|-----------------|--------------|
| `:integer`, `:int` | `Int` |
| `:float`, `:double`, `:decimal` | `Float` |
| `:boolean`, `:bool` | `Boolean` |
| `:string`, `:text`, `:varchar` | `String` |
| `:datetime`, `:date`, `:timestamp` | `String` |

You can still add custom queries and mutations alongside auto-generated ones. Custom resolvers always take precedence over auto-generated ones.

### Example: ORM + Custom Queries

```ruby
schema = Tina4::GraphQLSchema.new

# Auto-generate CRUD for Product
schema.from_orm(Product)

# Add a custom query that filters by category
schema.add_query("productsByCategory", type: "[Product]",
                 args: { "category" => { type: "String!" } }) do |root, args, ctx|
  products, count = Product.where("category = ?", [args["category"]])
  products.map(&:to_hash)
end

gql = Tina4::GraphQL.new(schema)
gql.register_route
```

---

## 8. Authentication in GraphQL

The resolver block receives a `ctx` hash that includes the current request. Use it to check authentication:

```ruby
schema.add_query("me", type: "User") do |root, args, ctx|
  request = ctx[:request]

  if request.nil? || request.headers["Authorization"].nil?
    raise "Authentication required"
  end

  token = request.headers["Authorization"].sub("Bearer ", "")
  payload = Tina4::Auth.decode(token)

  raise "Invalid token" if payload.nil?

  db = Tina4.database
  db.fetch_one("SELECT id, name, email, role FROM users WHERE id = ?", [payload["user_id"]])
end
```

The `ctx` hash is populated by `register_route`, which passes `{ request: request }` to every resolver.

---

## 9. The GraphiQL Playground

When you call `register_route`, Tina4 serves a GraphiQL interactive playground at the same endpoint via GET:

```
http://localhost:7147/graphql
```

GraphiQL gives you:

- A query editor with syntax highlighting and auto-completion
- A documentation explorer showing all types, queries, and mutations
- A results panel showing the response
- Query history

Type a query on the left, click the play button, and see the results on the right. The documentation explorer on the right sidebar shows every type, field, and argument available in your schema.

In production, disable the playground by using a custom route instead of `register_route`:

```ruby
Tina4.post "/graphql", auth: false do |request, response|
  result = gql.handle_request(request.body, context: { request: request })
  response.json(result)
end
```

---

## 10. Query Variables

For production use, clients should send query variables separately from the query string. This prevents injection and allows query caching.

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query GetProduct($id: Int!) { product(id: $id) { id name price } }",
    "variables": {"id": 1}
  }'
```

```json
{
  "data": {
    "product": {
      "id": 1,
      "name": "Wireless Keyboard",
      "price": 79.99
    }
  }
}
```

The query uses `$id` as a placeholder. The actual value comes from the `variables` object. This is safer and more efficient than string interpolation.

Variable definitions sit in the operation signature:

```graphql
query GetProduct($id: Int!) {
  product(id: $id) {
    id
    name
    price
  }
}
```

The `$id: Int!` declaration tells GraphQL the variable name, type, and that it is required (the `!`). The executor substitutes `$id` with the value from the `variables` hash before calling the resolver.

You can define multiple variables:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query Search($category: String!, $limit: Int) { productsByCategory(category: $category, limit: $limit) { id name price } }",
    "variables": {"category": "Electronics", "limit": 10}
  }'
```

---

## 11. Exercise: Build a GraphQL API for a Blog

Build a complete GraphQL API for a blog with posts, authors, and comments.

### Requirements

1. **Schema** -- Define queries and mutations for `User`, `Post`, and `Comment` with these fields:

   - `User`: id, name, email, posts (nested)
   - `Post`: id, title, body, published, author (nested), comments (nested), commentCount (computed)
   - `Comment`: id, authorName, body, createdAt

2. **Queries**:
   - `posts` -- List all published posts
   - `post(id: Int!)` -- Get a single post by ID
   - `user(id: Int!)` -- Get a user with their posts

3. **Mutations**:
   - `createPost(userId: Int!, title: String!, body: String!, published: Boolean)` -- Create a new post
   - `addComment(postId: Int!, authorName: String!, body: String!)` -- Add a comment to a post

4. Use the ORM models from Chapter 6 (User, Post, Comment).

### Test with these queries:

```bash
# List published posts with author names
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ posts { id title author { name } commentCount } }"}'

# Get a specific post with all comments
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ post(id: 1) { title body author { name email } comments { authorName body } } }"}'

# Create a post
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createPost(userId: 1, title: \"GraphQL is great\", body: \"Here is why...\", published: true) { id title } }"}'

# Add a comment
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { addComment(postId: 1, authorName: \"Carol\", body: \"Nice article!\") { id authorName } }"}'
```

---

## 12. Solution

Create `src/routes/graphql_blog.rb`:

```ruby
schema = Tina4::GraphQLSchema.new

# ── Queries ──

schema.add_query("posts", type: "[Post]") do |root, args, ctx|
  db = Tina4.database
  posts = db.fetch("SELECT * FROM posts WHERE published = 1 ORDER BY created_at DESC")

  posts.each do |post|
    post["author"] = db.fetch_one(
      "SELECT id, name, email FROM users WHERE id = ?",
      [post["user_id"]]
    )
    post["comments"] = db.fetch(
      "SELECT * FROM comments WHERE post_id = ? ORDER BY created_at",
      [post["id"]]
    )
    post["commentCount"] = post["comments"].length
  end

  posts
end

schema.add_query("post", type: "Post",
                 args: { "id" => { type: "Int!" } }) do |root, args, ctx|
  db = Tina4.database
  post = db.fetch_one("SELECT * FROM posts WHERE id = ?", [args["id"].to_i])

  return nil if post.nil?

  post["author"] = db.fetch_one(
    "SELECT id, name, email FROM users WHERE id = ?",
    [post["user_id"]]
  )
  post["comments"] = db.fetch(
    "SELECT * FROM comments WHERE post_id = ? ORDER BY created_at",
    [post["id"]]
  )
  post["commentCount"] = post["comments"].length

  post
end

schema.add_query("user", type: "User",
                 args: { "id" => { type: "Int!" } }) do |root, args, ctx|
  db = Tina4.database
  user = db.fetch_one(
    "SELECT id, name, email FROM users WHERE id = ?",
    [args["id"].to_i]
  )

  return nil if user.nil?

  user["posts"] = db.fetch(
    "SELECT id, title FROM posts WHERE user_id = ?",
    [user["id"]]
  )

  user
end

# ── Mutations ──

schema.add_mutation("createPost", type: "Post",
                    args: {
                      "userId"    => { type: "Int!" },
                      "title"     => { type: "String!" },
                      "body"      => { type: "String!" },
                      "published" => { type: "Boolean" }
                    }) do |root, args, ctx|
  db = Tina4.database

  user = db.fetch_one("SELECT id FROM users WHERE id = ?", [args["userId"].to_i])
  raise "User not found" if user.nil?

  db.execute(
    "INSERT INTO posts (user_id, title, body, published) VALUES (:user_id, :title, :body, :published)",
    {
      user_id: args["userId"].to_i,
      title: args["title"],
      body: args["body"],
      published: args["published"] ? 1 : 0
    }
  )

  db.fetch_one("SELECT * FROM posts WHERE id = last_insert_rowid()")
end

schema.add_mutation("addComment", type: "Comment",
                    args: {
                      "postId"     => { type: "Int!" },
                      "authorName" => { type: "String!" },
                      "body"       => { type: "String!" }
                    }) do |root, args, ctx|
  db = Tina4.database

  post = db.fetch_one("SELECT id FROM posts WHERE id = ?", [args["postId"].to_i])
  raise "Post not found" if post.nil?

  db.execute(
    "INSERT INTO comments (post_id, author_name, body) VALUES (:post_id, :author_name, :body)",
    {
      post_id: args["postId"].to_i,
      author_name: args["authorName"],
      body: args["body"]
    }
  )

  db.fetch_one("SELECT * FROM comments WHERE id = last_insert_rowid()")
end

gql = Tina4::GraphQL.new(schema)
gql.register_route
```

**Expected output for `{ posts { id title author { name } commentCount } }`:**

```json
{
  "data": {
    "posts": [
      {
        "id": 1,
        "title": "My First Post",
        "author": {"name": "Alice"},
        "commentCount": 1
      },
      {
        "id": 2,
        "title": "GraphQL is great",
        "author": {"name": "Alice"},
        "commentCount": 0
      }
    ]
  }
}
```

---

## 13. Input Validation

Tina4's GraphQL engine validates every argument against its declared type before your resolver runs. You never need to check whether a required argument is present or whether a string arrived where an integer was expected -- the engine rejects the query before your code executes.

The built-in validator covers:

- **Non-null enforcement** -- Arguments marked with `!` must be present and non-null.
- **Scalar type checking** -- `Int`, `Float`, `String`, `Boolean`, and `ID` values are verified against their declared type.
- **Type coercion** -- When safe, the engine coerces compatible values automatically (e.g., an integer `42` passed to a `Float` field becomes `42.0`, or a string `"7"` passed to an `Int` field becomes `7`).
- **List item validation** -- For `[Int!]!` arguments, the engine checks that the value is a list, that no item is null, and that every item is an integer.

### Example: Missing Required Argument

Suppose you define a query that requires an `id`:

```ruby
schema.add_query("user", type: "User",
                 args: { "id" => { type: "ID!" } }) do |root, args, ctx|
  db = Tina4.database
  db.fetch_one("SELECT * FROM users WHERE id = ?", [args["id"].to_i])
end
```

Sending a query without the required argument:

```graphql
{
  user {
    name
    email
  }
}
```

Returns an error before the resolver runs:

```json
{
  "errors": [
    {
      "message": "Argument 'id' of type 'ID!' is required but not provided.",
      "locations": [{"line": 2, "column": 3}]
    }
  ]
}
```

Your resolver never executes. No nil-check needed inside the block.

---

## 14. Field-Level Auth Directives

Tina4 supports three directives that control field-level access in your GraphQL schema:

| Directive | Effect |
|-----------|--------|
| `@auth` | Field resolves only when `ctx["user"]` is present (any authenticated user) |
| `@role(role: "admin")` | Field resolves only when `ctx["user"]["role"]` matches the specified role |
| `@guest` | Field resolves only when `ctx["user"]` is absent (unauthenticated visitors) |

### Passing Auth Context

Pass user information through the context parameter of `execute()`:

```ruby
result = gql.execute(query, variables: {}, context: {
  "user" => { "id" => 1, "role" => "admin" }
})
```

When no user is logged in, pass an empty context or omit the `user` key:

```ruby
result = gql.execute(query, variables: {}, context: {})
```

### Schema Example

```graphql
type User {
    id: ID!
    name: String!
    email: String! @auth
    role: String! @role(role: "admin")
}

type Query {
    me: User @auth
    publicStats: Stats @guest
    users: [User!]! @role(role: "admin")
}
```

### Behavior on Failed Auth

When a directive check fails, the field resolves to `null` silently -- no error is added to the response. The rest of the query executes normally. This prevents leaking information about which fields exist behind authentication.

For example, if a non-admin user queries:

```graphql
{
  users {
    name
    email
    role
  }
}
```

The response is:

```json
{
  "data": {
    "users": null
  }
}
```

No error message. No hint that the field requires admin access. The field is simply excluded.

---

## 15. Gotchas

### 1. Resolver Not Called

**Problem:** A query returns `null` even though data exists.

**Cause:** The query name in `add_query` does not match the name the client sends. GraphQL is case-sensitive.

**Fix:** Verify that `schema.add_query("products", ...)` matches `{ products { ... } }` in the client query. Check capitalization.

### 2. Nested Data Returns Wrong Shape

**Problem:** `post.author` returns the entire post hash instead of the user.

**Cause:** You attached the nested data to a key that does not match the field name the client requests.

**Fix:** Use the exact field name the client will query. If the client sends `{ post { author { name } } }`, the hash must have an `"author"` key:

```ruby
post["author"] = db.fetch_one("SELECT id, name FROM users WHERE id = ?", [post["user_id"]])
```

### 3. Mutation Returns Null

**Problem:** A mutation executes but returns null.

**Cause:** `db.execute` returns affected row count, not the data. Your mutation block ends with `db.execute`, so the block returns an integer.

**Fix:** Follow every `db.execute` with a `db.fetch_one` to return the actual record:

```ruby
db.execute("INSERT INTO products ...")
db.fetch_one("SELECT * FROM products WHERE id = last_insert_rowid()")
```

### 4. N+1 Query Problem

**Problem:** Loading 50 posts with their authors generates 51 database queries (1 for posts + 50 for authors).

**Cause:** Each nested lookup runs inside a loop. When you resolve `author` for each post, that is one query per post.

**Fix:** Pre-fetch all related records in the parent resolver. Check `ctx["__selections"]` to see which nested fields the client requested -- if `author` is not in the selection set, skip the join. For ORM queries, use the `include` parameter to eager-load relationships in a single query. For manual queries, load all relevant users in one query, build a hash by ID, and attach them:

```ruby
schema.add_query("posts", type: "[Post]") do |root, args, ctx|
  db = Tina4.database
  posts = db.fetch("SELECT * FROM posts ORDER BY created_at DESC")

  user_ids = posts.map { |p| p["user_id"] }.uniq
  users = db.fetch("SELECT * FROM users WHERE id IN (#{user_ids.join(',')})")
  user_map = users.each_with_object({}) { |u, h| h[u["id"]] = u }

  posts.each { |p| p["author"] = user_map[p["user_id"]] }
  posts
end
```

### 5. GraphQL Playground Returns 404

**Problem:** Visiting `/graphql` in the browser returns a 404.

**Cause:** You did not call `register_route`, or you registered a POST-only route manually.

**Fix:** Call `gql.register_route` which registers both POST (for queries) and GET (for the GraphiQL playground).

### 6. Type Mismatch Between Schema and Data

**Problem:** A field declared as `Int` receives a string from the database, causing unexpected results.

**Cause:** SQLite returns all values as strings. Your resolver passes them through without conversion.

**Fix:** The input validation layer (see section 13) now coerces compatible types automatically -- a string `"42"` passed as an argument to an `Int` parameter is converted before your resolver runs. However, resolver *return values* still need correct types. Cast values explicitly:

```ruby
{
  "id" => record["id"].to_i,
  "price" => record["price"].to_f,
  "inStock" => record["in_stock"] == 1
}
```

The `to_hash` method on ORM models handles this for model properties with type declarations. Raw database hashes need manual casting.

### 7. Authentication Not Applied

**Problem:** GraphQL queries work without authentication.

**Cause:** `register_route` sets `auth: false` by default. No middleware checks the token.

**Fix:** Check `ctx[:request]` in resolvers that need authentication. Or register a custom POST route with `auth: true` and let your auth middleware run first:

```ruby
Tina4.post "/graphql", auth: true do |request, response|
  result = gql.handle_request(request.body, context: { request: request })
  response.json(result)
end
```

### 8. Error Messages Expose Internal Details

**Problem:** Database error messages appear in GraphQL responses.

**Cause:** Exceptions raised in resolvers become error messages in the response.

**Fix:** Wrap resolver logic in `begin/rescue` and return clean error messages:

```ruby
schema.add_query("product", type: "Product",
                 args: { "id" => { type: "Int!" } }) do |root, args, ctx|
  begin
    db = Tina4.database
    db.fetch_one("SELECT * FROM products WHERE id = ?", [args["id"].to_i])
  rescue => e
    raise "Product not found"
  end
end
```

---

## 14. SOAP / WSDL Services

### What is SOAP?

SOAP (Simple Object Access Protocol) is an XML-based messaging protocol for exchanging structured data between systems. It predates REST and GraphQL, but remains common in enterprise integrations -- banking, healthcare, government, and ERP systems all rely on SOAP services.

A WSDL (Web Services Description Language) file describes a SOAP service: what operations are available, what parameters they accept, and what they return. Clients use the WSDL to auto-generate code for calling the service.

Tina4 includes a zero-dependency SOAP 1.1 server that generates WSDL definitions from Ruby classes and type annotations. No XML authoring required. It uses REXML (part of Ruby's standard library) for XML parsing.

---

### Defining a SOAP Service

Create a class that extends `Tina4::WSDL`. Mark each method with `wsdl_operation` before the `def`. The `output` hash describes the response fields and their types.

```ruby
class Calculator < Tina4::WSDL
  wsdl_operation output: { Result: :int }
  def add(a, b)
    { Result: a.to_i + b.to_i }
  end

  wsdl_operation output: { Result: :int }
  def multiply(a, b)
    { Result: a.to_i * b.to_i }
  end
end

Tina4::Router.get("/calculator") do |request, response|
  service = Calculator.new(request)
  response.call(service.handle)
end

Tina4::Router.post("/calculator") do |request, response|
  service = Calculator.new(request)
  response.call(service.handle)
end
```

That is the entire service. The `handle` method inspects the request:

- **GET** (or `?wsdl` query parameter) -- returns the auto-generated WSDL definition
- **POST** with SOAP XML body -- parses the XML, finds the operation, converts parameters, calls the method, and returns a SOAP XML response

### Type Annotations Map to XSD

The `output` hash maps response element names to Ruby type symbols. Input parameter types default to `:string` and are converted based on the output type declarations.

| Ruby type | XSD type |
|-----------|----------|
| `:string`, `String` | `xsd:string` |
| `:int`, `:integer`, `Integer` | `xsd:int` |
| `:float`, `:double`, `Float` | `xsd:double` |
| `:boolean`, `:bool` | `xsd:boolean` |
| `:date` | `xsd:date` |
| `:datetime` | `xsd:dateTime` |
| `:base64` | `xsd:base64Binary` |

### A More Complete Example

```ruby
class UserService < Tina4::WSDL
  wsdl_operation output: { Name: :string, Email: :string, Active: :boolean }
  def get_user(user_id)
    user = User.find(user_id.to_i)
    if user
      {
        Name: user.name,
        Email: user.email,
        Active: user.active == 1
      }
    else
      { Name: "", Email: "", Active: false }
    end
  end

  wsdl_operation output: { Total: :int, Average: :float }
  def sum_list(numbers)
    nums = numbers.split(",").map(&:to_i)
    {
      Total: nums.sum,
      Average: nums.sum.to_f / nums.length
    }
  end
end

Tina4::Router.get("/api/users/soap") do |request, response|
  service = UserService.new(request)
  response.call(service.handle)
end

Tina4::Router.post("/api/users/soap") do |request, response|
  service = UserService.new(request)
  response.call(service.handle)
end
```

### Lifecycle Hooks

Override `on_request` and `on_result` to add validation, logging, or transformation around every operation call.

```ruby
class AuditedService < Tina4::WSDL
  def on_request(request)
    puts "SOAP request from #{request.headers['x-forwarded-for'] || 'unknown'}"
  end

  def on_result(result)
    result[:Timestamp] = Time.now.iso8601
    result
  end

  wsdl_operation output: { Status: :string, Timestamp: :string }
  def ping
    { Status: "ok" }
  end
end
```

### Testing with curl

Fetch the WSDL definition:

```bash
curl http://localhost:7147/calculator?wsdl
```

Call the add operation with a SOAP request:

```bash
curl -X POST http://localhost:7147/calculator \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <add>
      <a>5</a>
      <b>3</b>
    </add>
  </soap:Body>
</soap:Envelope>'
```

Response:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
<addResponse>
<Result>8</Result>
</addResponse>
</soap:Body>
</soap:Envelope>
```

If the operation name is wrong or the XML is malformed, the service returns a SOAP fault:

```xml
<soap:Fault>
  <faultcode>Client</faultcode>
  <faultstring>Unknown operation: subtract</faultstring>
</soap:Fault>
```

### When to Use SOAP vs REST vs GraphQL

| Scenario | Use |
|----------|-----|
| New API for web/mobile clients | REST or GraphQL |
| Integrating with legacy enterprise systems (SAP, banks, government) | SOAP |
| Clients require a machine-readable service contract | SOAP (WSDL) |
| Simple internal microservices | REST |
| Clients with diverse data needs | GraphQL |

SOAP is rarely the right choice for new APIs. When you need to expose a service that legacy systems can consume, Tina4 makes it straightforward -- define a class, annotate your types, and the framework handles the XML.
