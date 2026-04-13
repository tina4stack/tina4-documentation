# Chapter 22: GraphQL

## 1. The Problem GraphQL Solves

Your mobile app needs a list of products. Each product has a name, price, 20 image URLs, a full description, 15 review objects, and 8 other fields you do not need right now. REST sends all of it. 50KB of JSON when you needed 2KB. On a spotty mobile connection, that wasted bandwidth matters.

Now your web dashboard needs the same products plus the category, stock status, and supplier info. REST forces you into three requests (products, categories, suppliers) stitched together on the client, or a custom endpoint with query parameter parsing on the server.

GraphQL solves both problems. The client asks for the fields it needs. The server returns those fields. One endpoint. One request. One response with the right shape.

Tina4 includes a built-in GraphQL engine. No external packages. No Apollo Server. No `graphql-php` library. Part of the framework.

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

GraphQL is available by default. The engine serves requests at `/graphql`. Change the endpoint in `.env` if needed:

```bash
TINA4_GRAPHQL_ENDPOINT=/graphql
```

To verify it is working, start the server and send a test query:

```bash
curl -X POST http://localhost:7146/graphql \
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

## 4. Defining a Schema

A GraphQL schema defines the data types your API can return and the operations clients can execute.

Create `src/graphql/schema.graphql`:

```graphql
type Product {
    id: Int!
    name: String!
    category: String!
    price: Float!
    inStock: Boolean!
    createdAt: String
}

type Query {
    products: [Product!]!
    product(id: Int!): Product
}
```

This schema says:

- A `Product` has six fields. The `!` means the field is non-nullable.
- The `Query` type has two operations: `products` returns a list of products, and `product(id)` returns a single product (or null if not found).

Tina4 auto-discovers `.graphql` files in `src/graphql/`. You do not need to register them.

---

## 5. Writing Resolvers

A resolver is the function that runs when a query or mutation executes. Resolvers live in `src/graphql/` as PHP files.

Create `src/graphql/resolvers.php`:

```php
<?php
use Tina4\GraphQL;

// Resolve the "products" query
GraphQL::resolve("Query", "products", function ($root, $args) {
    $product = new Product();
    $products = $product->select("*", "", [], "name ASC");

    return array_map(fn($p) => $p->toArray(), $products);
});

// Resolve the "product" query
GraphQL::resolve("Query", "product", function ($root, $args) {
    $product = new Product();
    $product->load($args["id"]);

    if (empty($product->id)) {
        return null;
    }

    return $product->toArray();
});
```

The `GraphQL::resolve()` method takes three arguments:

1. **Type name** -- The GraphQL type this resolver belongs to (`Query`, `Mutation`, or a custom type).
2. **Field name** -- The field within the type this resolver handles.
3. **Resolver function** -- Receives `$root` (the parent value, if any) and `$args` (the query arguments).

### Testing the Queries

List all products:

```bash
curl -X POST http://localhost:7146/graphql \
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

Notice: the response only contains the four fields we asked for (`id`, `name`, `price`, `inStock`), not `category` or `createdAt`. That is GraphQL in action.

Get a single product with all fields:

```bash
curl -X POST http://localhost:7146/graphql \
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
curl -X POST http://localhost:7146/graphql \
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

## 6. Mutations

Mutations create, update, or delete data. They live in the schema alongside queries.

Update `src/graphql/schema.graphql`:

```graphql
type Product {
    id: Int!
    name: String!
    category: String!
    price: Float!
    inStock: Boolean!
    createdAt: String
}

input ProductInput {
    name: String!
    category: String
    price: Float!
    inStock: Boolean
}

input ProductUpdateInput {
    name: String
    category: String
    price: Float
    inStock: Boolean
}

type DeleteResult {
    success: Boolean!
    message: String!
}

type Query {
    products: [Product!]!
    product(id: Int!): Product
    productsByCategory(category: String!): [Product!]!
}

