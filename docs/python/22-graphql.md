# Chapter 22: GraphQL and SOAP

## 1. The Problem GraphQL Solves

Your mobile app needs a list of products. Each product carries a name, price, 20 image URLs, a full description, 15 review objects, and 8 fields you do not need. REST sends all of it -- 50KB of JSON when you needed 2KB. On a mobile connection, that waste stings.

Now your web dashboard needs the same products plus category, stock status, and supplier info. REST forces you to make three requests and stitch them together, or build a custom endpoint with query parameter parsing.

GraphQL ends both problems. The client asks for the fields it needs. The server returns those fields. One endpoint. One request. One response shaped to fit.

Tina4 includes a built-in GraphQL engine. No external packages. No Strawberry. No Ariadne. Part of the framework.

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

GraphQL is available by default in Tina4. The engine serves requests at `/graphql`. If you want to change the endpoint, set it in `.env`:

```bash
TINA4_GRAPHQL_ENDPOINT=/graphql
```

To verify it is working, start the server and send a test query:

```bash
curl -X POST http://localhost:7145/graphql \
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

A GraphQL schema defines the types of data your API can return and the queries and mutations clients can execute.

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

A resolver is the function that runs when a query or mutation is executed. Resolvers live in `src/graphql/` as Python files.

Create `src/graphql/resolvers.py`:

```python
from tina4_python.graphql import GraphQL

# Resolve the "products" query
@GraphQL.resolve("Query", "products")
async def resolve_products(root, args):
    products, count = Product.where("1=1")
    return [p.to_dict() for p in products]


# Resolve the "product" query
@GraphQL.resolve("Query", "product")
async def resolve_product(root, args):
    product = Product.find(args["id"])

    if product is None:
        return None

    return product.to_dict()
```

The `@GraphQL.resolve()` decorator takes two arguments:

1. **Type name** -- The GraphQL type this resolver belongs to (`Query`, `Mutation`, or a custom type).
2. **Field name** -- The field within the type this resolver handles.

The resolver function receives `root` (the parent value, if any) and `args` (the query arguments).

### Testing the Queries

List all products:

```bash
curl -X POST http://localhost:7145/graphql \
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
curl -X POST http://localhost:7145/graphql \
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
curl -X POST http://localhost:7145/graphql \
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

Mutations are how clients create, update, or delete data. They are defined in the schema alongside queries.

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

Add to `src/graphql/resolvers.py`:

```python
@GraphQL.resolve("Mutation", "createProduct")
async def resolve_create_product(root, args):
    input_data = args["input"]

    product = Product()
    product.name = input_data["name"]
    product.category = input_data.get("category", "Uncategorized")
    product.price = float(input_data["price"])
    product.in_stock = bool(input_data.get("inStock", True))
    product.save()

    return product.to_dict()


@GraphQL.resolve("Mutation", "updateProduct")
async def resolve_update_product(root, args):
    product = Product.find(args["id"])

    if product is None:
        return None

    input_data = args["input"]
    if "name" in input_data:
        product.name = input_data["name"]
    if "category" in input_data:
        product.category = input_data["category"]
    if "price" in input_data:
        product.price = float(input_data["price"])
    if "inStock" in input_data:
        product.in_stock = bool(input_data["inStock"])
    product.save()

    return product.to_dict()


@GraphQL.resolve("Mutation", "deleteProduct")
async def resolve_delete_product(root, args):
    product = Product.find(args["id"])

    if product is None:
        return {"success": False, "message": "Product not found"}

    product.delete()
    return {"success": True, "message": "Product deleted"}


@GraphQL.resolve("Query", "productsByCategory")
async def resolve_products_by_category(root, args):
    products, count = Product.where("category = ?", [args["category"]])
    return [p.to_dict() for p in products]
```

### Testing Mutations

Create a product:

```bash
curl -X POST http://localhost:7145/graphql \
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
curl -X POST http://localhost:7145/graphql \
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
curl -X POST http://localhost:7145/graphql \
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

The real power of GraphQL: traversing relationships in a single query. Authors, posts, comments -- all in one request.

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

Add resolvers for the nested types:

```python
@GraphQL.resolve("Query", "posts")
async def resolve_posts(root, args):
    posts, count = Post.where("published = ?", [1])
    return [p.to_dict() for p in posts]


@GraphQL.resolve("Query", "post")
async def resolve_post(root, args):
    post = Post.find(args["id"])
    return post.to_dict() if post else None


# Resolve Post.author (nested field)
@GraphQL.resolve("Post", "author")
async def resolve_post_author(post, args):
    user = User.find(post["user_id"])
    return user.to_dict() if user else None


