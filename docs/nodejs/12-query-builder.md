# Chapter 12: QueryBuilder

## 1. Why a Query Builder?

In Chapter 5 you wrote raw SQL. In Chapter 6 you used ORM models with `select()`. Both work. Both have limits.

Raw SQL is powerful but brittle. Concatenate a WHERE clause wrong and you get a syntax error -- or worse, a SQL injection. The ORM's `select()` method handles simple cases, but building dynamic queries with optional filters, joins, and aggregations turns into a mess of string concatenation and empty-parameter guards.

The QueryBuilder sits between raw SQL and the ORM. It gives you a fluent, chainable API that builds correct SQL. You write TypeScript. It writes SQL. Every method returns `this`, so you chain calls in any order. When you are done, call `get()` to execute or `toSql()` to inspect.

---

## 2. Creating a QueryBuilder

There are two entry points.

### Standalone: QueryBuilder.from()

Import `QueryBuilder` from the ORM package and call the static `from()` factory:

```typescript
import { QueryBuilder } from "tina4-nodejs";

const users = QueryBuilder.from("users", db)
    .select("id", "name", "email")
    .where("active = ?", [1])
    .orderBy("name ASC")
    .limit(10)
    .get();
```

The first argument is the table name. The second is the database adapter -- the same `db` object you get from `Database.create()` or the globally initialised adapter. If you omit the adapter, the QueryBuilder falls back to the global adapter registered by `initDatabase()`.

### From an ORM Model: Model.query()

Every model that extends `BaseModel` has a static `query()` method. It returns a QueryBuilder pre-configured with the model's table name and database adapter:

```typescript
import { User } from "../orm/User";

const activeUsers = User.query()
    .where("active = ?", [1])
    .orderBy("name ASC")
    .get();
```

No need to pass the table name or database. The model knows both.

---

## 3. Selecting Columns

By default, the QueryBuilder selects all columns (`*`). Use `select()` to pick specific columns:

```typescript
QueryBuilder.from("products", db)
    .select("id", "name", "price")
    .get();
```

This generates:

```sql
SELECT id, name, price FROM products
```

Pass as many column names as you need. Each is a separate string argument, not a comma-separated string. If you call `select()` with no arguments, it keeps the default `*`.

You can also use expressions:

```typescript
QueryBuilder.from("orders", db)
    .select("customer_id", "SUM(total) as revenue")
    .groupBy("customer_id")
    .get();
```

---

## 4. WHERE Conditions

### where() -- AND

Add a condition with `where()`. Use `?` as the placeholder for parameters:

```typescript
QueryBuilder.from("users", db)
    .where("age > ?", [18])
    .where("active = ?", [1])
    .get();
```

This generates:

```sql
SELECT * FROM users WHERE age > ? AND active = ?
```

With parameters `[18, 1]`.

Multiple `where()` calls are joined with AND. The first call starts the WHERE clause. Every subsequent call adds `AND condition`.

### orWhere() -- OR

Use `orWhere()` to add an OR condition:

```typescript
QueryBuilder.from("products", db)
    .where("category = ?", ["Electronics"])
    .orWhere("category = ?", ["Books"])
    .get();
```

This generates:

```sql
SELECT * FROM products WHERE category = ? OR category = ?
```

### Combining AND and OR

```typescript
QueryBuilder.from("products", db)
    .where("price < ?", [100])
    .where("in_stock = ?", [1])
    .orWhere("featured = ?", [1])
    .get();
```

Generates:

```sql
SELECT * FROM products WHERE price < ? AND in_stock = ? OR featured = ?
```

If you need grouping with parentheses, write the grouped expression as a single condition:

```typescript
QueryBuilder.from("products", db)
    .where("price < ?", [100])
    .where("(category = ? OR category = ?)", ["Electronics", "Books"])
    .get();
```

Generates:

```sql
SELECT * FROM products WHERE price < ? AND (category = ? OR category = ?)
```

---

## 5. Joins

### Inner Join

```typescript
QueryBuilder.from("orders", db)
    .select("orders.id", "users.name", "orders.total")
    .join("users", "users.id = orders.user_id")
    .get();
```

