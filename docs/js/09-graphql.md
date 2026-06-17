# Chapter 9: GraphQL

## One Method, Two Worlds

REST gives you URLs. GraphQL gives you a query language. Different philosophies, different trade-offs -- but your frontend shouldn't care. The `api` module you met in Chapter 6 already speaks GraphQL. Same auth. Same token rotation. Same error handling. One extra method and you're talking to a GraphQL endpoint.

No Apollo. No urql. No code generation. You write a query string, pass it to `api.graphql()`, and get back `{ data, errors }`. The framework handles the plumbing.

---

## 1. Your First Query

`api.graphql()` sends a POST with `{ query, variables }` and returns a typed response.

```javascript
import { api } from "tina4-js";

api.configure({ baseUrl: "/api", auth: true });

const { data, errors } = await api.graphql("/graphql",
    "{ products { id name price } }"
);

if (errors) {
    console.error("GraphQL errors:", errors);
} else {
    console.log(data.products);
}
```

The response shape never changes:

```typescript
{
    data: T | null;          // Your result, or null on failure
    errors?: Array<{ message: string }>;  // Present only when something went wrong
}
```

Query succeeds -- `data` holds your result, `errors` is undefined. Query fails -- `data` is null, `errors` tells you why. No status codes to decode. No response body formats to guess at.

---

## 2. Variables

Hardcoded values in query strings invite injection and kill reusability. Variables fix both problems. Pass them as the third argument.

```javascript
const { data } = await api.graphql("/graphql",
    `query ($limit: Int!, $offset: Int!) {
        products(limit: $limit, offset: $offset) {
            id
            name
            price
            stock
        }
    }`,
    { limit: 10, offset: 0 }
);
```

A search query with user input:

```javascript
const { data } = await api.graphql("/graphql",
    `query ($term: String!) {
        search_products(term: $term) {
            id
            name
            price
        }
    }`,
    { term: "widget" }
);
```

The variable goes into the JSON body, not the query string. The server handles escaping. Your frontend stays clean.

---

## 3. Mutations

Queries read. Mutations write. Same method, different keyword.

### Create

```javascript
const { data } = await api.graphql("/graphql",
    `mutation ($input: ProductInput!) {
        create_product(input: $input) {
            id
            name
            price
        }
    }`,
    {
        input: {
            name: "New Widget",
            price: 29.99,
            category_id: 1,
            stock: 100
        }
    }
);

console.log("Created:", data.create_product.id);
```

### Update

```javascript
const { data } = await api.graphql("/graphql",
    `mutation ($id: Int!, $input: ProductInput!) {
        update_product(id: $id, input: $input) {
            id
            name
            price
        }
    }`,
    { id: 42, input: { price: 24.99 } }
);
```

### Delete

```javascript
const { data } = await api.graphql("/graphql",
    `mutation ($id: Int!) {
        delete_product(id: $id) {
            success
        }
    }`,
    { id: 42 }
);
```

Three operations. One method. The server reads the `query` or `mutation` keyword and knows what to do.

---

## 4. Authentication

`api.graphql()` runs through the same auth pipeline as every other `api` method. Configure auth once and forget about it.

```javascript
api.configure({
    baseUrl: "/api",
    auth: true,
});

// The Bearer token rides along
const { data } = await api.graphql("/graphql",
    "{ me { id name email role } }"
);
```

Token rotation works too. The server sends a `FreshToken` header. The client stores it. The next request uses the fresh token. You never touch any of this.

---

## 5. Error Handling

GraphQL responses carry two kinds of failure. The HTTP request itself can fail -- network down, server crashed, 500 response. Or the request succeeds but the query contains errors -- bad field name, permission denied, validation failure.

### GraphQL Errors (query-level)

The server returns 200 but `errors` is populated. `data` might still hold partial results.