# Resolve Post.comments (nested field)
@GraphQL.resolve("Post", "comments")
async def resolve_post_comments(post, args):
    comments, count = Comment.where("post_id = ?", [post["id"]])
    return [c.to_dict() for c in comments]


# Resolve Post.commentCount (computed field)
@GraphQL.resolve("Post", "commentCount")
async def resolve_post_comment_count(post, args):
    comments, count = Comment.where("post_id = ?", [post["id"]])
    return count


# Resolve User.posts (nested field)
@GraphQL.resolve("User", "posts")
async def resolve_user_posts(user, args):
    posts, count = Post.where("user_id = ?", [user["id"]])
    return [p.to_dict() for p in posts]
```

Now clients can query across relationships in a single request:

```bash
curl -X POST http://localhost:7145/graphql \
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

One request. Exactly the fields the client needs. No over-fetching. No under-fetching.

---

## 8. Auto-Generating Schema from ORM Models

If your ORM models have `auto_crud = True`, Tina4 can auto-generate GraphQL types and basic CRUD resolvers for them. Enable this in `.env`:

```bash
TINA4_GRAPHQL_AUTO_SCHEMA=true
```

With this setting, every ORM model with `auto_crud = True` automatically gets:

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
http://localhost:7145/graphql/playground
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

For production use, clients should send query variables separately from the query string. This prevents injection and allows query caching.

```bash
curl -X POST http://localhost:7145/graphql \
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
curl -X POST http://localhost:7145/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ posts { id title author { name } commentCount } }"}'

# Get a specific post with all comments
curl -X POST http://localhost:7145/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ post(id: 1) { title body author { name email } comments { authorName body } } }"}'

# Create a post
curl -X POST http://localhost:7145/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createPost(userId: 1, title: \"GraphQL is great\", body: \"Here is why...\", published: true) { id title } }"}'

# Add a comment
curl -X POST http://localhost:7145/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { addComment(postId: 1, authorName: \"Carol\", body: \"Nice article!\") { id authorName } }"}'
```

---

## 12. Solution

### Schema

Create `src/graphql/blog_schema.graphql`:

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

Create `src/graphql/blog_resolvers.py`:

```python
from tina4_python.graphql import GraphQL


@GraphQL.resolve("Query", "posts")
async def resolve_posts(root, args):
    posts, count = Post.where("published = ?", [1])
    return [p.to_dict() for p in posts]


@GraphQL.resolve("Query", "post")
async def resolve_post(root, args):
    post = Post.find(args["id"])
    return post.to_dict() if post else None


@GraphQL.resolve("Query", "user")
async def resolve_user(root, args):
    user = User.find(args["id"])
    return user.to_dict() if user else None


@GraphQL.resolve("Post", "author")
async def resolve_post_author(post, args):
    user = User.find(post["user_id"])
    return user.to_dict() if user else None


@GraphQL.resolve("Post", "comments")
async def resolve_post_comments(post, args):
    comments, count = Comment.where("post_id = ?", [post["id"]])
    return [c.to_dict() for c in comments]


@GraphQL.resolve("Post", "commentCount")
async def resolve_post_comment_count(post, args):
    comments, count = Comment.where("post_id = ?", [post["id"]])
    return count


@GraphQL.resolve("User", "posts")
async def resolve_user_posts(user, args):
    posts, count = Post.where("user_id = ?", [user["id"]])
    return [p.to_dict() for p in posts]


@GraphQL.resolve("Mutation", "createPost")
async def resolve_create_post(root, args):
    user = User.find(args["userId"])

    if user is None:
        raise Exception("User not found")

    post = Post()
    post.user_id = args["userId"]
    post.title = args["title"]
    post.body = args["body"]
    post.published = bool(args.get("published", False))
    post.save()

    return post.to_dict()


@GraphQL.resolve("Mutation", "addComment")
async def resolve_add_comment(root, args):
    post = Post.find(args["postId"])

    if post is None:
        raise Exception("Post not found")

    comment = Comment()
    comment.post_id = args["postId"]
    comment.author_name = args["authorName"]
    comment.body = args["body"]
    comment.save()

    return comment.to_dict()
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

Tina4's GraphQL engine validates arguments against their declared types before the resolver runs. If validation fails, the resolver is skipped and a clean error is returned.

### What Gets Validated

- **Non-null enforcement** — `ID!` means the argument cannot be null or empty
- **Scalar type checking** — `Int` must be numeric, `Boolean` must be bool, `String` must be scalar
- **Type coercion** — string `"123"` coerces to Int `123`, string `"true"` coerces to Boolean `True`
- **List item validation** — `[Int!]` checks each item in the list

### Example

```python
gql.schema.add_query("user", {"id": "ID!"}, "User", lambda r, a, c: find_user(a["id"]))
```

Query with missing required argument:

```graphql
{ user { id name } }
```

Response:

```json
{
  "data": { "user": null },
  "errors": [
    { "message": "Argument 'id' on field 'user' is required (type: ID!)", "path": ["user"] }
  ]
}
```

The resolver never runs. The client gets a clear error describing what went wrong and where.

---

## 14. Field-Level Auth Directives

Control access to individual fields using directives. No middleware setup, no wrapper functions — add a directive to the query and Tina4 checks the context.

### Available Directives

| Directive | Meaning |
|-----------|---------|
| `@auth` | Field requires any authenticated user |
| `@role(role: "admin")` | Field requires a specific role |
| `@guest` | Field is only accessible to unauthenticated users |

### Passing Auth Context

The `execute()` method accepts a `context` parameter. Pass the authenticated user from your request handler:

```python
from tina4_python import get
from tina4_python.graphql import GraphQL

