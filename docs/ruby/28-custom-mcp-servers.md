# Chapter 28: Building Custom MCP Servers

## 1. Beyond Dev Tools

Chapter 27 covered the built-in MCP server that ships with Tina4. It exposes framework internals for AI-assisted development. This chapter goes further: you build your own MCP servers that expose your application's business logic.

A CRM system exposes customer lookup. An accounting system exposes invoice queries. A warehouse system exposes inventory checks. Any domain logic that an AI assistant should access becomes an MCP tool.

---

## 2. Creating an MCP Server

Require `McpServer` and create an instance on any path:

```ruby
require "tina4"

mcp = Tina4::McpServer.new("/api/my-tools", name: "My App Tools", version: "1.0.0")
```

The server registers HTTP endpoints at:
- `POST /api/my-tools/message` -- JSON-RPC message handler
- `GET /api/my-tools/sse` -- SSE endpoint for client discovery

Register it with the router in `app.rb` before `run`:

```ruby
mcp.register_routes
```

---

## 3. Registering Tools with mcp_tool

The `Tina4.mcp_tool` method turns a block into an MCP tool. Parameter metadata becomes the input schema:

```ruby
require "tina4"

mcp = Tina4::McpServer.new("/crm/mcp", name: "CRM Tools")

Tina4.mcp_tool("lookup_customer", description: "Find a customer by email", server: mcp,
  params: [{ name: "email", type: "string" }]) do |args|
  db.fetch_one("SELECT * FROM customers WHERE email = ?", [args["email"]])
end

Tina4.mcp_tool("recent_orders", description: "Get recent orders for a customer", server: mcp,
  params: [
    { name: "customer_id", type: "integer" },
    { name: "limit", type: "integer", default: 10 }
  ]) do |args|
  db.fetch(
    "SELECT * FROM orders WHERE customer_id = ? ORDER BY created_at DESC",
    [args["customer_id"]], limit: args["limit"] || 10
  ).to_a
end
```

The registration extracts:
- **Parameter names** from the params list
- **Types** from the type field (`"string"`, `"integer"`, `"boolean"`, etc.)
- **Required vs optional** -- parameters with defaults are optional
- **Description** from the `description` argument

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

## 4. Registering Resources with mcp_resource

Resources are read-only data endpoints. They expose reference data that AI assistants can browse:

```ruby
Tina4.mcp_resource("crm://product-catalog", description: "All active products", server: mcp) do
  db.fetch("SELECT id, name, price, category FROM products WHERE active = 1").to_a
end

Tina4.mcp_resource("crm://tax-rates", description: "Current tax rates by region", server: mcp) do
  db.fetch("SELECT region, rate FROM tax_rates").to_a
end
```

Resources are accessed via `resources/list` and `resources/read` in the MCP protocol.

---

## 5. Class-Based MCP Services

Group related tools into a service class. Register each method as a tool:

```ruby
require "tina4"

mcp = Tina4::McpServer.new("/accounting/mcp", name: "Accounting Tools")

class AccountingService
  def initialize(db)
    @db = db
  end

  def lookup(invoice_no)
    @db.fetch_one("SELECT * FROM invoices WHERE invoice_no = ?", [invoice_no])
  end

  def balances(min_amount = 0.0)
    @db.fetch("SELECT * FROM invoices WHERE paid = 0 AND total >= ?", [min_amount]).to_a
  end

  def summary(year, month)
    @db.fetch_one(
      "SELECT SUM(total) as revenue, COUNT(*) as invoice_count " \
      "FROM invoices WHERE strftime('%Y', created_at) = ? " \
      "AND strftime('%m', created_at) = ?",
      [year.to_s, format("%02d", month)]
    )
  end
end

svc = AccountingService.new(db)

Tina4.mcp_tool("invoice_lookup", description: "Find an invoice by number", server: mcp,
  params: [{ name: "invoice_no", type: "string" }]) do |args|
  svc.lookup(args["invoice_no"])
end

Tina4.mcp_tool("outstanding_balances", description: "List all unpaid invoices", server: mcp,
  params: [{ name: "min_amount", type: "number", default: 0.0 }]) do |args|
  svc.balances(args["min_amount"] || 0.0)
end

Tina4.mcp_tool("monthly_summary", description: "Revenue summary for a month", server: mcp,
  params: [
    { name: "year", type: "integer" },
    { name: "month", type: "integer" }
  ]) do |args|
  svc.summary(args["year"], args["month"])
end
```

---

## 6. Securing MCP Endpoints