type Mutation {
    createProduct(input: ProductInput!): Product!
    updateProduct(id: Int!, input: ProductUpdateInput!): Product
    deleteProduct(id: Int!): DeleteResult!
}
```

Key concepts:

- **`input` types** define the shape of data the client sends. They are like regular types but used for arguments.
- **`Mutation` type** lists all write operations. By convention, mutations are named with verbs: `createProduct`, `updateProduct`, `deleteProduct`.
- Fields in `ProductUpdateInput` are all optional (no `!`) because the client may only want to update one field.

### Mutation Resolvers

Add to `src/graphql/resolvers.php`:

```php
// Create a product
GraphQL::resolve("Mutation", "createProduct", function ($root, $args) {
    $input = $args["input"];

    $product = new Product();
    $product->name = $input["name"];
    $product->category = $input["category"] ?? "Uncategorized";
    $product->price = (float) $input["price"];
    $product->inStock = (bool) ($input["inStock"] ?? true);
    $product->save();

    return $product->toArray();
});

// Update a product
GraphQL::resolve("Mutation", "updateProduct", function ($root, $args) {
    $product = new Product();
    $product->load($args["id"]);

    if (empty($product->id)) {
        return null;
    }

    $input = $args["input"];
    if (isset($input["name"])) $product->name = $input["name"];
    if (isset($input["category"])) $product->category = $input["category"];
    if (isset($input["price"])) $product->price = (float) $input["price"];
    if (isset($input["inStock"])) $product->inStock = (bool) $input["inStock"];
    $product->save();

    return $product->toArray();
});

// Delete a product
GraphQL::resolve("Mutation", "deleteProduct", function ($root, $args) {
    $product = new Product();
    $product->load($args["id"]);

    if (empty($product->id)) {
        return ["success" => false, "message" => "Product not found"];
    }

    $product->delete();
    return ["success" => true, "message" => "Product deleted"];
});

// Query: products by category
GraphQL::resolve("Query", "productsByCategory", function ($root, $args) {
    $product = new Product();
    $products = $product->select("*", "category = :category", [
        "category" => $args["category"]
    ]);

    return array_map(fn($p) => $p->toArray(), $products);
});
```

### Testing Mutations

Create a product:

```bash
curl -X POST http://localhost:7146/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createProduct(input: { name: \"Desk Lamp\", category: \"Office\", price: 39.99 }) { id name price } }"
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
curl -X POST http://localhost:7146/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { updateProduct(id: 4, input: { price: 44.99, inStock: false }) { id name price inStock } }"
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
curl -X POST http://localhost:7146/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { deleteProduct(id: 4) { success message } }"
  }'
```

```json
{
  "data": {
    "deleteProduct": {
      "success": true,
      "message": "Product deleted"
    }
  }
}
```

---

## 7. Nested Types and Relationships

GraphQL's real power: traversing relationships in a single query. Authors and comments in a blog schema.

Update `src/graphql/schema.graphql`:

```graphql
type User {
    id: Int!
    name: String!
    email: String!
    posts: [Post!]!
}

type Post {
    id: Int!
    title: String!
    body: String!
    published: Boolean!
    author: User!
    comments: [Comment!]!
    commentCount: Int!
}

type Comment {
    id: Int!
    authorName: String!
    body: String!
    post: Post!
}

type Product {
    id: Int!
    name: String!
    category: String!
    price: Float!
    inStock: Boolean!
    createdAt: String
}

input ProductInput {
    name: String!
    category: String
    price: Float!
    inStock: Boolean
}

type DeleteResult {
    success: Boolean!
    message: String!
}

type Query {
    products: [Product!]!
    product(id: Int!): Product
    productsByCategory(category: String!): [Product!]!
    posts: [Post!]!
    post(id: Int!): Post
    user(id: Int!): User
}

type Mutation {
    createProduct(input: ProductInput!): Product!
    deleteProduct(id: Int!): DeleteResult!
}
```

Add resolvers for the nested types:

```php
// Posts query
GraphQL::resolve("Query", "posts", function ($root, $args) {
    $post = new Post();
    $posts = $post->select("*", "published = :pub", ["pub" => 1], "created_at DESC");
    return array_map(fn($p) => $p->toArray(), $posts);
});

