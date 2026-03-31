# Chapter 28: Building Custom MCP Servers

## 1. Beyond Dev Tools

Chapter 27 covered the built-in MCP server that ships with Tina4. It exposes framework internals for AI-assisted development. This chapter goes further: you build your own MCP servers that expose your application's business logic.

A CRM system exposes customer lookup. An accounting system exposes invoice queries. A warehouse system exposes inventory checks. Any domain logic that an AI assistant should access becomes an MCP tool.

---

## 2. Creating an MCP Server

Import `McpServer` and create an instance on any path:

```typescript
import { McpServer } from "tina4-nodejs/mcp";

const mcp = new McpServer("/api/my-tools", { name: "My App Tools", version: "1.0.0" });
```

The server registers HTTP endpoints at:
- `POST /api/my-tools/message` -- JSON-RPC message handler
- `GET /api/my-tools/sse` -- SSE endpoint for client discovery

Register it with the router in `app.ts` before `run()`:

```typescript
mcp.registerRoutes(router);
```

---

## 3. Registering Tools with @mcpTool

The `@mcpTool` decorator turns a method into an MCP tool. Type annotations become the input schema automatically:

```typescript
import { McpServer, mcpTool } from "tina4-nodejs/mcp";

const mcp = new McpServer("/crm/mcp", { name: "CRM Tools" });

class CrmTools {
  @mcpTool("lookup_customer", { description: "Find a customer by email", server: mcp })
  async lookupCustomer(email: string): Promise<Record<string, unknown> | null> {
    return await db.fetchOne("SELECT * FROM customers WHERE email = ?", [email]);
  }

  @mcpTool("recent_orders", { description: "Get recent orders for a customer", server: mcp })
  async recentOrders(customerId: number, limit: number = 10): Promise<Record<string, unknown>[]> {
    const result = await db.fetch(
      "SELECT * FROM orders WHERE customer_id = ? ORDER BY created_at DESC",
      [customerId], { limit }
    );
    return result.toArray();
  }
}
```

The decorator extracts:
- **Parameter names** from the method signature
- **Types** from type annotations (`string` -> `"string"`, `number` -> `"integer"`, etc.)
- **Required vs optional** -- parameters with defaults are optional
- **Description** from the `description` option or the JSDoc comment

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

## 4. Registering Resources with @mcpResource

Resources are read-only data endpoints. They expose reference data that AI assistants can browse:

```typescript
import { mcpResource } from "tina4-nodejs/mcp";

class CrmResources {
  @mcpResource("crm://product-catalog", { description: "All active products", server: mcp })
  async productCatalog(): Promise<Record<string, unknown>[]> {
    return (await db.fetch("SELECT id, name, price, category FROM products WHERE active = 1")).toArray();
  }

  @mcpResource("crm://tax-rates", { description: "Current tax rates by region", server: mcp })
  async taxRates(): Promise<Record<string, unknown>[]> {
    return (await db.fetch("SELECT region, rate FROM tax_rates")).toArray();
  }
}
```

Resources are accessed via `resources/list` and `resources/read` in the MCP protocol.

---

## 5. Class-Based MCP Services

Group related tools into a service class. Each method with `@mcpTool` becomes a tool:

```typescript
import { McpServer, mcpTool } from "tina4-nodejs/mcp";

const mcp = new McpServer("/accounting/mcp", { name: "Accounting Tools" });

class AccountingService {
  private db: Database;

  constructor(db: Database) {
    this.db = db;
  }

  @mcpTool("invoice_lookup", { description: "Find an invoice by number", server: mcp })
  async lookup(invoiceNo: string): Promise<Record<string, unknown> | null> {
    return await this.db.fetchOne(
      "SELECT * FROM invoices WHERE invoice_no = ?", [invoiceNo]
    );
  }

  @mcpTool("outstanding_balances", { description: "List all unpaid invoices", server: mcp })
  async balances(minAmount: number = 0.0): Promise<Record<string, unknown>[]> {
    return (await this.db.fetch(
      "SELECT * FROM invoices WHERE paid = 0 AND total >= ?", [minAmount]
    )).toArray();
  }

  @mcpTool("monthly_summary", { description: "Revenue summary for a month", server: mcp })
  async summary(year: number, month: number): Promise<Record<string, unknown> | null> {
    return await this.db.fetchOne(
      "SELECT SUM(total) as revenue, COUNT(*) as invoice_count " +
      "FROM invoices WHERE strftime('%Y', created_at) = ? " +
      "AND strftime('%m', created_at) = ?",
      [String(year), String(month).padStart(2, "0")]
    );
  }
}

// Create the service instance — methods are already registered via decorators
const accounting = new AccountingService(db);
```

---

## 6. Securing MCP Endpoints

By default, developer MCP servers are public. Add authentication using the standard Tina4 middleware:

