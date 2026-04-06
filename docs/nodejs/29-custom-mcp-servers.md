# Chapter 28: Building Custom MCP Servers

## 1. Beyond Dev Tools

Chapter 27 covered the built-in MCP server that ships with Tina4. It exposes framework internals for AI-assisted development. This chapter goes further: you build your own MCP servers that expose your application's business logic.

A CRM system exposes customer lookup. An accounting system exposes invoice queries. A warehouse system exposes inventory checks. Any domain logic that an AI assistant should access becomes an MCP tool.

---

## 2. Creating an MCP Server

Import `McpServer` and create an instance on any path:

```typescript
import { McpServer } from "@tina4/core";

const mcp = new McpServer("/api/my-tools", "My App Tools", "1.0.0");
```

The server registers HTTP endpoints at:
- `POST /api/my-tools/message` -- JSON-RPC message handler
- `GET /api/my-tools/sse` -- SSE endpoint for client discovery

Register it with the router in your server setup:

```typescript
mcp.registerRoutes(router);
```

---

## 3. Registering Tools with mcpTool

The `mcpTool` function registers a handler as an MCP tool. Parameter metadata becomes the input schema:

```typescript
import { McpServer, mcpTool, schemaFromParams } from "@tina4/core";

const mcp = new McpServer("/crm/mcp", "CRM Tools");

mcpTool("lookup_customer", "Find a customer by email", mcp, [
  { name: "email", type: "string" },
])((args) => {
  return db.fetchOne("SELECT * FROM customers WHERE email = ?", [args.email]);
});

mcpTool("recent_orders", "Get recent orders for a customer", mcp, [
  { name: "customer_id", type: "integer" },
  { name: "limit", type: "integer", default: 10 },
])((args) => {
  return db.fetch(
    "SELECT * FROM orders WHERE customer_id = ? ORDER BY created_at DESC",
    [args.customer_id], { limit: (args.limit as number) || 10 }
  );
});
```

The registration extracts:
- **Parameter names** from the params list
- **Types** from the type field (`"string"`, `"integer"`, `"boolean"`, etc.)
- **Required vs optional** -- parameters with defaults are optional
- **Description** from the description argument

An AI assistant sees these tools and their schemas:

```json
{
  "name": "lookup_customer",
  "description": "Find a customer by email",
  "inputSchema": {
    "type": "object",
    "properties": {
      "email": {"type": "string"}
    },
    "required": ["email"]
  }
}
```

---

## 4. Registering Resources with mcpResource

Resources are read-only data endpoints. They expose reference data that AI assistants can browse:

```typescript
import { mcpResource } from "@tina4/core";

mcpResource("crm://product-catalog", "All active products", "application/json", mcp)(
  () => db.fetch("SELECT id, name, price, category FROM products WHERE active = 1")
);

mcpResource("crm://tax-rates", "Current tax rates by region", "application/json", mcp)(
  () => db.fetch("SELECT region, rate FROM tax_rates")
);
```

Resources are accessed via `resources/list` and `resources/read` in the MCP protocol.

---

## 5. Class-Based MCP Services

Group related tools into a service class. Register each method as a tool:

```typescript
import { McpServer, schemaFromParams } from "@tina4/core";

const mcp = new McpServer("/accounting/mcp", "Accounting Tools");

class AccountingService {
  constructor(private db: any) {}

  lookup(invoiceNo: string) {
    return this.db.fetchOne(
      "SELECT * FROM invoices WHERE invoice_no = ?", [invoiceNo]
    );
  }

  balances(minAmount = 0.0) {
    return this.db.fetch(
      "SELECT * FROM invoices WHERE paid = 0 AND total >= ?", [minAmount]
    );
  }

  summary(year: number, month: number) {
    return this.db.fetchOne(
      "SELECT SUM(total) as revenue, COUNT(*) as invoice_count " +
      "FROM invoices WHERE strftime('%Y', created_at) = ? " +
      "AND strftime('%m', created_at) = ?",
      [String(year), String(month).padStart(2, "0")]
    );
  }
}

const svc = new AccountingService(db);

mcp.registerTool("invoice_lookup",
  (args) => svc.lookup(args.invoice_no as string),
  "Find an invoice by number",
  schemaFromParams([{ name: "invoice_no", type: "string" }])
);

mcp.registerTool("outstanding_balances",
  (args) => svc.balances((args.min_amount as number) || 0),
  "List all unpaid invoices",
  schemaFromParams([{ name: "min_amount", type: "number", default: 0.0 }])
);

mcp.registerTool("monthly_summary",
  (args) => svc.summary(args.year as number, args.month as number),
  "Revenue summary for a month",
  schemaFromParams([{ name: "year", type: "integer" }, { name: "month", type: "integer" }])
);
```