// Single post query
GraphQL::resolve("Query", "post", function ($root, $args) {
    $post = new Post();
    $post->load($args["id"]);
    return empty($post->id) ? null : $post->toArray();
});

// Resolve Post.author (nested field)
GraphQL::resolve("Post", "author", function ($post, $args) {
    $user = new User();
    $user->load($post["user_id"]);
    return $user->toArray();
});

// Resolve Post.comments (nested field)
GraphQL::resolve("Post", "comments", function ($post, $args) {
    $comment = new Comment();
    $comments = $comment->select("*", "post_id = :postId", ["postId" => $post["id"]]);
    return array_map(fn($c) => $c->toArray(), $comments);
});

// Resolve Post.commentCount (computed field)
GraphQL::resolve("Post", "commentCount", function ($post, $args) {
    $comment = new Comment();
    $comments = $comment->select("count(*) as cnt", "post_id = :postId", ["postId" => $post["id"]]);
    return $comments[0]->cnt ?? 0;
});

// Resolve User.posts (nested field)
GraphQL::resolve("User", "posts", function ($user, $args) {
    $post = new Post();
    $posts = $post->select("*", "user_id = :userId", ["userId" => $user["id"]]);
    return array_map(fn($p) => $p->toArray(), $posts);
});
```

Now clients can query across relationships in a single request:

```bash
curl -X POST http://localhost:7146/graphql \
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

One request. The fields the client asked for. Nothing more. Nothing less.

---

## 8. Auto-Generating Schema from ORM Models

If your ORM models have `$autoCrud = true`, Tina4 can auto-generate GraphQL types and basic CRUD resolvers for them. Enable this in `.env`:

```bash
TINA4_GRAPHQL_AUTO_SCHEMA=true
```

With this setting, every ORM model with `$autoCrud = true` automatically gets:

- A GraphQL type with fields matching the model properties
- A query to list all records (e.g., `products`)
- A query to get one by ID (e.g., `product(id: Int!)`)
- A mutation to create (e.g., `createProduct(input: ProductInput!)`)
- A mutation to update (e.g., `updateProduct(id: Int!, input: ProductUpdateInput!)`)
- A mutation to delete (e.g., `deleteProduct(id: Int!)`)

You can still define custom resolvers that override the auto-generated ones. Custom resolvers always take precedence.

---

## 9. The GraphiQL Playground

When `TINA4_DEBUG=true`, Tina4 serves a GraphiQL interactive playground at:

```
http://localhost:7146/graphql/playground
```

GraphiQL gives you:

- A query editor with syntax highlighting and auto-completion
- A documentation explorer showing all types, queries, and mutations
- A results panel showing the response
- Query history

This is the fastest way to explore and test your GraphQL API during development. Type a query on the left, click the play button, and see the results on the right. The documentation explorer on the right sidebar shows every type, field, and argument available in your schema.

GraphiQL is only available when `TINA4_DEBUG=true`. In production, it is disabled automatically.

---

## 10. Query Variables

For production, clients send query variables separately from the query string. This prevents injection and allows query caching.

```bash
curl -X POST http://localhost:7146/graphql \
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

The query uses `$id` as a placeholder, and the actual value comes from the `variables` object. This is safer and more efficient than string interpolation.

---

## 11. Exercise: Build a GraphQL API for a Blog

Build a complete GraphQL API for a blog with posts, authors, and comments.

### Requirements

1. **Schema** -- Define types for `User`, `Post`, and `Comment` with the following fields:

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
curl -X POST http://localhost:7146/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ posts { id title author { name } commentCount } }"}'

# Get a specific post with all comments
curl -X POST http://localhost:7146/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ post(id: 1) { title body author { name email } comments { authorName body } } }"}'

# Create a post
curl -X POST http://localhost:7146/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createPost(userId: 1, title: \"GraphQL is great\", body: \"Here is why...\", published: true) { id title } }"}'

# Add a comment
curl -X POST http://localhost:7146/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { addComment(postId: 1, authorName: \"Carol\", body: \"Nice article!\") { id authorName } }"}'

# Get a user with all their posts
curl -X POST http://localhost:7146/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ user(id: 1) { name email posts { title published } } }"}'
```