gql = GraphQL()

@get("/api/graphql")
async def graphql_handler(request, response):
    body = request.body
    context = {}
    if request.user:
        context["user"] = {"id": request.user.id, "role": request.user.role}

    result = gql.execute(body["query"], body.get("variables"), context)
    return response.json(result)
```

### Using Directives in Queries

```graphql
# Only authenticated users can see this field
{ profile @auth { id name email } }

# Only admins can see salary
{ employees { name salary @role(role: "admin") } }

# Only guests see the registration prompt
{ registrationBanner @guest }
```

When a directive check fails, the field returns `null` and is silently excluded from the response. No error is added — the field simply doesn't appear, as if it doesn't exist for that user.

---

## 15. Gotchas

### 1. Schema File Not Found

**Problem:** Queries return errors about unknown types or fields.

**Cause:** The `.graphql` file is not in `src/graphql/`, or has a syntax error that prevents parsing.

**Fix:** Make sure schema files are in `src/graphql/` and end with `.graphql`. Check for syntax errors -- a missing `!` or unmatched brace will cause the entire schema to fail silently.

### 2. Resolver Not Called

**Problem:** A query returns `null` even though data exists.

**Cause:** The resolver is not registered, or the type/field names do not match the schema exactly. GraphQL is case-sensitive.

**Fix:** Verify that `@GraphQL.resolve("Query", "products")` matches `type Query { products: ... }` exactly. Check capitalization.

### 3. Nested Resolver Returns Wrong Data

**Problem:** `post.author` returns the entire post instead of the user.

**Cause:** The nested resolver receives the parent object as its first argument (`post`), not a fresh model. If you return the parent instead of loading the related record, you get the wrong data.

**Fix:** In a nested resolver, always load the related record from the database using the foreign key from the parent:

```python
@GraphQL.resolve("Post", "author")
async def resolve_post_author(post, args):
    user = User.find(post["user_id"])  # Use the foreign key from the parent
    return user.to_dict() if user else None
```

### 4. Mutation Input Not Parsed

**Problem:** `args["input"]` is `None` inside a mutation resolver.

**Cause:** The mutation signature in the schema uses an `input` type, but the client query passes arguments directly instead of wrapping them in an `input` object.

**Fix:** Match the query to the schema. If the schema says `createProduct(input: ProductInput!)`, the client must send `createProduct(input: { name: "Widget", price: 9.99 })`, not `createProduct(name: "Widget", price: 9.99)`.

### 5. N+1 Query Problem

**Problem:** Loading 50 posts with their authors generates 51 database queries (1 for posts + 50 for authors).

**Cause:** Each nested resolver runs independently. When you resolve `author` for each post, that is one query per post.

**Fix:** Use the `include` parameter in your ORM queries to eager-load relationships. Tina4's GraphQL engine injects the current selection set into context as `context["__selections"]`, so `fromOrm` resolvers can detect which relationships the client requested and batch-load them:

```python
# The fromOrm resolver automatically checks __selections and eager-loads
gql.schema.from_orm(Post)  # Generates queries that use include= when sub-fields match relationships
```

For custom resolvers, check `context.get("__selections")` and pre-load related data in a single query.

### 6. GraphQL Playground Returns 404

**Problem:** `/graphql/playground` returns a 404 error.

**Cause:** `TINA4_DEBUG` is set to `false`. The playground is only available in debug mode.

**Fix:** Set `TINA4_DEBUG=true` in your `.env` file. The playground is intentionally disabled in production.

### 7. Type Mismatch Between Schema and Resolver

**Problem:** A field declared as `Int!` in the schema receives a string from the resolver.

**Cause:** Python's dynamic typing means your resolver might return `"42"` (a string) for an `Int!` field.

**Fix:** Tina4's input validation now coerces argument types automatically (string `"123"` becomes Int `123`). For return values, `to_dict()` handles type casting for ORM model properties. For computed fields, cast explicitly:

```python
return {
    "id": int(product.id),
    "price": float(product.price),
    "inStock": bool(product.in_stock)
}
```

---

## 14. SOAP / WSDL Services

### What is SOAP?

SOAP (Simple Object Access Protocol) is an XML-based messaging protocol for exchanging structured data between systems. It predates REST and GraphQL, but remains common in enterprise integrations -- banking, healthcare, government, and ERP systems all rely on SOAP services.

A WSDL (Web Services Description Language) file describes a SOAP service: what operations are available, what parameters they accept, and what they return. Clients use the WSDL to auto-generate code for calling the service.

Tina4 includes a zero-dependency SOAP 1.1 server that generates WSDL definitions automatically from Python classes and type annotations. No XML authoring required.

---

### Defining a SOAP Service

Create a class that extends `WSDL`. Each method decorated with `@wsdl_operation` becomes a SOAP operation. The decorator takes a dict describing the response fields and their types.

```python
from tina4_python.wsdl import WSDL, wsdl_operation
from tina4_python.core.router import get, post

