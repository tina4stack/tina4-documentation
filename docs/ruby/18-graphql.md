# Chapter 16: GraphQL

## 1. The Problem GraphQL Solves

Your mobile app needs a product list. Each product carries a name, price, 20 image URLs, a full description, 15 review objects, and 8 other fields you do not need. REST sends all of it. 50KB of JSON when 2KB would do. On a spotty mobile connection, that waste hurts.

Your web dashboard needs the same products but also wants category, stock status, and supplier info. REST forces three requests (products, categories, suppliers) stitched together on the client. Or a custom endpoint.

GraphQL kills both problems. The client asks for the fields it needs. The server returns those fields. One endpoint. One request. One response shaped to fit.

Tina4 includes a built-in GraphQL engine. No external packages. No Apollo Server. It is part of the framework.

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

---

## 3. Enabling GraphQL

GraphQL is available by default in Tina4. The engine serves requests at `/graphql`:

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

---

## 4. Defining a Schema

Create your GraphQL schema in `src/routes/graphql.rb`:

```ruby
Tina4::GraphQL.query("products") do |args|
  db = Tina4.database
  products = db.fetch("SELECT * FROM products ORDER BY name")
  products
end

Tina4::GraphQL.query("product") do |args|
  db = Tina4.database
  db.fetch_one("SELECT * FROM products WHERE id = ?", [args["id"].to_i])
end

Tina4::GraphQL.query("users") do |args|
  db = Tina4.database
  db.fetch("SELECT id, name, email, role FROM users ORDER BY name")
end
```

### Querying

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ products { id name price } }"}'
```

```json
{
  "data": {
    "products": [
      {"id": 1, "name": "Wireless Keyboard", "price": 79.99},
      {"id": 2, "name": "USB-C Hub", "price": 49.99}
    ]
  }
}
```

The client asked for `id`, `name`, and `price` only. The response contains exactly those fields -- no `category`, no `in_stock`, no `created_at`.

---

## 5. Query Arguments

```ruby
Tina4::GraphQL.query("product") do |args|
  db = Tina4.database
  db.fetch_one("SELECT * FROM products WHERE id = ?", [args["id"].to_i])
end
```

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ product(id: 1) { name price category } }"}'
```

```json
{
  "data": {
    "product": {
      "name": "Wireless Keyboard",
      "price": 79.99,
      "category": "Electronics"
    }
  }
}
```

---

## 6. Mutations

Mutations are write operations. Define them with `Tina4::GraphQL.mutation`:

```ruby
Tina4::GraphQL.mutation("createProduct") do |args|
  db = Tina4.database

  db.execute(
    "INSERT INTO products (name, category, price) VALUES (:name, :category, :price)",
    { name: args["name"], category: args["category"] || "Uncategorized", price: args["price"].to_f }
  )

  db.fetch_one("SELECT * FROM products WHERE id = last_insert_rowid()")
end

Tina4::GraphQL.mutation("updateProduct") do |args|
  db = Tina4.database
  id = args["id"].to_i

  db.execute(
    "UPDATE products SET name = ?, price = ? WHERE id = ?",
    [args["name"], args["price"].to_f, id]
  )

  db.fetch_one("SELECT * FROM products WHERE id = ?", [id])
end

Tina4::GraphQL.mutation("deleteProduct") do |args|
  db = Tina4.database
  id = args["id"].to_i

  db.execute("DELETE FROM products WHERE id = ?", [id])

  { deleted: true, id: id }
end
```

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createProduct(name: \"Widget\", price: 9.99) { id name price } }"}'
```

```json
{
  "data": {
    "createProduct": {
      "id": 6,
      "name": "Widget",
      "price": 9.99
    }
  }
}
```

---

## 7. Nested Queries (Relationships)

```ruby
Tina4::GraphQL.query("users") do |args|
  db = Tina4.database
  users = db.fetch("SELECT id, name, email FROM users ORDER BY name")

  users.each do |user|
    user["posts"] = db.fetch("SELECT id, title FROM posts WHERE user_id = ?", [user["id"]])
  end

  users
end
```

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ users { name email posts { title } } }"}'
```

```json
{
  "data": {
    "users": [
      {
        "name": "Alice",
        "email": "alice@example.com",
        "posts": [
          {"title": "First Post"},
          {"title": "Second Post"}
        ]
      }
    ]
  }
}
```

---

## 8. Authentication in GraphQL