```javascript
const { data, errors } = await api.graphql("/graphql",
    `{
        products { id name }
        categories { id name }
    }`
);

if (errors) {
    for (const err of errors) {
        console.warn("GraphQL error:", err.message);
    }
}

// Products might have loaded even if categories failed
if (data?.products) {
    renderProducts(data.products);
}
```

### Network Errors (transport-level)

The HTTP request never completed. This throws.

```javascript
try {
    const { data } = await api.graphql("/graphql", "{ products { id } }");
} catch (err) {
    console.error("Network error:", err);
}
```

Check `errors` for query problems. Catch exceptions for network problems. Handle both and your UI stays resilient.

---

## 6. Custom Headers

Per-request headers and query params go in the fourth argument. Same options object as `api.get()` and `api.post()`.

```javascript
const { data } = await api.graphql("/graphql",
    "{ products { id name } }",
    {},
    {
        headers: { "X-Request-Id": "abc123" },
        params: { debug: "true" }
    }
);
```

The empty object in position three means "no variables." The options follow.

---

## 7. Tina4 Backend Integration

Every Tina4 backend -- Python, PHP, Ruby, Node.js -- generates a GraphQL endpoint from your ORM models. Register a model. The backend builds the schema. The frontend queries it. No SDL files. No resolvers to wire by hand.

The default endpoint is `/api/graphql`.

```javascript
api.configure({ baseUrl: "" });

// The backend generated this query from the User model
const { data } = await api.graphql("/api/graphql",
    "{ users(limit: 10) { id name email } }"
);

// Mutations are generated too
const { data: created } = await api.graphql("/api/graphql",
    `mutation {
        create_user(name: "Alice", email: "alice@example.com") {
            id name email
        }
    }`
);
```

Your ORM models define the schema. The GraphQL layer reads it. The frontend consumes it. Three layers, zero duplication.

---

## 8. TypeScript

`api.graphql()` accepts a type parameter. Pass an interface that describes the response shape and TypeScript narrows the return type.

```typescript
interface ProductsResponse {
    products: Array<{
        id: number;
        name: string;
        price: number;
    }>;
}

const { data } = await api.graphql<ProductsResponse>("/graphql",
    "{ products { id name price } }"
);

// data is ProductsResponse | null
data?.products.forEach(p => console.log(p.name));
```

The type flows through destructuring. Your editor autocompletes `data.products[0].name`. No type assertions needed.

---

## 9. Reactive Queries with Signals

GraphQL and signals fit together. A signal changes. An effect fires the query. The result lands in another signal. The UI updates.

```javascript
import { signal, effect, html } from "tina4-js";
import { api } from "tina4-js/api";

const searchTerm = signal("");
const products = signal([]);
const loading = signal(false);

effect(async () => {
    const term = searchTerm.value;
    if (term.length < 2) return;

    loading.value = true;
    const { data } = await api.graphql("/api/graphql",
        `query ($term: String!) {
            search_products(term: $term) { id name price }
        }`,
        { term }
    );
    products.value = data?.search_products || [];
    loading.value = false;
});

const view = html`
    <input @input=${(e) => { searchTerm.value = e.target.value; }}
           placeholder="Search products...">
    ${() => loading.value
        ? html`<p>Loading...</p>`
        : html`<ul>${() => products.value.map(p =>
            html`<li>${p.name} - $${p.price}</li>`
          )}</ul>`
    }
`;
```

The user types. The signal updates. The effect queries. The list renders. No state management library. No cache normalisation layer. Signals and GraphQL, working together.

---

## Summary

| Call | What it does |
|------|-------------|
| `api.graphql(path, query)` | Run a query |
| `api.graphql(path, query, variables)` | Run a query with variables |
| `api.graphql(path, query, variables, options)` | Run a query with custom headers or params |

One method. It sends `{ query, variables }` as JSON. It returns `{ data, errors }`. Auth, interceptors, and token rotation carry over from your `api.configure()` call. Everything you learned in Chapter 6 applies here -- GraphQL rides on the same transport.