class Calculator(WSDL):
    @wsdl_operation({"Result": int})
    def Add(self, a: int, b: int):
        return {"Result": a + b}

    @wsdl_operation({"Result": int})
    def Multiply(self, a: int, b: int):
        return {"Result": a * b}

@get("/calculator")
@post("/calculator")
async def calculator_endpoint(request, response):
    service = Calculator(request)
    return response(service.handle())
```

That is the entire service. The `handle()` method inspects the request:

- **GET** (or `?wsdl` query parameter) -- returns the auto-generated WSDL definition
- **POST** with SOAP XML body -- parses the XML, finds the operation, converts parameters, calls the method, and returns a SOAP XML response

### Type Annotations Map to XSD

Python type annotations on method parameters control how incoming XML values are converted. The WSDL generator also uses them to produce correct XSD type declarations.

| Python type | XSD type |
|-------------|----------|
| `str` | `xsd:string` |
| `int` | `xsd:int` |
| `float` | `xsd:double` |
| `bool` | `xsd:boolean` |
| `bytes` | `xsd:base64Binary` |
| `List[T]` | Element of type T (repeated) |
| `Optional[T]` | Type T (nillable) |

### A More Complete Example

```python
from typing import List, Optional
from tina4_python.wsdl import WSDL, wsdl_operation
from tina4_python.core.router import get, post

class UserService(WSDL):
    @wsdl_operation({"Name": str, "Email": str, "Active": bool})
    def GetUser(self, user_id: int):
        user = User.find(user_id)
        if user:
            return {
                "Name": user.name,
                "Email": user.email,
                "Active": bool(user.active),
            }
        return {"Name": "", "Email": "", "Active": False}

    @wsdl_operation({"Total": int, "Average": float, "Error": Optional[str]})
    def SumList(self, Numbers: List[int]):
        if not Numbers:
            return {"Total": 0, "Average": 0.0, "Error": "Empty list"}
        return {
            "Total": sum(Numbers),
            "Average": sum(Numbers) / len(Numbers),
            "Error": None,
        }

@get("/api/users/soap")
@post("/api/users/soap")
async def user_soap(request, response):
    service = UserService(request)
    return response(service.handle())
```

### Lifecycle Hooks

Override `on_request` and `on_result` to add validation, logging, or transformation around every operation call.

```python
class AuditedService(WSDL):
    def on_request(self, request):
        print(f"SOAP request from {request.headers.get('x-forwarded-for', 'unknown')}")

    def on_result(self, result):
        result["Timestamp"] = datetime.now().isoformat()
        return result

    @wsdl_operation({"Status": str, "Timestamp": str})
    def Ping(self):
        return {"Status": "ok"}
```

### Testing with curl

Fetch the WSDL definition:

```bash
curl http://localhost:7145/calculator?wsdl
```

Call the Add operation with a SOAP request:

```bash
curl -X POST http://localhost:7145/calculator \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <Add>
      <a>5</a>
      <b>3</b>
    </Add>
  </soap:Body>
</soap:Envelope>'
```

Response:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <AddResponse>
      <Result>8</Result>
    </AddResponse>
  </soap:Body>
</soap:Envelope>
```

If the operation name is wrong or the XML is malformed, the service returns a SOAP fault:

```xml
<soap:Fault>
  <faultcode>Client</faultcode>
  <faultstring>Unknown operation: Subtract</faultstring>
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

SOAP is rarely the right choice for new APIs, but when you need to expose a service that legacy systems can consume, Tina4 makes it straightforward -- define a class, annotate your types, and the framework handles the XML.