```ruby
Tina4::GraphQL.query("me") do |args, context|
  if context[:user].nil?
    raise "Authentication required"
  end

  db = Tina4.database
  db.fetch_one("SELECT id, name, email, role FROM users WHERE id = ?", [context[:user]["user_id"]])
end
```

The `context` hash is populated by middleware that validates the JWT token.

---

## 9. GraphQL Playground

When `TINA4_DEBUG=true`, visit `/graphql/playground` for an interactive GraphQL IDE where you can:

- Write and execute queries
- Browse the schema documentation
- See auto-completion suggestions
- View query history

---

## 10. Exercise: Build a GraphQL API for a Blog

### Requirements

1. Define queries: `posts` (list all), `post(id)` (get one with comments)
2. Define mutations: `createPost`, `addComment`
3. Include nested data (post with author and comments)

### Test with:

```bash
curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ posts { id title user { name } } }"}'

curl -X POST http://localhost:7147/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createPost(title: \"Hello\", body: \"World\", userId: 1) { id title } }"}'
```

---

## 11. Solution

Create `src/routes/graphql_blog.rb`:

```ruby
Tina4::GraphQL.query("posts") do |args|
  db = Tina4.database
  posts = db.fetch("SELECT * FROM posts WHERE published = 1 ORDER BY created_at DESC")

  posts.each do |post|
    post["user"] = db.fetch_one("SELECT id, name, email FROM users WHERE id = ?", [post["user_id"]])
  end

  posts
end

Tina4::GraphQL.query("post") do |args|
  db = Tina4.database
  post = db.fetch_one("SELECT * FROM posts WHERE id = ?", [args["id"].to_i])

  return nil if post.nil?

  post["user"] = db.fetch_one("SELECT id, name, email FROM users WHERE id = ?", [post["user_id"]])
  post["comments"] = db.fetch("SELECT * FROM comments WHERE post_id = ? ORDER BY created_at", [post["id"]])

  post
end

Tina4::GraphQL.mutation("createPost") do |args|
  db = Tina4.database

  db.execute(
    "INSERT INTO posts (user_id, title, body, published) VALUES (:user_id, :title, :body, :published)",
    { user_id: args["userId"].to_i, title: args["title"], body: args["body"], published: args["published"] ? 1 : 0 }
  )

  db.fetch_one("SELECT * FROM posts WHERE id = last_insert_rowid()")
end

Tina4::GraphQL.mutation("addComment") do |args|
  db = Tina4.database

  db.execute(
    "INSERT INTO comments (post_id, author_name, body) VALUES (:post_id, :author_name, :body)",
    { post_id: args["postId"].to_i, author_name: args["authorName"], body: args["body"] }
  )

  db.fetch_one("SELECT * FROM comments WHERE id = last_insert_rowid()")
end
```

---

## 12. Gotchas

### 1. N+1 Queries in Nested Resolvers

**Problem:** Fetching 100 posts with their authors makes 101 database queries.

**Fix:** Use batch loading or pre-fetch all authors in one query before resolving.

### 2. All Fields Returned Despite Client Selection

**Problem:** The response includes fields the client did not ask for.

**Fix:** Tina4's GraphQL engine handles field selection automatically. If all fields appear, ensure you are using the GraphQL endpoint, not a REST endpoint.

### 3. Mutations Return Null

**Problem:** A mutation executes but returns null.

**Fix:** Make sure your mutation block returns the created/updated object. `db.execute` returns affected rows, not the data. Follow it with a `db.fetch_one` to return the actual record.

### 4. Authentication Not Applied

**Problem:** GraphQL queries work without authentication.

**Fix:** Apply auth middleware to the `/graphql` endpoint, or check `context[:user]` in resolvers.

### 5. Query Too Complex

**Problem:** A deeply nested query causes a timeout.

**Fix:** Set query depth limits: `TINA4_GRAPHQL_MAX_DEPTH=5` in `.env`.

### 6. Error Messages Expose Internal Details

**Problem:** Database error messages appear in GraphQL responses.

**Fix:** In production (`TINA4_DEBUG=false`), Tina4 returns generic error messages. Use `begin/rescue` in resolvers to handle errors gracefully.

### 7. Cannot Use GET for Queries

**Problem:** `GET /graphql?query={products{id}}` returns a 404 or error.

**Fix:** GraphQL in Tina4 uses POST by default. All queries and mutations should be sent as POST requests with a JSON body.
