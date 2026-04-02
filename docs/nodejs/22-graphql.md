# Chapter 16: GraphQL and SOAP

## 1. The Problem GraphQL Solves

Your mobile app needs a list of products. Each product carries a name, price, 20 image URLs, a full description, 15 review objects, and 8 fields you do not need. REST sends all of it -- 50KB of JSON when you needed 2KB. On a mobile connection, that waste stings.

Now your web dashboard needs the same products plus category, stock status, and supplier info. REST forces you to make three requests and stitch them together, or build a custom endpoint with query parameter parsing.

GraphQL ends both problems. The client asks for the fields it needs. The server returns those fields. One endpoint. One request. One response shaped to fit.

Tina4 includes a built-in GraphQL engine. No external packages. No Apollo Server. No graphql-yoga. Part of the framework.

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

```env
TINA4_GRAPHQL_ENDPOINT=/graphql
```

To verify it is working, start the server and send a test query:

```bash
curl -X POST http://localhost:7148/graphql \
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

A resolver is the function that runs when a query or mutation is executed. Resolvers live in `src/graphql/` as TypeScript files.

Create `src/graphql/resolvers.ts`:

```typescript
import { GraphQL } from "tina4-nodejs";
import { Product } from "../orm/Product";

// Resolve the "products" query
GraphQL.resolve("Query", "products", async (root, args) => {
    const product = new Product();
    const products = await product.select("*", "", {}, "name ASC");
    return products.map(p => p.toDict());
});

// Resolve the "product" query
GraphQL.resolve("Query", "product", async (root, args) => {
    const product = new Product();
    await product.load(args.id);
    return product.id ? product.toDict() : null;
});
```

`GraphQL.resolve()` takes three arguments:

1. **Type name** -- The GraphQL type this resolver belongs to (`Query`, `Mutation`, or a custom type).
2. **Field name** -- The field within the type this resolver handles.
3. **Resolver function** -- Receives `root` (the parent value, if any) and `args` (the query arguments).

### Testing the Queries

List all products:

```bash
curl -X POST http://localhost:7148/graphql \
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

Notice: the response contains only the four fields we asked for (`id`, `name`, `price`, `inStock`), not `category` or `createdAt`. That is GraphQL in action.

Get a single product with all fields:

```bash
curl -X POST http://localhost:7148/graphql \
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
curl -X POST http://localhost:7148/graphql \
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

Add to `src/graphql/resolvers.ts`:

```typescript
GraphQL.resolve("Mutation", "createProduct", async (root, args) => {
    const input = args.input;
    const product = new Product();
    product.name = input.name;
    product.category = input.category ?? "Uncategorized";
    product.price = parseFloat(input.price);
    product.inStock = Boolean(input.inStock ?? true);
    await product.save();
    return product.toDict();
});

GraphQL.resolve("Mutation", "updateProduct", async (root, args) => {
    const product = new Product();
    await product.load(args.id);

    if (!product.id) return null;

    const input = args.input;
    if (input.name !== undefined) product.name = input.name;
    if (input.category !== undefined) product.category = input.category;
    if (input.price !== undefined) product.price = parseFloat(input.price);
    if (input.inStock !== undefined) product.inStock = Boolean(input.inStock);
    await product.save();

    return product.toDict();
});

GraphQL.resolve("Mutation", "deleteProduct", async (root, args) => {
    const product = new Product();
    await product.load(args.id);
    if (!product.id) return { success: false, message: "Product not found" };
    await product.delete();
    return { success: true, message: "Product deleted" };
});

GraphQL.resolve("Query", "productsByCategory", async (root, args) => {
    const product = new Product();
    const products = await product.select("*", "category = :category", { category: args.category });
    return products.map(p => p.toDict());
});
```

### Testing Mutations

Create a product:

```bash
curl -X POST http://localhost:7148/graphql \
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
curl -X POST http://localhost:7148/graphql \
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
curl -X POST http://localhost:7148/graphql \
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

```typescript
import { GraphQL } from "tina4-nodejs";
import { Post } from "../orm/Post";
import { User } from "../orm/User";
import { Comment } from "../orm/Comment";

GraphQL.resolve("Query", "posts", async (root, args) => {
    const post = new Post();
    const posts = await post.select("*", "published = :pub", { pub: 1 });
    return posts.map(p => p.toDict());
});

GraphQL.resolve("Query", "post", async (root, args) => {
    const post = new Post();
    await post.load(args.id);
    return post.id ? post.toDict() : null;
});

// Resolve Post.author (nested field)
GraphQL.resolve("Post", "author", async (post, args) => {
    const user = new User();
    await user.load(post.user_id);
    return user.toDict();
});

// Resolve Post.comments (nested field)
GraphQL.resolve("Post", "comments", async (post, args) => {
    const comment = new Comment();
    const comments = await comment.select("*", "post_id = :postId", { postId: post.id });
    return comments.map(c => c.toDict());
});

// Resolve Post.commentCount (computed field)
GraphQL.resolve("Post", "commentCount", async (post, args) => {
    const comment = new Comment();
    const result = await comment.select("count(*) as cnt", "post_id = :postId", { postId: post.id });
    return parseInt(result[0]?.cnt ?? 0, 10);
});

// Resolve User.posts (nested field)
GraphQL.resolve("User", "posts", async (user, args) => {
    const post = new Post();
    const posts = await post.select("*", "user_id = :userId", { userId: user.id });
    return posts.map(p => p.toDict());
});
```