---

## 12. Solution

### Schema

Create `src/graphql/blog-schema.graphql`:

```graphql
type User {
    id: Int!
    name: String!
    email: String!
    posts: [Post!]!
}

type Post {
    id: Int!
    title: String!
    body: String!
    published: Boolean!
    author: User!
    comments: [Comment!]!
    commentCount: Int!
    createdAt: String
}

type Comment {
    id: Int!
    authorName: String!
    body: String!
    createdAt: String
}

type Query {
    posts: [Post!]!
    post(id: Int!): Post
    user(id: Int!): User
}

type Mutation {
    createPost(userId: Int!, title: String!, body: String!, published: Boolean): Post!
    addComment(postId: Int!, authorName: String!, body: String!): Comment!
}
```

### Resolvers

Create `src/graphql/blog-resolvers.php`:

```php
<?php
use Tina4\GraphQL;

// Query: list published posts
GraphQL::resolve("Query", "posts", function ($root, $args) {
    $post = new Post();
    $posts = $post->select("*", "published = :pub", ["pub" => 1], "created_at DESC");
    return array_map(fn($p) => $p->toArray(), $posts);
});

// Query: single post
GraphQL::resolve("Query", "post", function ($root, $args) {
    $post = new Post();
    $post->load($args["id"]);
    return empty($post->id) ? null : $post->toArray();
});

// Query: single user
GraphQL::resolve("Query", "user", function ($root, $args) {
    $user = new User();
    $user->load($args["id"]);
    return empty($user->id) ? null : $user->toArray();
});

// Post.author resolver
GraphQL::resolve("Post", "author", function ($post, $args) {
    $user = new User();
    $user->load($post["user_id"]);
    return $user->toArray();
});

// Post.comments resolver
GraphQL::resolve("Post", "comments", function ($post, $args) {
    $comment = new Comment();
    $comments = $comment->select("*", "post_id = :postId", [
        "postId" => $post["id"]
    ], "created_at ASC");
    return array_map(fn($c) => $c->toArray(), $comments);
});

// Post.commentCount resolver
GraphQL::resolve("Post", "commentCount", function ($post, $args) {
    $comment = new Comment();
    $results = $comment->select("count(*) as cnt", "post_id = :postId", [
        "postId" => $post["id"]
    ]);
    return (int) ($results[0]->cnt ?? 0);
});

// User.posts resolver
GraphQL::resolve("User", "posts", function ($user, $args) {
    $post = new Post();
    $posts = $post->select("*", "user_id = :userId", [
        "userId" => $user["id"]
    ], "created_at DESC");
    return array_map(fn($p) => $p->toArray(), $posts);
});

// Mutation: create a post
GraphQL::resolve("Mutation", "createPost", function ($root, $args) {
    $user = new User();
    $user->load($args["userId"]);

    if (empty($user->id)) {
        throw new \Exception("User not found");
    }

    $post = new Post();
    $post->userId = $args["userId"];
    $post->title = $args["title"];
    $post->body = $args["body"];
    $post->published = (bool) ($args["published"] ?? false);
    $post->save();

    return $post->toArray();
});

// Mutation: add a comment
GraphQL::resolve("Mutation", "addComment", function ($root, $args) {
    $post = new Post();
    $post->load($args["postId"]);

    if (empty($post->id)) {
        throw new \Exception("Post not found");
    }

    $comment = new Comment();
    $comment->postId = $args["postId"];
    $comment->authorName = $args["authorName"];
    $comment->body = $args["body"];
    $comment->save();

    return $comment->toArray();
});
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

```php
<?php
use Tina4\GraphQL;

