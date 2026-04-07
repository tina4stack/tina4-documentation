# Chapter 27: MCP Dev Tools

## 1. What is MCP?

The Model Context Protocol connects AI coding tools to your running application. Claude Code, Cursor, and other assistants speak this protocol. When they connect, they see your database, routes, templates, and files -- not as static text, but as live, queryable tools.

Tina4 ships a built-in MCP server. It starts automatically in dev mode. No configuration needed.

---

## 2. How It Works

Set `TINA4_DEBUG=true` in your `.env` file and start the server:

```bash
php app.php
```

The console prints:

```
MCP server available at http://localhost:7145/__dev/mcp
```

Tina4 writes the connection details to `.claude/settings.json` automatically. Claude Code discovers the server on its next restart. Cursor reads the same file.

### Localhost-Only Security

The built-in MCP server activates only when two conditions hold:

1. `TINA4_DEBUG=true`
2. The server runs on `localhost`, `127.0.0.1`, or `0.0.0.0`

Deploy to a remote server and the MCP endpoint vanishes -- even with debug enabled. This prevents accidental exposure of database queries and file editing in production.

To enable on a staging server (rare, intentional), set:

```bash
TINA4_MCP_REMOTE=true
```

---

## 3. Connecting AI Tools

### Claude Code

Tina4 auto-generates `.claude/settings.json`:

```json
{
  "mcpServers": {
    "tina4-dev": {
      "url": "http://localhost:7145/__dev/mcp/sse"
    }
  }
}
```

Restart Claude Code. It connects and lists the tools.

### Cursor

Copy the same MCP config into Cursor's settings. The SSE URL is identical.

### Manual Connection

Any MCP client can connect via:

- **SSE endpoint**: `GET http://localhost:7145/__dev/mcp/sse` -- returns the message endpoint URL
- **Message endpoint**: `POST http://localhost:7145/__dev/mcp/message` -- accepts JSON-RPC 2.0 messages

---

## 4. Built-in Tools

The MCP server exposes 24 tools organized by category.

### Database

| Tool | Description |
|------|-------------|
| `database_query` | Execute a read-only SQL query (SELECT) |
| `database_execute` | Execute arbitrary SQL (INSERT, UPDATE, DELETE, DDL) |
| `database_tables` | List all tables in the database |
| `database_columns` | Get column definitions for a specific table |

Example -- an AI assistant queries your database directly:

```
Tool: database_query
Arguments: {"sql": "SELECT id, name, email FROM users WHERE active = 1"}
```

The `database_execute` tool handles write operations. It commits automatically after each statement.

### Routes

| Tool | Description |
|------|-------------|
| `route_list` | List all registered routes with methods and auth status |
| `route_test` | Call a route and return status, body, and headers |
| `swagger_spec` | Return the full OpenAPI 3.0.3 specification |

The `route_test` tool lets an AI assistant verify endpoints without leaving the conversation:

```
Tool: route_test
Arguments: {"method": "GET", "path": "/api/users"}
```

### Templates

| Tool | Description |
|------|-------------|
| `template_render` | Render a Frond template string with provided data |

Useful for testing template snippets:

```
Tool: template_render
Arguments: {"template": "Hello {{ name }}!", "data": "{\"name\": \"Alice\"}"}
```

### Files

| Tool | Description |
|------|-------------|
| `file_read` | Read a project file (relative to project root) |
| `file_write` | Write or update a project file |
| `file_list` | List files in a directory |
| `asset_upload` | Upload a file to `src/public/` |

File operations are sandboxed. Paths that escape the project directory are rejected. An AI assistant cannot read `/etc/passwd` or write outside your project.

### Migrations

| Tool | Description |
|------|-------------|
| `migration_status` | List pending and completed migrations |
| `migration_create` | Create a new migration file |
| `migration_run` | Run all pending migrations |

### Data and ORM

| Tool | Description |
|------|-------------|
| `orm_describe` | List all ORM models with fields, types, and relationships |
| `seed_table` | Seed a table with fake data |

### Infrastructure

| Tool | Description |
|------|-------------|
| `queue_status` | Queue size by status (pending, completed, failed) |
| `session_list` | Active sessions with data |
| `cache_stats` | Response cache hit/miss statistics |

### Debugging

| Tool | Description |
|------|-------------|
| `log_tail` | Read recent log entries |
| `error_log` | Recent errors and exceptions with stack traces |
| `env_list` | Environment variables (sensitive values redacted) |
| `system_info` | Framework version, PHP version, project path |

The `env_list` tool redacts any variable containing "secret", "password", "token", "key", or "credential" in its name.

---

## 5. Protocol Details

The MCP server uses JSON-RPC 2.0 over HTTP. Two endpoints serve the protocol:

### SSE Endpoint (GET)

```
GET /__dev/mcp/sse
Content-Type: text/event-stream
```

Returns the message endpoint URL as a server-sent event:

```
event: endpoint
data: http://localhost:7145/__dev/mcp/message
```

### Message Endpoint (POST)

```
POST /__dev/mcp/message
Content-Type: application/json
```

Accepts JSON-RPC 2.0 requests:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}
```

Returns JSON-RPC 2.0 responses:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {"name": "database_query", "description": "Execute a read-only SQL query", "inputSchema": {...}}
    ]
  }
}
```

### Lifecycle

1. Client sends `initialize` -- server responds with capabilities
2. Client sends `notifications/initialized` -- server acknowledges
3. Client calls `tools/list` -- server returns all registered tools with schemas
4. Client calls `tools/call` with tool name and arguments -- server executes and returns results
5. Client calls `resources/list` and `resources/read` for data resources

---

## 6. Troubleshooting

**MCP server not starting:**
- Check `TINA4_DEBUG=true` in `.env`
- Verify the server is running on localhost (not a remote host)

**Claude Code not detecting the server:**
- Restart Claude Code after starting the Tina4 server
- Check `.claude/settings.json` exists with the correct URL
- Verify the port matches your server's port

**Tools returning errors:**
- Database tools require `$db = new Database(...)` in `app.php`
- File tools are sandboxed to the project directory
- `database_execute` only works on localhost

**Remote server — MCP disabled:**
- This is intentional. Set `TINA4_MCP_REMOTE=true` only on staging environments you trust
- Never enable MCP on production servers