Now clients can query across relationships in a single request:

```bash
curl -X POST http://localhost:7148/graphql \
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

## 8. Auto-Generating Schema from ORM Models

If your ORM models have `static autoCrud = true`, Tina4 can auto-generate GraphQL types and basic CRUD resolvers for them. Enable this in `.env`:

```env
TINA4_GRAPHQL_AUTO_SCHEMA=true
```

With this setting, every ORM model with `static autoCrud = true` gets:

- A GraphQL type with fields matching the model properties
- A query to list all records (e.g., `products`)
- A query to get one by ID (e.g., `product(id: Int!)`)
- A mutation to create (e.g., `createProduct(input: ProductInput!)`)
- A mutation to update (e.g., `updateProduct(id: Int!, input: ProductUpdateInput!)`)
- A mutation to delete (e.g., `deleteProduct(id: Int!)`)

You can still define custom resolvers that override the auto-generated ones. Custom resolvers take precedence.

---

## 9. The GraphiQL Playground

When `TINA4_DEBUG=true`, Tina4 serves a GraphiQL interactive playground at:

```
http://localhost:7148/graphql/playground
```

GraphiQL gives you:

- A query editor with syntax highlighting and auto-completion
- A documentation explorer showing all types, queries, and mutations
- A results panel showing the response
- Query history

This is the fastest way to explore and test your GraphQL API during development. Type a query on the left, click the play button, and see the results on the right. The documentation explorer on the right sidebar shows every type, field, and argument available in your schema.

GraphiQL is only available when `TINA4_DEBUG=true`. In production, it is disabled.

---

## 10. Query Variables

For production use, clients should send query variables separately from the query string. This prevents injection and allows query caching.

```bash
curl -X POST http://localhost:7148/graphql \
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
curl -X POST http://localhost:7148/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ posts { id title author { name } commentCount } }"}'

# Get a specific post with all comments
curl -X POST http://localhost:7148/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ post(id: 1) { title body author { name email } comments { authorName body } } }"}'

# Create a post
curl -X POST http://localhost:7148/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createPost(userId: 1, title: \"GraphQL is great\", body: \"Here is why...\", published: true) { id title } }"}'

# Add a comment
curl -X POST http://localhost:7148/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { addComment(postId: 1, authorName: \"Carol\", body: \"Nice article!\") { id authorName } }"}'
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

Create `src/graphql/blog-resolvers.ts`:

```typescript
import { GraphQL } from "tina4-nodejs";
import { Post } from "../orm/Post";
import { User } from "../orm/User";
import { Comment } from "../orm/Comment";

GraphQL.resolve("Query", "posts", async () => {
    const post = new Post();
    const posts = await post.select("*", "published = :pub", { pub: 1 }, "created_at DESC");
    return posts.map(p => p.toDict());
});

GraphQL.resolve("Query", "post", async (root, args) => {
    const post = new Post();
    await post.load(args.id);
    return post.id ? post.toDict() : null;
});

GraphQL.resolve("Query", "user", async (root, args) => {
    const user = new User();
    await user.load(args.id);
    return user.id ? user.toDict() : null;
});

GraphQL.resolve("Post", "author", async (post) => {
    const user = new User();
    await user.load(post.user_id);
    return user.toDict();
});

GraphQL.resolve("Post", "comments", async (post) => {
    const comment = new Comment();
    const comments = await comment.select("*", "post_id = :postId", { postId: post.id }, "created_at ASC");
    return comments.map(c => c.toDict());
});

GraphQL.resolve("Post", "commentCount", async (post) => {
    const comment = new Comment();
    const result = await comment.select("count(*) as cnt", "post_id = :postId", { postId: post.id });
    return parseInt(result[0]?.cnt ?? 0, 10);
});

GraphQL.resolve("User", "posts", async (user) => {
    const post = new Post();
    const posts = await post.select("*", "user_id = :userId", { userId: user.id }, "created_at DESC");
    return posts.map(p => p.toDict());
});

GraphQL.resolve("Mutation", "createPost", async (root, args) => {
    const user = new User();
    await user.load(args.userId);

    if (!user.id) {
        throw new Error("User not found");
    }

    const post = new Post();
    post.userId = args.userId;
    post.title = args.title;
    post.body = args.body;
    post.published = Boolean(args.published ?? false);
    await post.save();

    return post.toDict();
});

GraphQL.resolve("Mutation", "addComment", async (root, args) => {
    const post = new Post();
    await post.load(args.postId);

    if (!post.id) {
        throw new Error("Post not found");
    }

    const comment = new Comment();
    comment.postId = args.postId;
    comment.authorName = args.authorName;
    comment.body = args.body;
    await comment.save();

    return comment.toDict();
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

## 13. Gotchas

### 1. Schema File Not Found

**Problem:** Queries return errors about unknown types or fields.

**Cause:** The `.graphql` file is not in `src/graphql/`, or has a syntax error that prevents parsing.

**Fix:** Make sure schema files are in `src/graphql/` and end with `.graphql`. Check for syntax errors -- a missing `!` or unmatched brace will cause the entire schema to fail silently.

### 2. Resolver Not Called

**Problem:** A query returns `null` even though data exists.

**Cause:** The resolver is not registered, or the type/field names do not match the schema. GraphQL is case-sensitive.

**Fix:** Verify that `GraphQL.resolve("Query", "products", ...)` matches `type Query { products: ... }` in your schema. Check capitalization.

### 3. Nested Resolver Returns Wrong Data

**Problem:** `post.author` returns the entire post instead of the user.

**Cause:** The nested resolver receives the parent object as its first argument (`post`), not a fresh model. If you return the parent instead of loading the related record, you get the wrong data.

**Fix:** In a nested resolver, load the related record from the database using the foreign key from the parent:

```typescript
GraphQL.resolve("Post", "author", async (post, args) => {
    const user = new User();
    await user.load(post.user_id);  // Use the foreign key from the parent
    return user.toDict();
});
```

### 4. Mutation Input Not Parsed

**Problem:** `args.input` is `undefined` inside a mutation resolver.

**Cause:** The mutation signature in the schema uses an `input` type, but the client query passes arguments directly instead of wrapping them in an `input` object.

**Fix:** Match the query to the schema. If the schema says `createProduct(input: ProductInput!)`, the client must send `createProduct(input: { name: "Widget", price: 9.99 })`, not `createProduct(name: "Widget", price: 9.99)`.

### 5. N+1 Query Problem

**Problem:** Loading 50 posts with their authors generates 51 database queries (1 for posts + 50 for authors).

**Cause:** Each nested resolver runs on its own. When you resolve `author` for each post, that is one query per post.

**Fix:** Use data loader patterns or batch loading. For simple cases, pre-load all related records in the parent resolver and pass them down. For complex cases, consider using the REST API with eager loading instead of GraphQL for that particular endpoint.

### 6. GraphQL Playground Returns 404

**Problem:** `/graphql/playground` returns a 404 error.

**Cause:** `TINA4_DEBUG` is set to `false`. The playground is only available in debug mode.

**Fix:** Set `TINA4_DEBUG=true` in your `.env` file. The playground is disabled in production by design.

### 7. Type Mismatch Between Schema and Resolver

**Problem:** A field declared as `Int!` in the schema receives a string from the resolver, causing a type error.

**Cause:** JavaScript's loose typing means your resolver might return `"42"` (a string) for an `Int!` field. GraphQL rejects it.

**Fix:** Cast values to the correct type in your resolvers. Use `parseInt()`, `parseFloat()`, `Boolean()`:

```typescript
return {
    id: parseInt(product.id, 10),
    price: parseFloat(product.price),
    inStock: Boolean(product.inStock)
};
```

The `toDict()` method handles this for model properties with type declarations, but computed or derived fields need manual casting.

---

## 14. SOAP / WSDL Services

### What is SOAP?

SOAP (Simple Object Access Protocol) is an XML-based messaging protocol for exchanging structured data between systems. It predates REST and GraphQL, but remains common in enterprise integrations -- banking, healthcare, government, and ERP systems all rely on SOAP services.

A WSDL (Web Services Description Language) file describes a SOAP service: what operations are available, what parameters they accept, and what they return. Clients use the WSDL to auto-generate code for calling the service.

Tina4 includes a built-in SOAP 1.1 / WSDL 1.1 engine. Zero external dependencies -- XML parsing uses simple string matching.

---

### Defining a SOAP Service

Create a class that extends `WSDLService`. Each method you want to expose gets the `@WSDLOp` decorator with `input` and `output` type maps.

```typescript
import { WSDLService, WSDLOp } from "tina4-nodejs";

class Calculator extends WSDLService {
  serviceName = "Calculator";
  serviceUrl = "/api/calculator";

