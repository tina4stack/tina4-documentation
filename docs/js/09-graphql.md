# Chapter 9: GraphQL

## Queries and Mutations Without a Client Library

You have a GraphQL API. You reach for Apollo Client — 30KB gzipped, its own cache, its own state management, its own learning curve. Or you write raw `fetch` calls and parse `data` and `errors` yourself every time.

tina4-js adds one method: `api.graphql()`. Same auth, same interceptors, same error handling as every other `api.*` call. Zero additional dependencies.

---

## 1. Setup

GraphQL uses the same API client as REST. Configure it once:

```typescript
import { api } from 'tina4js';

api.configure({
  baseUrl: '/api',
  auth: true,
});
```

Every `api.graphql()` call inherits the base URL, auth headers, interceptors, and token rotation.

---

## 2. Simple Query

```typescript
const { data, errors } = await api.graphql('/graphql',
  '{ products(limit: 10) { id name price } }'
);

if (errors) {
  console.error('GraphQL errors:', errors);
} else {
  console.log(data.products);
}
```

The method sends a POST request with `{ query, variables }` in the body. The response is `{ data, errors }` — the standard GraphQL response shape.

---

## 3. Query with Variables

```typescript
const { data } = await api.graphql('/graphql',
  `query ($term: String!) {
    search_products(term: $term) {
      id
      name
      price
    }
  }`,
  { term: 'widget' }
);

console.log(data.search_products);
```

Variables are passed as the third argument. They're sent as `{ query, variables: { term: "widget" } }` in the request body.

---

## 4. Mutations

```typescript
const { data, errors } = await api.graphql('/graphql',
  `mutation ($input: CreateProductInput!) {
    createProduct(input: $input) {
      id
      name
      price
    }
  }`,
  { input: { name: 'New Widget', price: 29.99 } }
);

if (data?.createProduct) {
  console.log('Created:', data.createProduct.id);
}
```

Mutations use the same method. GraphQL doesn't distinguish between query and mutation at the HTTP level — both are POST requests.

---

## 5. Per-Request Headers

```typescript
const { data } = await api.graphql('/graphql',
  '{ me { id name email } }',
  {},
  { headers: { 'X-Tenant': 'acme' } }
);
```

The fourth argument is `RequestOptions` — same as `api.get()` and `api.post()`. You can pass custom headers and query params.

---

## 6. Error Handling

GraphQL errors come in two forms:

**HTTP errors** (network failure, 500, 401) — these throw, just like any `api.*` call:

```typescript
try {
  const { data } = await api.graphql('/graphql', '{ products { id } }');
} catch (err) {
  // err.status, err.data, err.ok — same as api.get() errors
  if (err.status === 401) navigate('/login');
}
```

**GraphQL errors** (invalid query, resolver errors) — these return in the `errors` array with a 200 status:

```typescript
const { data, errors } = await api.graphql('/graphql',
  '{ nonExistentField }'
);

if (errors) {
  for (const err of errors) {
    console.error(err.message);
    // "Cannot query field 'nonExistentField' on type 'Query'"
  }
}
```

---

## 7. With Interceptors

All existing interceptors apply to GraphQL calls:

```typescript
// Log every GraphQL query
api.intercept('request', (config) => {
  if (config.body) {
    const body = JSON.parse(config.body);
    if (body.query) console.log('GraphQL:', body.query);
  }
  return config;
});

// Redirect on auth failure
api.intercept('response', (res) => {
  if (res.status === 401) navigate('/login');
  return res;
});
```

---

## 8. Real-World Example: Product Search

```typescript
import { api, signal, effect, html } from 'tina4js';

api.configure({ baseUrl: '/api', auth: true });

const searchTerm = signal('');
const products = signal([]);
const loading = signal(false);
const error = signal('');

async function search() {
  const term = searchTerm.value.trim();
  if (!term) return;

  loading.value = true;
  error.value = '';

  const { data, errors } = await api.graphql('/graphql',
    `query ($term: String!) {
      search_products(term: $term) { id name price image }
    }`,
    { term }
  );

  loading.value = false;

  if (errors) {
    error.value = errors[0].message;
  } else {
    products.value = data.search_products;
  }
}

const view = html`
  <div>
    <input
      type="text"
      placeholder="Search products..."
      .value=${searchTerm}
      @input=${(e) => { searchTerm.value = e.target.value; }}
      @keydown=${(e) => { if (e.key === 'Enter') search(); }}
    />
    <button @click=${search} ?disabled=${loading}>
      ${() => loading.value ? 'Searching...' : 'Search'}
    </button>
    ${() => error.value ? html`<p class="error">${error.value}</p>` : null}
    <ul>
      ${() => products.value.map(p => html`
        <li>${p.name} — $${p.price}</li>
      `)}
    </ul>
  </div>
`;
```

---

## 9. API Reference

```typescript
api.graphql<T>(
  path: string,
  query: string,
  variables?: Record<string, unknown>,
  options?: RequestOptions
): Promise<{ data: T | null; errors?: Array<{ message: string }> }>
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `string` | GraphQL endpoint (e.g. `'/graphql'`) |
| `query` | `string` | GraphQL query or mutation string |
| `variables` | `object` | Optional variables (default: `{}`) |
| `options` | `RequestOptions` | Optional `{ headers, params }` |

**Returns:** `{ data, errors }` — standard GraphQL response shape.

**Auth:** Uses the same Bearer token and formToken as all `api.*` methods.

---

## Summary

| Task | Code |
|------|------|
| Simple query | `api.graphql('/graphql', '{ products { id name } }')` |
| With variables | `api.graphql('/graphql', query, { id: 42 })` |
| Mutation | `api.graphql('/graphql', 'mutation { ... }', vars)` |
| Custom headers | `api.graphql('/graphql', query, vars, { headers: {...} })` |
| Error check | `const { data, errors } = await api.graphql(...)` |

No Apollo. No Relay. No urql. One method. Same auth. Same interceptors. Done.
