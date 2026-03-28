# Chapter 16: GraphQL

## 1. The Problem GraphQL Solves

Your mobile app needs a list of products with name and price. 2KB. Your REST API returns all 20 fields. 50KB. Twenty-five times the payload the client needs.

GraphQL flips control. The client asks for the fields it wants. The server returns nothing else.

Tina4 includes a built-in GraphQL engine. Zero external packages.

---

## 2. GraphQL vs REST

| Aspect | REST | GraphQL |
|--------|------|---------|
| Endpoints | One per resource | One endpoint (`/graphql`) |
| Data shape | Server decides | Client decides |
| Over-fetching | Common | Never |
| Under-fetching | Common | Never |

---

## 3. Enabling GraphQL

GraphQL runs at `/graphql` by default. Test:

```bash
curl -X POST http://localhost:7148/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { queryType { name } } }"}'
```

---

## 4. Defining a Schema

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

---

## 5. Writing Resolvers

Create `src/graphql/resolvers.ts`:

```typescript
import { GraphQL } from "tina4-nodejs";
import { Product } from "../orm/Product";

GraphQL.resolve("Query", "products", async (root, args) => {
    const product = new Product();
    const products = await product.select("*", "", {}, "name ASC");
    return products.map(p => p.toDict());
});

GraphQL.resolve("Query", "product", async (root, args) => {
    const product = new Product();
    await product.load(args.id);
    return product.id ? product.toDict() : null;
});
```

```bash
curl -X POST http://localhost:7148/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ products { id name price inStock } }"}'
```

```json
{
  "data": {
    "products": [
      {"id": 1, "name": "Wireless Keyboard", "price": 79.99, "inStock": true}
    ]
  }
}
```

---

## 6. Mutations

```graphql
input ProductInput {
    name: String!
    category: String
    price: Float!
    inStock: Boolean
}

type Mutation {
    createProduct(input: ProductInput!): Product!
    deleteProduct(id: Int!): DeleteResult!
}

type DeleteResult {
    success: Boolean!
    message: String!
}
```

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

GraphQL.resolve("Mutation", "deleteProduct", async (root, args) => {
    const product = new Product();
    await product.load(args.id);
    if (!product.id) return { success: false, message: "Product not found" };
    await product.delete();
    return { success: true, message: "Product deleted" };
});
```

---

## 7. Nested Types and Relationships

```typescript
GraphQL.resolve("Post", "author", async (post, args) => {
    const user = new User();
    await user.load(post.user_id);
    return user.toDict();
});

GraphQL.resolve("Post", "comments", async (post, args) => {
    const comment = new Comment();
    const comments = await comment.select("*", "post_id = :postId", { postId: post.id });
    return comments.map(c => c.toDict());
});

GraphQL.resolve("User", "posts", async (user, args) => {
    const post = new Post();
    const posts = await post.select("*", "user_id = :userId", { userId: user.id });
    return posts.map(p => p.toDict());
});
```

```bash
curl -X POST http://localhost:7148/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ posts { id title author { name email } comments { authorName body } } }"}'
```

---

## 8. Auto-Generating Schema from ORM Models

```env
TINA4_GRAPHQL_AUTO_SCHEMA=true
```

Every ORM model with `static autoCrud = true` gets GraphQL types and resolvers generated for it. Zero manual schema writing.

---

## 9. The GraphiQL Playground

When `TINA4_DEBUG=true`:

```
http://localhost:7148/graphql/playground
```

---

## 10. Query Variables

```bash
curl -X POST http://localhost:7148/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query GetProduct($id: Int!) { product(id: $id) { id name price } }",
    "variables": {"id": 1}
  }'
```

---

## 11. Exercise: Build a GraphQL API for a Blog

Define types for User, Post, Comment. Implement queries (posts, post, user) and mutations (createPost, addComment).

---

## 12. Solution

Create `src/graphql/blog-schema.graphql` with User, Post, Comment types, and resolvers in `src/graphql/blog-resolvers.ts` using the ORM models from Chapter 6.

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
    const post = new Post();
    post.userId = args.userId;
    post.title = args.title;
    post.body = args.body;
    post.published = Boolean(args.published ?? false);
    await post.save();
    return post.toDict();
});

GraphQL.resolve("Mutation", "addComment", async (root, args) => {
    const comment = new Comment();
    comment.postId = args.postId;
    comment.authorName = args.authorName;
    comment.body = args.body;
    await comment.save();
    return comment.toDict();
});
```

---

## 13. Gotchas

### 1. Schema File Not Found -- Place `.graphql` files in `src/graphql/`.
### 2. Resolver Not Called -- Check type/field names match schema exactly (case-sensitive).
### 3. Nested Resolver Returns Wrong Data -- Load the related record using the foreign key from the parent.
### 4. Mutation Input Not Parsed -- Match the query structure to the schema signature.
### 5. N+1 Query Problem -- Use data loaders or pre-load in parent resolvers.
### 6. GraphQL Playground Returns 404 -- Set `TINA4_DEBUG=true`.
### 7. Type Mismatch -- Cast values explicitly: `parseInt()`, `parseFloat()`, `Boolean()`.

---

## 14. SOAP / WSDL Services

### What is SOAP/WSDL?

SOAP (Simple Object Access Protocol) is an XML-based messaging protocol used in enterprise systems, banking, government, and legacy integrations. WSDL (Web Services Description Language) is the XML contract that describes a SOAP service — its operations, input/output types, and endpoint URL.

Tina4 includes a built-in SOAP 1.1 / WSDL 1.1 engine. Zero external dependencies — XML parsing uses simple string matching.

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

- `serviceName` — appears in the WSDL `<service>` element.
- `serviceUrl` — the URL path for both WSDL and SOAP requests.
- `input` — maps parameter names to type strings.
- `output` — maps return field names to type strings.
- The method receives parameters in the order declared in `input` and returns a plain object matching `output`.

---

### Registering the Service

Call `register()` with your router to wire up two routes automatically:

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

### SOAP Request Handling

When a POST arrives, Tina4 parses the SOAP envelope, extracts the operation name and parameters from the `<Body>`, converts parameter values to the correct types, calls your method, and wraps the result in a SOAP response envelope.

If something goes wrong, a SOAP fault is returned with a `<faultcode>` (`Client` or `Server`) and `<faultstring>`.

---

### Testing with curl

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

1. **Content-Type must be `text/xml`** — SOAP requests are XML, not JSON.
2. **Operation name must match exactly** — the element name inside `<Body>` must match your method name (case-sensitive).
3. **Parameter order matters** — values are extracted in the order declared in `input`.
4. **Namespace prefixes are handled** — Tina4 strips namespace prefixes when matching element names, so `<ns1:Add>` works the same as `<Add>`.