  @WSDLOp({
    description: "Add two numbers",
    input: { a: "int", b: "int" },
    output: { Result: "int" },
  })
  async Add(a: number, b: number): Promise<Record<string, unknown>> {
    return { Result: a + b };
  }

  @WSDLOp({
    description: "Multiply two numbers",
    input: { x: "float", y: "float" },
    output: { Product: "double" },
  })
  async Multiply(x: number, y: number): Promise<Record<string, unknown>> {
    return { Product: x * y };
  }
}
```

Key points:

- `serviceName` -- appears in the WSDL `<service>` element.
- `serviceUrl` -- the URL path for both WSDL and SOAP requests.
- `input` -- maps parameter names to type strings.
- `output` -- maps return field names to type strings.
- The method receives parameters in the order declared in `input` and returns a plain object matching `output`.

---

### Registering the Service

Call `register()` with your router to wire up two routes:

```typescript
const calc = new Calculator();
calc.register(router);
```

This creates:

| Method | URL | Purpose |
|--------|-----|---------|
| GET | `/api/calculator?wsdl` | Returns the auto-generated WSDL XML |
| POST | `/api/calculator` | Accepts SOAP XML requests |

---

### Auto-Generated WSDL

Fetch the WSDL document:

```bash
curl http://localhost:7148/api/calculator?wsdl
```

Tina4 generates a complete WSDL 1.1 document containing `<types>`, `<message>`, `<portType>`, `<binding>`, and `<service>` sections. The endpoint URL is inferred from the request's `Host` header.

---

### Type Mappings

The `input` and `output` maps use short type names that are converted to XSD types:

| Tina4 Type | XSD Type |
|------------|----------|
| `int`, `integer` | `xsd:int` |
| `float` | `xsd:float` |
| `double`, `number`, `numeric` | `xsd:double` |
| `string` | `xsd:string` |
| `bool`, `boolean` | `xsd:boolean` |

Unknown types default to `xsd:string`.

---

### Lifecycle Hooks

Override `onRequest` and `onResult` to add validation, logging, or transformation around every operation call.

```typescript
import { WSDLService, WSDLOp } from "tina4-nodejs";

class AuditedService extends WSDLService {
  serviceName = "AuditedService";
  serviceUrl = "/api/audited";

  onRequest(request: any): void {
    console.log(`SOAP request from ${request.headers["x-forwarded-for"] ?? "unknown"}`);
  }

  onResult(result: Record<string, unknown>): Record<string, unknown> {
    result["Timestamp"] = new Date().toISOString();
    return result;
  }

  @WSDLOp({
    description: "Health check",
    input: {},
    output: { Status: "string", Timestamp: "string" },
  })
  async Ping(): Promise<Record<string, unknown>> {
    return { Status: "ok" };
  }
}
```

---

### Testing with curl

Fetch the WSDL definition:

```bash
curl http://localhost:7148/api/calculator?wsdl
```

Send a SOAP request to the `Add` operation:

```bash
curl -X POST http://localhost:7148/api/calculator \
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

---

### A More Complete Example

A user lookup service with multiple operations:

```typescript
import { WSDLService, WSDLOp } from "tina4-nodejs";

class UserService extends WSDLService {
  serviceName = "UserService";
  serviceUrl = "/api/users/soap";

  @WSDLOp({
    description: "Look up a user by ID",
    input: { userId: "int" },
    output: { Name: "string", Email: "string", Active: "boolean" },
  })
  async GetUser(userId: number): Promise<Record<string, unknown>> {
    // Replace with real database lookup
    return { Name: "Alice", Email: "alice@example.com", Active: true };
  }

  @WSDLOp({
    description: "Search users by name",
    input: { query: "string" },
    output: { Count: "int", Names: "string" },
  })
  async SearchUsers(query: string): Promise<Record<string, unknown>> {
    return { Count: 1, Names: "Alice" };
  }
}
```

---

### SOAP Gotchas

1. **Content-Type must be `text/xml`** -- SOAP requests are XML, not JSON.
2. **Operation name must match** -- the element name inside `<Body>` must match your method name (case-sensitive).
3. **Parameter order matters** -- values are extracted in the order declared in `input`.
4. **Namespace prefixes are handled** -- Tina4 strips namespace prefixes when matching element names, so `<ns1:Add>` works the same as `<Add>`.

---

### When to Use SOAP vs REST vs GraphQL

| Scenario | Use |
|----------|-----|
| New API for web/mobile clients | REST or GraphQL |
| Integrating with legacy enterprise systems (SAP, banks, government) | SOAP |
| Clients require a machine-readable service contract | SOAP (WSDL) |
| Simple internal microservices | REST |
| Clients with diverse data needs | GraphQL |

SOAP is rarely the right choice for new APIs, but when you need to expose a service that legacy systems can consume, Tina4 makes it straightforward -- define a class, annotate your types, and the framework handles the XML.
