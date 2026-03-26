# GraphQL
::: tip 🔥 Hot Tips
- Auto-generate a full GraphQL API from your [ORM classes](orm.md) with a single `fromORM()` call
- Zero external dependencies — Tina4 ships its own recursive-descent parser and executor
- Register the `/graphql` endpoint in one line
- Supports queries, mutations, variables, fragments, and aliases out of the box
  :::

## Installation

Require the package via Composer:

```bash
composer require tina4stack/tina4php-graphql
```

The module requires PHP 8.1 or higher.

## Quick Start

The fastest way to get a working GraphQL API is to point it at an existing ORM class.

```php
// index.php or a bootstrap file
global $DBA;
$DBA = new \Tina4\DataSQLite3("database/app.db");

$schema = new \Tina4\GraphQLSchema();
$schema->fromORM(User::class);

\Tina4\GraphQLRoute::register($schema);
```

That single `fromORM()` call creates:

| Generated | Name | Description |
|-----------|------|-------------|
| Type | `User` | Object type with fields from public properties |
| Query | `user(id: ID)` | Fetch a single record by ID |
| Query | `users(limit: Int, offset: Int)` | Paginated list (default limit 10) |
| Mutation | `createUser(input: UserInput)` | Insert a new record |
| Mutation | `updateUser(id: ID!, input: UserInput)` | Update an existing record |
| Mutation | `deleteUser(id: ID!)` | Delete a record, returns Boolean |

You can now POST to `/graphql` and start querying.

## Setting Up the Endpoint {#endpoint}

`GraphQLRoute::register()` creates a `POST /graphql` route that reads `php://input`, executes the query, and returns JSON.

```php
// Default path
\Tina4\GraphQLRoute::register($schema);

// Custom path
\Tina4\GraphQLRoute::register($schema, "/api/graphql");
```

If you need more control (authentication, custom context, etc.), wire the route yourself:

```php
\Tina4\Post::add("/graphql", function (\Tina4\Response $response, \Tina4\Request $request) use ($schema) {
    $requestBody = file_get_contents('php://input');

    // Pass a context object to all resolvers
    $context = ['user' => $request->session['user'] ?? null];

    $graphql = new \Tina4\GraphQL($schema);
    $result = $graphql->handleRequest($requestBody, $context);

    return $response($result, HTTP_OK, APPLICATION_JSON);
});
```

## Defining a Schema Manually {#manual-schema}

When auto-generation does not fit your needs, build the schema by hand.

### Register a type

```php
$schema = new \Tina4\GraphQLSchema();

// Define an OBJECT type with named fields
$productType = new \Tina4\GraphQLType('Product', 'OBJECT', [
    'id'    => ['type' => 'ID'],
    'name'  => ['type' => 'String'],
    'price' => ['type' => 'Float'],
    'inStock' => ['type' => 'Boolean'],
]);

$schema->addType($productType);
```

### Register a query

```php
$schema->addQuery('product', [
    'type' => 'Product',
    'args' => [
        'id' => ['type' => 'ID'],
    ],
    'resolve' => function ($root, $args, $context) {
        // Return an associative array matching the type fields
        return [
            'id' => $args['id'],
            'name' => 'Widget',
            'price' => 9.99,
            'inStock' => true,
        ];
    },
]);
```

### Register a mutation

```php
$schema->addMutation('updateProductPrice', [
    'type' => 'Product',
    'args' => [
        'id'    => ['type' => 'ID!'],
        'price' => ['type' => 'Float!'],
    ],
    'resolve' => function ($root, $args, $context) {
        // your update logic here
        return [
            'id' => $args['id'],
            'name' => 'Widget',
            'price' => $args['price'],
            'inStock' => true,
        ];
    },
]);
```

## Auto-Generating Schema from ORM {#from-orm}

This is the killer feature. Given a Tina4 ORM class, `fromORM()` introspects its public properties, maps PHP types to GraphQL scalars, and registers a full set of CRUD queries and mutations automatically.

### How it works

1. Public properties on the ORM class become fields on the GraphQL type.
2. PHP type hints (`int`, `float`, `bool`, `string`) are mapped to `Int`, `Float`, `Boolean`, `String`. Untyped properties default to `String`.
3. ORM meta-properties (`$tableName`, `$primaryKey`, `$fieldMapping`, etc.) are excluded automatically.
4. The class short name is used as the type name. The lower-camelCase form is used for query names.

### Example ORM class

```php
class Product extends \Tina4\ORM
{
    public $tableName = 'product';
    public int $id;
    public string $name;
    public float $price;
    public int $categoryId;
}
```

### Register it

