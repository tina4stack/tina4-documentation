# Chapter 28: Building Custom MCP Servers

## 1. Beyond Dev Tools

Chapter 27 covered the built-in MCP server that ships with Tina4. It exposes framework internals for AI-assisted development. This chapter goes further: you build your own MCP servers that expose your application's business logic.

A CRM system exposes customer lookup. An accounting system exposes invoice queries. A warehouse system exposes inventory checks. Any domain logic that an AI assistant should access becomes an MCP tool.

---

## 2. Creating an MCP Server

Import `McpServer` and create an instance on any path:

```python
from tina4_python.mcp import McpServer

mcp = McpServer("/api/my-tools", name="My App Tools", version="1.0.0")
```

The server registers HTTP endpoints at:
- `POST /api/my-tools/message` -- JSON-RPC message handler
- `GET /api/my-tools/sse` -- SSE endpoint for client discovery

Register it with the router in `app.py` before `run()`:

```python
from tina4_python.core.router import get, post
mcp.register_routes(__import__("tina4_python.core.router", fromlist=["router"]))
```

---

## 3. Registering Tools with @mcp_tool

The `@mcp_tool` decorator turns a function into an MCP tool. Type hints become the input schema automatically:

```python
from tina4_python.mcp import McpServer, mcp_tool

mcp = McpServer("/crm/mcp", name="CRM Tools")

@mcp_tool("lookup_customer", description="Find a customer by email", server=mcp)
def lookup_customer(email: str):
    """Search the customer database by email address."""
    return db.fetch_one("SELECT * FROM customers WHERE email = ?", [email])

@mcp_tool("recent_orders", description="Get recent orders for a customer", server=mcp)
def recent_orders(customer_id: int, limit: int = 10):
    """Fetch the most recent orders for a customer."""
    result = db.fetch(
        "SELECT * FROM orders WHERE customer_id = ? ORDER BY created_at DESC",
        [customer_id], limit=limit
    )
    return result.to_array()
```

The decorator extracts:
- **Parameter names** from the function signature
- **Types** from type hints (`str` -> `"string"`, `int` -> `"integer"`, etc.)
- **Required vs optional** -- parameters with defaults are optional
- **Description** from the `description` argument or the docstring

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

## 4. Registering Resources with @mcp_resource

Resources are read-only data endpoints. They expose reference data that AI assistants can browse:

```python
from tina4_python.mcp import mcp_resource

@mcp_resource("crm://product-catalog", description="All active products", server=mcp)
def product_catalog():
    return db.fetch("SELECT id, name, price, category FROM products WHERE active = 1").to_array()

@mcp_resource("crm://tax-rates", description="Current tax rates by region", server=mcp)
def tax_rates():
    return db.fetch("SELECT region, rate FROM tax_rates").to_array()
```

Resources are accessed via `resources/list` and `resources/read` in the MCP protocol.

---

## 5. Class-Based MCP Services

Group related tools into a service class. Each method with `@mcp_tool` becomes a tool:

```python
from tina4_python.mcp import McpServer, mcp_tool

mcp = McpServer("/accounting/mcp", name="Accounting Tools")

class AccountingService:
    def __init__(self, db):
        self.db = db

    @mcp_tool("invoice_lookup", description="Find an invoice by number", server=mcp)
    def lookup(self, invoice_no: str):
        return self.db.fetch_one(
            "SELECT * FROM invoices WHERE invoice_no = ?", [invoice_no]
        )

    @mcp_tool("outstanding_balances", description="List all unpaid invoices", server=mcp)
    def balances(self, min_amount: float = 0.0):
        return self.db.fetch(
            "SELECT * FROM invoices WHERE paid = 0 AND total >= ?", [min_amount]
        ).to_array()

    @mcp_tool("monthly_summary", description="Revenue summary for a month", server=mcp)
    def summary(self, year: int, month: int):
        return self.db.fetch_one(
            "SELECT SUM(total) as revenue, COUNT(*) as invoice_count "
            "FROM invoices WHERE strftime('%Y', created_at) = ? "
            "AND strftime('%m', created_at) = ?",
            [str(year), f"{month:02d}"]
        )

# Create the service instance — methods are already registered via decorators
accounting = AccountingService(db)
```

---

## 6. Securing MCP Endpoints