By default, developer MCP servers are public. Add authentication using Tina4 middleware:

```ruby
# Secure the entire MCP path
Tina4.secured do
  mcp.register_routes
end
```

Or check the bearer token inside individual tools:

```ruby
Tina4.mcp_tool("sensitive_data", description: "Access restricted data", server: mcp,
  params: [{ name: "token", type: "string" }]) do |args|
  payload = Tina4::Auth.valid_token(args["token"])
  unless payload
    next { error: "Unauthorized" }
  end
  db.fetch("SELECT * FROM sensitive_table").to_a
end
```

---

## 7. Testing MCP Tools

Test tool functions directly, or test via the MCP protocol:

```ruby
# Test the tool block directly
def test_lookup_customer
  result = db.fetch_one("SELECT * FROM customers WHERE email = ?", ["alice@example.com"])
  assert result != nil
  assert_equal "alice@example.com", result["email"]
end

# Test via MCP protocol
def test_mcp_tool_call
  resp = JSON.parse(mcp.handle_message({
    "jsonrpc" => "2.0",
    "id" => 1,
    "method" => "tools/call",
    "params" => {
      "name" => "lookup_customer",
      "arguments" => { "email" => "alice@example.com" }
    }
  }))
  assert resp.key?("result")
  content = resp["result"]["content"][0]["text"]
  assert content.downcase.include?("alice")
end
```

---

## 8. Complete Example: CRM MCP Server

Here is a full working example -- a CRM system with customer, order, and product tools:

```ruby
# app.rb
require "tina4"

db = Tina4::Database.new("sqlite:///crm.db")
Tina4::ORM.bind(db)

# Create MCP server
crm_mcp = Tina4::McpServer.new("/crm/mcp", name: "CRM Assistant", version: "1.0.0")

# Tools
Tina4.mcp_tool("find_customer", description: "Search customers by name or email", server: crm_mcp,
  params: [{ name: "query", type: "string" }]) do |args|
  q = args["query"]
  db.fetch("SELECT * FROM customers WHERE name LIKE ? OR email LIKE ?",
           ["%#{q}%", "%#{q}%"]).to_a
end

Tina4.mcp_tool("customer_orders", description: "Get all orders for a customer", server: crm_mcp,
  params: [{ name: "customer_id", type: "integer" }]) do |args|
  db.fetch(
    "SELECT o.*, GROUP_CONCAT(oi.product_name) as items " \
    "FROM orders o LEFT JOIN order_items oi ON o.id = oi.order_id " \
    "WHERE o.customer_id = ? GROUP BY o.id ORDER BY o.created_at DESC",
    [args["customer_id"]]
  ).to_a
end

Tina4.mcp_tool("create_note", description: "Add a note to a customer record", server: crm_mcp,
  params: [
    { name: "customer_id", type: "integer" },
    { name: "note", type: "string" }
  ]) do |args|
  db.insert("customer_notes", { customer_id: args["customer_id"], note: args["note"] })
  { success: true }
end

# Resources
Tina4.mcp_resource("crm://products", description: "Product catalog", server: crm_mcp) do
  db.fetch("SELECT * FROM products WHERE active = 1").to_a
end

Tina4.mcp_resource("crm://stats", description: "CRM statistics", server: crm_mcp) do
  customers = db.fetch_one("SELECT COUNT(*) as count FROM customers")
  orders = db.fetch_one("SELECT COUNT(*) as count, SUM(total) as revenue FROM orders")
  {
    customers: customers["count"],
    orders: orders["count"],
    revenue: orders["revenue"]
  }
end

# Register routes
crm_mcp.register_routes

Tina4.run
```

Connect Claude Code to `http://localhost:7147/crm/mcp/sse` and ask:

> "Find all customers named Smith and show their recent orders"

The AI calls `find_customer` with `query: "Smith"`, then `customer_orders` for each result. No custom API needed. The MCP protocol handles it.

---

## 9. Best Practices

1. **One server per domain** -- CRM tools on `/crm/mcp`, accounting on `/accounting/mcp`
2. **Keep tools focused** -- one query per tool, not a Swiss-army-knife tool
3. **Use param metadata** -- types and defaults become the schema. An AI assistant cannot call a tool correctly without knowing the parameter types
4. **Return structured data** -- hashes and arrays, not formatted strings. Let the AI format for the user
5. **Secure production endpoints** -- use `Tina4.secured` or middleware for any MCP server that runs outside localhost
6. **Test tools directly** -- call the Ruby method in your test suite, not just through the MCP protocol