```typescript
import { secured, middleware } from "tina4-nodejs/router";

// Secure the entire MCP path
@secured()
@middleware(AuthMiddleware)
function registerMcp() {
  mcp.registerRoutes(router);
}
```

Or check the bearer token inside individual tools:

```typescript
@mcpTool("sensitive_data", { description: "Access restricted data", server: mcp })
async sensitiveData(token: string): Promise<Record<string, unknown>[] | { error: string }> {
  const payload = Auth.validTokenStatic(token);
  if (!payload) {
    return { error: "Unauthorized" };
  }
  return (await db.fetch("SELECT * FROM sensitive_table")).toArray();
}
```

---

## 7. Testing MCP Tools

Use `TestClient` to test MCP endpoints without starting a server, or test tool methods directly:

```typescript
// Test the tool method directly
test("lookup_customer returns correct customer", async () => {
  const tools = new CrmTools();
  const result = await tools.lookupCustomer("alice@example.com");
  expect(result).not.toBeNull();
  expect(result!.email).toBe("alice@example.com");
});

// Test via MCP protocol
test("MCP tool call returns result", async () => {
  const resp = JSON.parse(await mcp.handleMessage({
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: {
      name: "lookup_customer",
      arguments: { email: "alice@example.com" }
    }
  }));
  expect(resp).toHaveProperty("result");
  const content = resp.result.content[0].text;
  expect(content.toLowerCase()).toContain("alice");
});
```

---

## 8. Complete Example: CRM MCP Server

Here is a full working example -- a CRM system with customer, order, and product tools:

```typescript
// app.ts
import { run } from "tina4-nodejs";
import { ormBind, Database } from "tina4-nodejs/orm";
import { McpServer, mcpTool, mcpResource } from "tina4-nodejs/mcp";

const db = new Database("sqlite:///crm.db");
ormBind(db);

// Create MCP server
const crmMcp = new McpServer("/crm/mcp", { name: "CRM Assistant", version: "1.0.0" });

class CrmService {
  private db: Database;

  constructor(db: Database) {
    this.db = db;
  }

  // Tools
  @mcpTool("find_customer", { description: "Search customers by name or email", server: crmMcp })
  async findCustomer(query: string): Promise<Record<string, unknown>[]> {
    return (await this.db.fetch(
      "SELECT * FROM customers WHERE name LIKE ? OR email LIKE ?",
      [`%${query}%`, `%${query}%`]
    )).toArray();
  }

  @mcpTool("customer_orders", { description: "Get all orders for a customer", server: crmMcp })
  async customerOrders(customerId: number): Promise<Record<string, unknown>[]> {
    return (await this.db.fetch(
      "SELECT o.*, GROUP_CONCAT(oi.product_name) as items " +
      "FROM orders o LEFT JOIN order_items oi ON o.id = oi.order_id " +
      "WHERE o.customer_id = ? GROUP BY o.id ORDER BY o.created_at DESC",
      [customerId]
    )).toArray();
  }

  @mcpTool("create_note", { description: "Add a note to a customer record", server: crmMcp })
  async createNote(customerId: number, note: string): Promise<{ success: boolean }> {
    await this.db.insert("customer_notes", { customer_id: customerId, note });
    return { success: true };
  }

  // Resources
  @mcpResource("crm://products", { description: "Product catalog", server: crmMcp })
  async products(): Promise<Record<string, unknown>[]> {
    return (await this.db.fetch("SELECT * FROM products WHERE active = 1")).toArray();
  }

  @mcpResource("crm://stats", { description: "CRM statistics", server: crmMcp })
  async stats(): Promise<Record<string, unknown>> {
    const customers = await this.db.fetchOne("SELECT COUNT(*) as count FROM customers");
    const orders = await this.db.fetchOne("SELECT COUNT(*) as count, SUM(total) as revenue FROM orders");
    return {
      customers: customers!.count,
      orders: orders!.count,
      revenue: orders!.revenue,
    };
  }
}

// Create the service and register routes
const crm = new CrmService(db);
crmMcp.registerRoutes(router);

run();
```

Connect Claude Code to `http://localhost:7145/crm/mcp/sse` and ask:

> "Find all customers named Smith and show their recent orders"

The AI calls `find_customer` with `query: "Smith"`, then `customer_orders` for each result. No custom API needed. The MCP protocol handles it.

---

## 9. Best Practices

1. **One server per domain** -- CRM tools on `/crm/mcp`, accounting on `/accounting/mcp`
2. **Keep tools focused** -- one query per tool, not a Swiss-army-knife tool
3. **Use type annotations** -- they become the schema. An AI assistant cannot call a tool correctly without knowing the parameter types
4. **Return structured data** -- objects and arrays, not formatted strings. Let the AI format for the user
5. **Secure production endpoints** -- use `@secured()` or middleware for any MCP server that runs outside localhost
6. **Test tools directly** -- call the TypeScript method in your test suite, not just through the MCP protocol
