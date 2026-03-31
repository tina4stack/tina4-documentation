# Chapter 28: Building Custom MCP Servers

## 1. Beyond Dev Tools

Chapter 27 covered the built-in MCP server that ships with Tina4. It exposes framework internals for AI-assisted development. This chapter goes further: you build your own MCP servers that expose your application's business logic.

A CRM system exposes customer lookup. An accounting system exposes invoice queries. A warehouse system exposes inventory checks. Any domain logic that an AI assistant should access becomes an MCP tool.

---

## 2. Creating an MCP Server

Import `McpServer` and create an instance on any path:

```php
use Tina4\McpServer;

$mcp = new McpServer("/api/my-tools", name: "My App Tools", version: "1.0.0");
```

The server registers HTTP endpoints at:
- `POST /api/my-tools/message` -- JSON-RPC message handler
- `GET /api/my-tools/sse` -- SSE endpoint for client discovery

Register it with the router in `app.php` before `run()`:

```php
$mcp->registerRoutes($router);
```

---

## 3. Registering Tools with #[McpTool]

The `#[McpTool]` attribute turns a method into an MCP tool. Type hints become the input schema automatically:

```php
use Tina4\McpServer;
use Tina4\McpTool;

$mcp = new McpServer("/crm/mcp", name: "CRM Tools");

class CrmTools
{
    #[McpTool("lookup_customer", description: "Find a customer by email", server: "crm")]
    public function lookupCustomer(string $email): array
    {
        global $db;
        return $db->fetchOne("SELECT * FROM customers WHERE email = ?", [$email]);
    }

    #[McpTool("recent_orders", description: "Get recent orders for a customer", server: "crm")]
    public function recentOrders(int $customerId, int $limit = 10): array
    {
        global $db;
        $result = $db->fetch(
            "SELECT * FROM orders WHERE customer_id = ? ORDER BY created_at DESC",
            [$customerId], $limit
        );
        return $result->toArray();
    }
}
```

The attribute extracts:
- **Parameter names** from the method signature
- **Types** from type hints (`string` -> `"string"`, `int` -> `"integer"`, etc.)
- **Required vs optional** -- parameters with defaults are optional
- **Description** from the `description` argument or the docblock

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

## 4. Registering Resources with #[McpResource]

Resources are read-only data endpoints. They expose reference data that AI assistants can browse:

```php
use Tina4\McpResource;

class CrmResources
{
    #[McpResource("crm://product-catalog", description: "All active products", server: "crm")]
    public function productCatalog(): array
    {
        global $db;
        return $db->fetch("SELECT id, name, price, category FROM products WHERE active = 1")->toArray();
    }

    #[McpResource("crm://tax-rates", description: "Current tax rates by region", server: "crm")]
    public function taxRates(): array
    {
        global $db;
        return $db->fetch("SELECT region, rate FROM tax_rates")->toArray();
    }
}
```

Resources are accessed via `resources/list` and `resources/read` in the MCP protocol.

---

## 5. Class-Based MCP Services

Group related tools into a service class. Each method with `#[McpTool]` becomes a tool:

```php
use Tina4\McpServer;
use Tina4\McpTool;

$mcp = new McpServer("/accounting/mcp", name: "Accounting Tools");

class AccountingService
{
    private $db;

    public function __construct($db)
    {
        $this->db = $db;
    }

    #[McpTool("invoice_lookup", description: "Find an invoice by number", server: "accounting")]
    public function lookup(string $invoiceNo): ?array
    {
        return $this->db->fetchOne(
            "SELECT * FROM invoices WHERE invoice_no = ?", [$invoiceNo]
        );
    }

    #[McpTool("outstanding_balances", description: "List all unpaid invoices", server: "accounting")]
    public function balances(float $minAmount = 0.0): array
    {
        return $this->db->fetch(
            "SELECT * FROM invoices WHERE paid = 0 AND total >= ?", [$minAmount]
        )->toArray();
    }

    #[McpTool("monthly_summary", description: "Revenue summary for a month", server: "accounting")]
    public function summary(int $year, int $month): ?array
    {
        return $this->db->fetchOne(
            "SELECT SUM(total) as revenue, COUNT(*) as invoice_count "
            . "FROM invoices WHERE strftime('%Y', created_at) = ? "
            . "AND strftime('%m', created_at) = ?",
            [(string)$year, str_pad($month, 2, '0', STR_PAD_LEFT)]
        );
    }
}

// Create the service instance — methods are already registered via attributes
$accounting = new AccountingService($db);
```

---

## 6. Securing MCP Endpoints

By default, developer MCP servers are public. Add authentication using the standard Tina4 middleware:

```php
use Tina4\Secured;
use Tina4\Middleware;

// Secure the entire MCP path
#[Secured]
#[Middleware(AuthMiddleware::class)]
function registerMcp() {
    global $mcp, $router;
    $mcp->registerRoutes($router);
}
```

Or check the bearer token inside individual tools:

```php
#[McpTool("sensitive_data", description: "Access restricted data", server: "crm")]
public function sensitiveData(string $token): array
{
    global $db;
    $payload = Auth::validTokenStatic($token);
    if (!$payload) {
        return ["error" => "Unauthorized"];
    }
    return $db->fetch("SELECT * FROM sensitive_table")->toArray();
}
```

---

## 7. Testing MCP Tools

Use `TestClient` to test MCP endpoints without starting a server, or test tool methods directly:

```php
// Test the tool method directly
public function testLookupCustomer(): void
{
    $tools = new CrmTools();
    $result = $tools->lookupCustomer("alice@example.com");
    $this->assertNotNull($result);
    $this->assertEquals("alice@example.com", $result["email"]);
}

// Test via MCP protocol
public function testMcpToolCall(): void
{
    $resp = json_decode($mcp->handleMessage([
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/call",
        "params" => [
            "name" => "lookup_customer",
            "arguments" => ["email" => "alice@example.com"]
        ]
    ]), true);
    $this->assertArrayHasKey("result", $resp);
    $content = $resp["result"]["content"][0]["text"];
    $this->assertStringContainsString("alice", strtolower($content));
}
```

---

## 8. Complete Example: CRM MCP Server

Here is a full working example -- a CRM system with customer, order, and product tools:

```php
<?php
// app.php
require_once "vendor/autoload.php";

use Tina4\McpServer;
use Tina4\McpTool;
use Tina4\McpResource;
use Tina4\Database;
use Tina4\ORM;

$db = new Database("sqlite:///crm.db");
ORM::bind($db);

// Create MCP server
$crmMcp = new McpServer("/crm/mcp", name: "CRM Assistant", version: "1.0.0");

class CrmService
{
    private $db;

    public function __construct($db)
    {
        $this->db = $db;
    }

    // Tools
    #[McpTool("find_customer", description: "Search customers by name or email", server: "crm")]
    public function findCustomer(string $query): array
    {
        return $this->db->fetch(
            "SELECT * FROM customers WHERE name LIKE ? OR email LIKE ?",
            ["%{$query}%", "%{$query}%"]
        )->toArray();
    }

    #[McpTool("customer_orders", description: "Get all orders for a customer", server: "crm")]
    public function customerOrders(int $customerId): array
    {
        return $this->db->fetch(
            "SELECT o.*, GROUP_CONCAT(oi.product_name) as items "
            . "FROM orders o LEFT JOIN order_items oi ON o.id = oi.order_id "
            . "WHERE o.customer_id = ? GROUP BY o.id ORDER BY o.created_at DESC",
            [$customerId]
        )->toArray();
    }

    #[McpTool("create_note", description: "Add a note to a customer record", server: "crm")]
    public function createNote(int $customerId, string $note): array
    {
        $this->db->insert("customer_notes", ["customer_id" => $customerId, "note" => $note]);
        return ["success" => true];
    }

    // Resources
    #[McpResource("crm://products", description: "Product catalog", server: "crm")]
    public function products(): array
    {
        return $this->db->fetch("SELECT * FROM products WHERE active = 1")->toArray();
    }

    #[McpResource("crm://stats", description: "CRM statistics", server: "crm")]
    public function stats(): array
    {
        $customers = $this->db->fetchOne("SELECT COUNT(*) as count FROM customers");
        $orders = $this->db->fetchOne("SELECT COUNT(*) as count, SUM(total) as revenue FROM orders");
        return [
            "customers" => $customers["count"],
            "orders" => $orders["count"],
            "revenue" => $orders["revenue"],
        ];
    }
}

// Create the service and register routes
$crm = new CrmService($db);
$crmMcp->registerRoutes($router);

Tina4\run();
```

Connect Claude Code to `http://localhost:7145/crm/mcp/sse` and ask:

> "Find all customers named Smith and show their recent orders"

The AI calls `find_customer` with `query: "Smith"`, then `customer_orders` for each result. No custom API needed. The MCP protocol handles it.

---

## 9. Best Practices

1. **One server per domain** -- CRM tools on `/crm/mcp`, accounting on `/accounting/mcp`
2. **Keep tools focused** -- one query per tool, not a Swiss-army-knife tool
3. **Use type hints** -- they become the schema. An AI assistant cannot call a tool correctly without knowing the parameter types
4. **Return structured data** -- arrays and objects, not formatted strings. Let the AI format for the user
5. **Secure production endpoints** -- use `#[Secured]` or middleware for any MCP server that runs outside localhost
6. **Test tools directly** -- call the PHP method in your test suite, not just through the MCP protocol