Generates:

```sql
SELECT orders.id, users.name, orders.total FROM orders INNER JOIN users ON users.id = orders.user_id
```

### Left Join

```typescript
QueryBuilder.from("users", db)
    .select("users.name", "orders.total")
    .leftJoin("orders", "orders.user_id = users.id")
    .get();
```

Generates:

```sql
SELECT users.name, orders.total FROM users LEFT JOIN orders ON orders.user_id = users.id
```

### Multiple Joins

Chain as many joins as you need:

```typescript
QueryBuilder.from("orders", db)
    .select("orders.id", "users.name", "products.name as product_name")
    .join("users", "users.id = orders.user_id")
    .join("order_items", "order_items.order_id = orders.id")
    .join("products", "products.id = order_items.product_id")
    .where("orders.status = ?", ["completed"])
    .get();
```

---

## 6. Grouping and Aggregation

### groupBy()

```typescript
QueryBuilder.from("orders", db)
    .select("status", "COUNT(*) as total")
    .groupBy("status")
    .get();
```

Generates:

```sql
SELECT status, COUNT(*) as total FROM orders GROUP BY status
```

Call `groupBy()` multiple times to group by multiple columns:

```typescript
QueryBuilder.from("orders", db)
    .select("status", "customer_id", "SUM(total) as revenue")
    .groupBy("status")
    .groupBy("customer_id")
    .get();
```

### having()

Filter grouped results with `having()`:

```typescript
QueryBuilder.from("products", db)
    .select("category", "AVG(price) as avg_price")
    .groupBy("category")
    .having("AVG(price) > ?", [50])
    .get();
```

Generates:

```sql
SELECT category, AVG(price) as avg_price FROM products GROUP BY category HAVING AVG(price) > ?
```

Multiple `having()` calls are joined with AND.

---

## 7. Ordering

```typescript
QueryBuilder.from("products", db)
    .orderBy("price DESC")
    .get();
```

Generates:

```sql
SELECT * FROM products ORDER BY price DESC
```

Call `orderBy()` multiple times for multi-column sorting:

```typescript
QueryBuilder.from("products", db)
    .orderBy("category ASC")
    .orderBy("price DESC")
    .get();
```

Generates:

```sql
SELECT * FROM products ORDER BY category ASC, price DESC
```

---

## 8. Limit and Offset

### Limit Only

```typescript
QueryBuilder.from("products", db)
    .limit(10)
    .get();
```

### Limit with Offset

```typescript
QueryBuilder.from("products", db)
    .limit(10, 20)
    .get();
```

The first argument is the maximum number of rows. The second is the number of rows to skip. This is how you implement pagination:

```typescript
const page = 3;
const perPage = 25;
const offset = (page - 1) * perPage;

const products = QueryBuilder.from("products", db)
    .orderBy("name ASC")
    .limit(perPage, offset)
    .get();
```

---

## 9. Executing Queries

### get\<T\>() -- All Rows

`get()` executes the query and returns an array of row objects:

```typescript
const users = QueryBuilder.from("users", db)
    .where("active = ?", [1])
    .get();
// users: Record<string, unknown>[]
```

Use the TypeScript generic to type the result:

```typescript
interface User {
    id: number;
    name: string;
    email: string;
    active: boolean;
}

const users = QueryBuilder.from("users", db)
    .where("active = ?", [1])
    .get<User>();
// users: User[]
```

The generic is optional. Without it, rows are typed as `Record<string, unknown>[]`.

### first\<T\>() -- Single Row

`first()` returns one row or `null`:

```typescript
const user = QueryBuilder.from("users", db)
    .where("email = ?", ["alice@example.com"])
    .first<User>();

if (!user) {
    // Not found
}
```

### count() -- Row Count

`count()` returns the number of matching rows without fetching the data:

```typescript
const total = QueryBuilder.from("users", db)
    .where("active = ?", [1])
    .count();
// total: number
```

It rewrites the query internally to `SELECT COUNT(*) as cnt` and extracts the value.