GraphQL::resolve("Query", "user", function ($root, $args) {
    $user = new User();
    $user->load($args["id"]);
    return empty($user->id) ? null : $user->toArray();
});
```

With the schema declaring `user(id: ID!): User`, sending a query without the required argument:

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

Your resolver never executes. No null-check needed inside the function.

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

```php
<?php
$result = $gql->execute($query, $variables, [
    'user' => ['id' => 1, 'role' => 'admin']
]);
```

When no user is logged in, pass an empty context or omit the `user` key:

```php
<?php
$result = $gql->execute($query, $variables, []);
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

### 1. Schema File Not Found

**Problem:** Queries return errors about unknown types or fields.

**Cause:** The `.graphql` file is not in `src/graphql/`, or has a syntax error that prevents parsing.

**Fix:** Make sure schema files are in `src/graphql/` and end with `.graphql`. Check for syntax errors -- a missing `!` or unmatched brace will cause the entire schema to fail silently.

### 2. Resolver Not Called

**Problem:** A query returns `null` even though data exists.

**Cause:** The resolver is not registered, or the type/field names do not match the schema exactly. GraphQL is case-sensitive.

**Fix:** Verify that `GraphQL::resolve("Query", "products", ...)` matches `type Query { products: ... }` exactly. Check capitalization.

### 3. Nested Resolver Returns Wrong Data

**Problem:** `post.author` returns the entire post instead of the user.

**Cause:** The nested resolver receives the parent object as its first argument (`$post`), not a fresh model. If you return the parent instead of loading the related record, you get the wrong data.

**Fix:** In a nested resolver, always load the related record from the database using the foreign key from the parent:

```php
GraphQL::resolve("Post", "author", function ($post, $args) {
    $user = new User();
    $user->load($post["user_id"]); // Use the foreign key from the parent
    return $user->toArray();
});
```

### 4. Mutation Input Not Parsed

**Problem:** `$args["input"]` is null inside a mutation resolver.

**Cause:** The mutation signature in the schema uses an `input` type, but the client query passes arguments directly instead of wrapping them in an `input` object.

**Fix:** Match the query to the schema. If the schema says `createProduct(input: ProductInput!)`, the client must send `createProduct(input: { name: "Widget", price: 9.99 })`, not `createProduct(name: "Widget", price: 9.99)`.

### 5. N+1 Query Problem

**Problem:** Loading 50 posts with their authors generates 51 database queries (1 for posts + 50 for authors).

**Cause:** Each nested resolver runs independently. When you resolve `author` for each post, that is one query per post.

**Fix:** Use data loader patterns or batch loading. For simple cases, you can pre-load all related records in the parent resolver and pass them down. Check `$ctx["__selections"]` to see which nested fields the client requested -- if `author` is not in the selection set, skip the join. For ORM queries, use the `include` parameter to eager-load relationships in a single query. For complex cases, consider using the REST API with eager loading instead of GraphQL for that particular endpoint.

### 6. GraphQL Playground Returns 404

**Problem:** `/graphql/playground` returns a 404 error.

**Cause:** `TINA4_DEBUG` is set to `false`. The playground is only available in debug mode.

**Fix:** Set `TINA4_DEBUG=true` in your `.env` file. The playground is intentionally disabled in production.

### 7. Type Mismatch Between Schema and Resolver

**Problem:** A field declared as `Int!` in the schema receives a string from the resolver, causing a type error.

**Cause:** PHP does not enforce types as strictly as GraphQL. If your resolver returns `"42"` (a string) for an `Int!` field, GraphQL rejects it.

**Fix:** The input validation layer (see section 13) now coerces compatible types automatically -- a string `"42"` passed as an argument to an `Int` parameter is converted before your resolver runs. However, resolver *return values* still need correct types. Cast values explicitly with `(int)`, `(float)`, `(bool)`:

```php
return [
    "id" => (int) $product->id,
    "price" => (float) $product->price,
    "inStock" => (bool) $product->inStock
];
```

The `toArray()` method handles this automatically for model properties with type declarations, but computed or derived fields need manual casting.