By default, developer MCP servers are public. Add authentication using the standard Tina4 middleware:

```python
from tina4_python.core.router import middleware, secured

# Secure the entire MCP path
@secured()
@middleware(AuthMiddleware)
def register_mcp():
    mcp.register_routes(router)
```

Or check the bearer token inside individual tools:

```python
@mcp_tool("sensitive_data", description="Access restricted data", server=mcp)
def sensitive_data(token: str):
    payload = Auth.valid_token_static(token)
    if not payload:
        return {"error": "Unauthorized"}
    return db.fetch("SELECT * FROM sensitive_table").to_array()
```

---

## 7. Testing MCP Tools

Use `TestClient` to test MCP endpoints without starting a server, or test tool functions directly:

```python
# Test the tool function directly
def test_lookup_customer():
    result = lookup_customer("alice@example.com")
    assert result is not None
    assert result["email"] == "alice@example.com"

# Test via MCP protocol
def test_mcp_tool_call():
    import json
    resp = json.loads(mcp.handle_message({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "lookup_customer",
            "arguments": {"email": "alice@example.com"}
        }
    }))
    assert "result" in resp
    content = resp["result"]["content"][0]["text"]
    assert "alice" in content.lower()
```

---

## 8. Complete Example: CRM MCP Server

Here is a full working example -- a CRM system with customer, order, and product tools:

```python
# app.py
from tina4_python.core import run
from tina4_python.orm import orm_bind
from tina4_python.database import Database
from tina4_python.mcp import McpServer, mcp_tool, mcp_resource

db = Database("sqlite:///crm.db")
orm_bind(db)

# Create MCP server
crm_mcp = McpServer("/crm/mcp", name="CRM Assistant", version="1.0.0")

# Tools
@mcp_tool("find_customer", description="Search customers by name or email", server=crm_mcp)
def find_customer(query: str):
    return db.fetch(
        "SELECT * FROM customers WHERE name LIKE ? OR email LIKE ?",
        [f"%{query}%", f"%{query}%"]
    ).to_array()

@mcp_tool("customer_orders", description="Get all orders for a customer", server=crm_mcp)
def customer_orders(customer_id: int):
    return db.fetch(
        "SELECT o.*, GROUP_CONCAT(oi.product_name) as items "
        "FROM orders o LEFT JOIN order_items oi ON o.id = oi.order_id "
        "WHERE o.customer_id = ? GROUP BY o.id ORDER BY o.created_at DESC",
        [customer_id]
    ).to_array()

@mcp_tool("create_note", description="Add a note to a customer record", server=crm_mcp)
def create_note(customer_id: int, note: str):
    db.insert("customer_notes", {"customer_id": customer_id, "note": note})
    return {"success": True}

# Resources
@mcp_resource("crm://products", description="Product catalog", server=crm_mcp)
def products():
    return db.fetch("SELECT * FROM products WHERE active = 1").to_array()

@mcp_resource("crm://stats", description="CRM statistics", server=crm_mcp)
def stats():
    customers = db.fetch_one("SELECT COUNT(*) as count FROM customers")
    orders = db.fetch_one("SELECT COUNT(*) as count, SUM(total) as revenue FROM orders")
    return {
        "customers": customers["count"],
        "orders": orders["count"],
        "revenue": orders["revenue"],
    }

# Register routes
import tina4_python.core.router as router
crm_mcp.register_routes(router)

if __name__ == "__main__":
    run()
```

Connect Claude Code to `http://localhost:7145/crm/mcp/sse` and ask:

> "Find all customers named Smith and show their recent orders"

The AI calls `find_customer` with `query: "Smith"`, then `customer_orders` for each result. No custom API needed. The MCP protocol handles it.

---

## 9. Best Practices

1. **One server per domain** -- CRM tools on `/crm/mcp`, accounting on `/accounting/mcp`
2. **Keep tools focused** -- one query per tool, not a Swiss-army-knife tool
3. **Use type hints** -- they become the schema. An AI assistant cannot call a tool correctly without knowing the parameter types
4. **Return structured data** -- dicts and lists, not formatted strings. Let the AI format for the user
5. **Secure production endpoints** -- use `@secured()` or middleware for any MCP server that runs outside localhost
6. **Test tools directly** -- call the Python function in your test suite, not just through the MCP protocol