### exists() -- Boolean Check

`exists()` returns `true` if at least one row matches:

```typescript
const hasAdmin = QueryBuilder.from("users", db)
    .where("role = ?", ["admin"])
    .exists();
// hasAdmin: boolean
```

---

## 10. Inspecting SQL with toSql()

Call `toSql()` to get the generated SQL string without executing the query. Useful for debugging:

```typescript
const sql = QueryBuilder.from("users", db)
    .select("id", "name")
    .where("active = ?", [1])
    .orderBy("name ASC")
    .limit(10)
    .toSql();

console.log(sql);
// SELECT id, name FROM users WHERE active = ? ORDER BY name ASC
```

Note that `toSql()` returns the SQL with `?` placeholders. The actual parameter values are bound at execution time by the database adapter.

The `LIMIT` and `OFFSET` clauses are not included in `toSql()` output -- they are passed directly to the adapter's `fetch()` method as separate arguments.

---

## 11. Using QueryBuilder in Route Handlers

The QueryBuilder pairs naturally with route handlers and `res.json()`:

### List Endpoint with Filters

```typescript
// src/routes/api/products/get.ts
import { QueryBuilder } from "tina4-nodejs";
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const category = req.query.category;
    const minPrice = req.query.min_price;
    const sort = req.query.sort ?? "name";
    const page = parseInt(req.query.page ?? "1", 10);
    const perPage = parseInt(req.query.per_page ?? "20", 10);

    const qb = QueryBuilder.from("products");

    if (category) {
        qb.where("category = ?", [category]);
    }

    if (minPrice) {
        qb.where("price >= ?", [parseFloat(minPrice)]);
    }

    const allowedSorts = ["name", "price", "category", "created_at"];
    const safeSort = allowedSorts.includes(sort) ? sort : "name";

    const total = qb.count();
    const products = qb
        .orderBy(`${safeSort} ASC`)
        .limit(perPage, (page - 1) * perPage)
        .get();

    return res.json({ products, total, page, per_page: perPage });
}
```

### Single Record Lookup

```typescript
// src/routes/api/users/[id]/get.ts
import { QueryBuilder } from "tina4-nodejs";
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const user = QueryBuilder.from("users")
        .where("id = ?", [req.params.id])
        .first();

    if (!user) {
        return res.status(404).json({ error: "User not found" });
    }

    return res.json(user);
}
```

### Dashboard with Aggregation

```typescript
// src/routes/api/dashboard/get.ts
import { QueryBuilder } from "tina4-nodejs";
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const totalUsers = QueryBuilder.from("users").count();

    const revenueByCategory = QueryBuilder.from("orders")
        .select("category", "SUM(total) as revenue", "COUNT(*) as order_count")
        .join("order_items", "order_items.order_id = orders.id")
        .join("products", "products.id = order_items.product_id")
        .where("orders.status = ?", ["completed"])
        .groupBy("category")
        .having("SUM(total) > ?", [0])
        .orderBy("revenue DESC")
        .get();

    const recentOrders = QueryBuilder.from("orders")
        .select("orders.id", "users.name as customer", "orders.total", "orders.created_at")
        .join("users", "users.id = orders.user_id")
        .orderBy("orders.created_at DESC")
        .limit(5)
        .get();

    return res.json({
        total_users: totalUsers,
        revenue_by_category: revenueByCategory,
        recent_orders: recentOrders,
    });
}
```

---

## 12. QueryBuilder vs ORM select()

Both query the database. When do you use which?

| Scenario | Use |
|----------|-----|
| Simple CRUD on a single model | ORM `select()` |
| Need `toDict()` / `toObject()` on results | ORM `select()` |
| Eager loading relationships | ORM `select()` with `include` |
| Multi-table joins | QueryBuilder |
| Aggregations (SUM, COUNT, AVG) | QueryBuilder |
| Complex dynamic filters | QueryBuilder |
| Sub-selects in columns | QueryBuilder |
| You want typed results without a model | QueryBuilder with `get<T>()` |

They are not mutually exclusive. Use ORM models for data that maps cleanly to a single table. Use the QueryBuilder when you need to reach across tables or aggregate.