---

## 6. Securing MCP Endpoints

By default, developer MCP servers are public. Add authentication using Tina4 middleware:

```typescript
// Secure the MCP routes via middleware
import { secured } from "@tina4/core";

// Apply auth middleware before registering routes
mcp.registerRoutes(router); // then protect the path with middleware
```

Or check the bearer token inside individual tools:

```typescript
import { Auth } from "@tina4/core";

mcp.registerTool("sensitive_data",
  (args) => {
    const payload = Auth.validToken(args.token as string, secret);
    if (!payload) return { error: "Unauthorized" };
    return db.fetch("SELECT * FROM sensitive_table");
  },
  "Access restricted data",
  schemaFromParams([{ name: "token", type: "string" }])
);
```

---

## 7. Testing MCP Tools

Test tool functions directly, or test via the MCP protocol:

```typescript
// Test the tool function directly
function testLookupCustomer() {
  const result = db.fetchOne("SELECT * FROM customers WHERE email = ?", ["alice@example.com"]);
  assert(result !== null);
  assert(result.email === "alice@example.com");
}

// Test via MCP protocol
function testMcpToolCall() {
  const resp = JSON.parse(mcp.handleMessage({
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: {
      name: "lookup_customer",
      arguments: { email: "alice@example.com" },
    },
  }));
  assert("result" in resp);
  const content = resp.result.content[0].text;
  assert(content.toLowerCase().includes("alice"));
}
```

---

## 8. Complete Example: CRM MCP Server

Here is a full working example -- a CRM system with customer, order, and product tools:

```typescript
// src/routes/mcp/setup.ts
import { McpServer, mcpTool, mcpResource, schemaFromParams } from "@tina4/core";
import { initDatabase } from "@tina4/orm";

const db = await initDatabase({ url: "sqlite:///crm.db" });

// Create MCP server
const crmMcp = new McpServer("/crm/mcp", "CRM Assistant", "1.0.0");

// Tools
mcpTool("find_customer", "Search customers by name or email", crmMcp, [
  { name: "query", type: "string" },
])((args) => {
  const q = args.query as string;
  return db.fetch(
    "SELECT * FROM customers WHERE name LIKE ? OR email LIKE ?",
    [`%${q}%`, `%${q}%`]
  );
});

mcpTool("customer_orders", "Get all orders for a customer", crmMcp, [
  { name: "customer_id", type: "integer" },
])((args) => {
  return db.fetch(
    "SELECT o.*, GROUP_CONCAT(oi.product_name) as items " +
    "FROM orders o LEFT JOIN order_items oi ON o.id = oi.order_id " +
    "WHERE o.customer_id = ? GROUP BY o.id ORDER BY o.created_at DESC",
    [args.customer_id]
  );
});

mcpTool("create_note", "Add a note to a customer record", crmMcp, [
  { name: "customer_id", type: "integer" },
  { name: "note", type: "string" },
])((args) => {
  db.execute("INSERT INTO customer_notes (customer_id, note) VALUES (?, ?)",
    [args.customer_id, args.note]);
  return { success: true };
});

// Resources
mcpResource("crm://products", "Product catalog", "application/json", crmMcp)(
  () => db.fetch("SELECT * FROM products WHERE active = 1")
);

mcpResource("crm://stats", "CRM statistics", "application/json", crmMcp)(() => {
  const customers = db.fetch("SELECT COUNT(*) as count FROM customers");
  const orders = db.fetch("SELECT COUNT(*) as count, SUM(total) as revenue FROM orders");
  return {
    customers: customers[0]?.count ?? 0,
    orders: orders[0]?.count ?? 0,
    revenue: orders[0]?.revenue ?? 0,
  };
});

// Register routes
crmMcp.registerRoutes(router);

export { crmMcp };
```

Connect Claude Code to `http://localhost:7148/crm/mcp/sse` and ask:

> "Find all customers named Smith and show their recent orders"

The AI calls `find_customer` with `query: "Smith"`, then `customer_orders` for each result. No custom API needed. The MCP protocol handles it.

---

## 9. Best Practices

1. **One server per domain** -- CRM tools on `/crm/mcp`, accounting on `/accounting/mcp`
2. **Keep tools focused** -- one query per tool, not a Swiss-army-knife tool
3. **Use param metadata** -- types and defaults become the schema. An AI assistant cannot call a tool correctly without knowing the parameter types
4. **Return structured data** -- objects and arrays, not formatted strings. Let the AI format for the user
5. **Secure production endpoints** -- use middleware for any MCP server that runs outside localhost
6. **Test tools directly** -- call the TypeScript function in your test suite, not just through the MCP protocol