```php
$schema = new \Tina4\GraphQLSchema();
$schema->fromORM(Product::class);
$schema->fromORM(Category::class);

\Tina4\GraphQLRoute::register($schema);
```

You can call `fromORM()` multiple times to register as many ORM classes as you like on the same schema.

### Type mapping reference

| PHP Type | GraphQL Type |
|----------|-------------|
| `int`, `integer` | `Int` |
| `float`, `double` | `Float` |
| `bool`, `boolean` | `Boolean` |
| `string` | `String` |
| _(no type hint)_ | `String` |

## Writing Queries {#queries}

Send a JSON POST request to your endpoint:

```json
{
  "query": "{ users(limit: 5) { id name price } }"
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

```php
function ($root, array $args, mixed $context): mixed
```

| Parameter | Description |
|-----------|-------------|
| `$root` | The parent value. `null` for root-level fields. |
| `$args` | Arguments passed in the query, with variables already resolved. |
| `$context` | Whatever you passed as context when calling `execute()` or `handleRequest()`. |

For nested fields, the executor resolves automatically by reading array keys or object properties from the parent value. You only need explicit resolvers for root-level queries and mutations.

```php
$schema->addQuery('topProducts', [
    'type' => '[Product]',
    'args' => ['limit' => ['type' => 'Int']],
    'resolve' => function ($root, $args, $context) {
        $limit = $args['limit'] ?? 5;
        return (new Product())
            ->select("*")
            ->orderBy("sales desc")
            ->asArray();
    },
]);
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

## GraphQL Type System {#types}

The `GraphQLType` class supports scalars, objects, lists, and non-null wrappers.

### Built-in scalars

`String`, `Int`, `Float`, `Boolean`, `ID`

### Creating types programmatically

```php
// Scalar
$idType = \Tina4\GraphQLType::scalar('ID');

// Object
$type = new \Tina4\GraphQLType('Category', 'OBJECT', [
    'id'   => ['type' => 'ID'],
    'name' => ['type' => 'String'],
]);

// List wrapper
$listType = \Tina4\GraphQLType::listOf($type);

// Non-null wrapper
$required = \Tina4\GraphQLType::nonNull($idType);
```

### Using type notation in definitions

When registering queries and mutations, types are referenced by string notation:

| Notation | Meaning |
|----------|---------|
| `String` | Nullable string |
| `String!` | Non-null string |
| `[Product]` | Nullable list of products |
| `[Product!]!` | Non-null list of non-null products |

## Programmatic Usage {#programmatic}

You do not have to use the HTTP endpoint. The `GraphQL` class can be called directly in your code:

```php
$schema = new \Tina4\GraphQLSchema();
// ... register types, queries, mutations ...

$graphql = new \Tina4\GraphQL($schema);
$result = $graphql->execute('{ users(limit: 3) { id name } }', [], $context);

// $result = ['data' => ['users' => [...]]]
```

Pass variables as the second argument:

```php
$result = $graphql->execute(
    'query ($id: ID) { user(id: $id) { id name } }',
    ['id' => '42']
);
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

If the query itself fails to parse, the response will have `data: null` and the parser error in `errors`.

## Full Working Example {#full-example}

```php
// ORM classes
class Category extends \Tina4\ORM
{
    public $tableName = 'category';
    public int $id;
    public string $name;
}

class Product extends \Tina4\ORM
{
    public $tableName = 'product';
    public int $id;
    public string $name;
    public float $price;
    public int $categoryId;
}

// Bootstrap
global $DBA;
$DBA = new \Tina4\DataSQLite3("database/shop.db");

$schema = new \Tina4\GraphQLSchema();
$schema->fromORM(Category::class);
$schema->fromORM(Product::class);

// Add a custom query alongside the auto-generated ones
$schema->addQuery('cheapProducts', [
    'type' => '[Product]',
    'args' => ['maxPrice' => ['type' => 'Float']],
    'resolve' => function ($root, $args) {
        $max = $args['maxPrice'] ?? 10.0;
        return (new Product())
            ->select("*")
            ->where("price <= ?", [$max])
            ->asArray();
    },
]);

\Tina4\GraphQLRoute::register($schema);
```

Now you can query:

```graphql
{
  # Auto-generated
  categories(limit: 100) { id name }

  # Auto-generated
  product(id: "7") { id name price }

  # Custom
  cheapProducts(maxPrice: 5.00) { id name price }
}
```

## Further Reading

- [ORM](orm.md) — the ORM classes that power `fromORM()`
- [Basic Routing](basic-routing.md) — how Tina4 routing works under the hood
- [REST API](rest-api.md) — for traditional REST-style endpoints