---

## 13. Exercise: Sales Report API

Build a sales report endpoint using the QueryBuilder.

### Setup

Assume these tables exist:

- `customers` -- id, name, email, region, created_at
- `orders` -- id, customer_id, status, total, created_at
- `order_items` -- id, order_id, product_id, quantity, unit_price
- `products` -- id, name, category, price

### Requirements

Create three route files:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/reports/revenue` | Revenue by product category with optional date range |
| `GET` | `/api/reports/top-customers` | Top 10 customers by total spend |
| `GET` | `/api/reports/summary` | Order count, total revenue, average order value |

Query parameters for `/api/reports/revenue`:

- `after` -- only orders after this date (e.g. `2025-01-01`)
- `before` -- only orders before this date
- `min_revenue` -- only categories with revenue above this amount

---

## 14. Solution

### Revenue by Category

Create `src/routes/api/reports/revenue/get.ts`:

```typescript
import { QueryBuilder } from "tina4-nodejs";
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const qb = QueryBuilder.from("order_items")
        .select(
            "products.category",
            "SUM(order_items.quantity * order_items.unit_price) as revenue",
            "SUM(order_items.quantity) as units_sold",
            "COUNT(DISTINCT orders.id) as order_count"
        )
        .join("orders", "orders.id = order_items.order_id")
        .join("products", "products.id = order_items.product_id")
        .where("orders.status = ?", ["completed"]);

    if (req.query.after) {
        qb.where("orders.created_at >= ?", [req.query.after]);
    }

    if (req.query.before) {
        qb.where("orders.created_at < ?", [req.query.before]);
    }

    qb.groupBy("products.category");

    if (req.query.min_revenue) {
        qb.having("SUM(order_items.quantity * order_items.unit_price) > ?", [
            parseFloat(req.query.min_revenue),
        ]);
    }

    const results = qb.orderBy("revenue DESC").get();

    return res.json({ categories: results });
}
```

### Top Customers

Create `src/routes/api/reports/top-customers/get.ts`:

```typescript
import { QueryBuilder } from "tina4-nodejs";
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const customers = QueryBuilder.from("orders")
        .select(
            "customers.id",
            "customers.name",
            "customers.email",
            "customers.region",
            "SUM(orders.total) as total_spend",
            "COUNT(orders.id) as order_count"
        )
        .join("customers", "customers.id = orders.customer_id")
        .where("orders.status = ?", ["completed"])
        .groupBy("customers.id")
        .groupBy("customers.name")
        .groupBy("customers.email")
        .groupBy("customers.region")
        .orderBy("total_spend DESC")
        .limit(10)
        .get();

    return res.json({ top_customers: customers });
}
```

### Summary

Create `src/routes/api/reports/summary/get.ts`:

```typescript
import { QueryBuilder } from "tina4-nodejs";
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const stats = QueryBuilder.from("orders")
        .select(
            "COUNT(*) as order_count",
            "SUM(total) as total_revenue",
            "AVG(total) as avg_order_value"
        )
        .where("status = ?", ["completed"])
        .first();

    const ordersByStatus = QueryBuilder.from("orders")
        .select("status", "COUNT(*) as count")
        .groupBy("status")
        .orderBy("count DESC")
        .get();

    const hasOrders = QueryBuilder.from("orders").exists();

    return res.json({
        summary: stats,
        by_status: ordersByStatus,
        has_orders: hasOrders,
    });
}
```

### Testing It

```bash
# Revenue by category
curl "http://localhost:7148/api/reports/revenue"

# Revenue with date range and minimum
curl "http://localhost:7148/api/reports/revenue?after=2025-01-01&before=2026-01-01&min_revenue=1000"

# Top customers
curl "http://localhost:7148/api/reports/top-customers"

# Summary
curl "http://localhost:7148/api/reports/summary"
```

---

## 15. NoSQL: MongoDB Queries

The QueryBuilder can generate MongoDB-compatible query documents with `toMongo()`. This returns an object containing the filter, projection, sort, limit, and skip -- ready to pass to the MongoDB Node.js driver.

### Operator Mapping

| SQL Operator | MongoDB Operator |
|-------------|-----------------|
| `=` | Exact match |
| `!=` | `$ne` |
| `>` | `$gt` |
| `<` | `$lt` |
| `>=` | `$gte` |
| `<=` | `$lte` |
| `LIKE` | `$regex` |
| `IN` | `$in` |
| `IS NULL` | `$exists: false` |
| `IS NOT NULL` | `$exists: true` |

### Example

```typescript
const query = QueryBuilder.from("users")
    .select("name", "email")
    .where("age > ?", [25])
    .where("status = ?", ["active"])
    .orderBy("name ASC")
    .limit(10)
    .offset(5);

const mongo = query.toMongo();
```

The returned object:

```typescript
{
    filter: { age: { $gt: 25 }, status: "active" },
    projection: { name: 1, email: 1 },
    sort: { name: 1 },
    limit: 10,
    skip: 5,
}
```

Pass it directly to the MongoDB driver:

```typescript
const collection = db.collection("users");
const cursor = collection.find(mongo.filter, {
    projection: mongo.projection,
    sort: mongo.sort,
    limit: mongo.limit,
    skip: mongo.skip,
});
```

---

## 16. Gotchas

### 1. Forgetting the Database Adapter

**Problem:** You call `QueryBuilder.from("users").get()` and get `"QueryBuilder: No database adapter provided."`.

**Cause:** No database adapter was passed to `from()` and no global adapter has been initialised.

**Fix:** Either pass the adapter explicitly -- `QueryBuilder.from("users", db)` -- or ensure `initDatabase()` has been called before any queries run. When Tina4 boots your server, the global adapter is initialised automatically from `DATABASE_URL`.

### 2. Parameter Order Matters

**Problem:** Your WHERE clause has three `?` placeholders but the results are wrong.

**Cause:** Parameters are collected in the order you call `where()` and `orWhere()`. If you add conditions in one order but pass parameters assuming a different order, values bind to the wrong placeholders.

**Fix:** Each `where()` call takes its own parameter array. The QueryBuilder concatenates them in call order. Keep the parameters next to their condition:

```typescript
// Correct
qb.where("age > ?", [18]).where("country = ?", ["ZA"]);

// Wrong -- do not batch parameters separately from conditions
```

### 3. toSql() Does Not Include LIMIT

**Problem:** You call `toSql()` and the output has no LIMIT clause, but `get()` returns limited rows.

**Cause:** LIMIT and OFFSET are passed to the database adapter's `fetch()` method as separate arguments, not appended to the SQL string.

**Fix:** This is by design. The adapter handles LIMIT/OFFSET according to the database engine's dialect. Use `toSql()` for debugging the WHERE, JOIN, and ORDER BY clauses.

### 4. Reusing a QueryBuilder

**Problem:** You call `count()` and then `get()` on the same QueryBuilder, but the results are inconsistent.

**Cause:** `count()` temporarily replaces the selected columns with `COUNT(*)` and restores them. This is safe for a single call, but interleaving multiple execution methods on the same builder can produce unexpected SQL if you modify the builder between calls.

**Fix:** For separate queries, create separate builders. Use `QueryBuilder.from()` or `Model.query()` fresh for each independent query.

### 5. Mixing QueryBuilder with ORM select()

**Problem:** You expect `get()` to return model instances with `toDict()`.

**Cause:** The QueryBuilder returns plain objects (`Record<string, unknown>` or your generic type `T`). It does not return model instances.

**Fix:** Use `get<T>()` with an interface to type the results. If you need model methods like `toDict()`, `save()`, or relationship loading, use the ORM's `select()` method instead.

### 6. OR Without AND

**Problem:** You start with `orWhere()` instead of `where()` and the query behaves unexpectedly.

**Cause:** The first condition in the WHERE clause ignores the connector (AND/OR). Starting with `orWhere()` works syntactically but reads misleadingly.

**Fix:** Always start with `where()` for the first condition. Use `orWhere()` for subsequent alternatives.
