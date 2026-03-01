# Tina4 Delphi – Quick Reference

<nav class="tina4-menu">
    <a href="#installation">Installation</a> •
    <a href="#quick-wins">Quick Wins</a> •
    <a href="#rest-client">REST Client</a> •
    <a href="#rest-request">REST Request</a> •
    <a href="#json-adapter">JSON Adapter</a> •
    <a href="#html-render">HTML Renderer</a> •
    <a href="#html-pages">Page Navigation</a> •
    <a href="#twig">Twig Templates</a> •
    <a href="#core-utilities">Core Utilities</a> •
    <a href="#claude-ai">Claude AI</a>
</nav>

<style>
.tina4-menu {
  background: #2c3e50; color: white; padding: 1rem; border-radius: 8px; margin: 2rem 0; text-align: center; font-size: 1.1rem;
}
.tina4-menu a { color: #1abc9c; text-decoration: none; margin: 0 0.4rem; }
.tina4-menu a:hover { text-decoration: underline; }
</style>

### Installation {#installation}

```bash
# Clone the repository
git clone https://github.com/tina4stack/tina4delphi.git
# Open Tina4DelphiProject in Delphi IDE
# Build and install Tina4Delphi, then Tina4DelphiDesign
```
[More details](installation.md) on requirements, SSL setup, and project configuration.

### Quick Wins {#quick-wins}

No components needed – just add `Tina4Core` to your uses clause and start using these utilities immediately.

**Fetch JSON from any REST API in one line:**

```pascal
var StatusCode: Integer;
var Response := SendHttpRequest(StatusCode, 'https://api.example.com', '/products');
var Products := BytesToJSONObject(Response);
// Products is now a TJSONObject you can iterate, bind to grids, etc.
```

**Turn any database query into JSON:**

```pascal
var JSON := GetJSONFromDB(FDConnection1, 'SELECT * FROM customers WHERE active = 1');
// {"records": [{"id": "1", "firstName": "Andre", "email": "andre@test.com"}, ...]}
// Field names are auto-converted to camelCase, dates to ISO 8601, blobs to Base64
```

**Populate a MemTable from JSON – no manual field defs needed:**

```pascal
PopulateMemTableFromJSON(FDMemTable1, 'records',
  '{"records": [{"id": "1", "name": "Alice"}, {"id": "2", "name": "Bob"}]}');
// FDMemTable1 is now a live dataset – bind it to a grid, filter it, export it
```

**Upload files with multipart form data:**

```pascal
var StatusCode: Integer;
SendMultipartFormData(StatusCode,
  'https://api.example.com', 'upload/avatar',
  ['userId', '1001', 'caption', 'Profile photo'],   // form fields
  ['avatar', 'C:\photos\me.jpg']);                    // file to upload
```

[More details](core.md) on string helpers, dates, encoding, JSON, database, and HTTP utilities.

---

### REST Client {#rest-client}

Drop a `TTina4REST` on your form and configure base URL and auth. Other components reference this for HTTP calls.

```pascal
Tina4REST1.BaseUrl := 'https://api.example.com/v1';
Tina4REST1.SetBearer('eyJhbGciOiJIUzI1NiJ9...');

var StatusCode: Integer;
var Response := Tina4REST1.Get(StatusCode, '/users', 'page=1&limit=10');
```
[More details](rest-client.md) on authentication, HTTP methods, and response handling.

### REST Request {#rest-request}

Links to a `TTina4REST` and executes REST calls with automatic MemTable population.

```pascal
// Design-time: set Tina4REST, EndPoint, DataKey, MemTable
Tina4RESTRequest1.ExecuteRESTCall;
// FDMemTable1 is now populated with the response data
```
[More details](rest-client.md#rest-request) on POST bodies, master/detail, async execution, and events.

### JSON Adapter {#json-adapter}

Populates a `TFDMemTable` from static JSON or from a REST request master source.

```pascal
Tina4JSONAdapter1.MemTable := FDMemTable1;
Tina4JSONAdapter1.DataKey := 'products';
Tina4JSONAdapter1.JSONData.Text := '{"products": [{"id": "1", "name": "Widget"}]}';
Tina4JSONAdapter1.Execute;
```
[More details](json-adapter.md) on MasterSource linking and sync modes.

### HTML Renderer {#html-render}

An FMX control that parses and renders HTML with CSS support directly on a canvas.

```pascal
Tina4HTMLRender1.HTML.Text := '<h1>Hello</h1><p>This is <b>bold</b> and <i>italic</i>.</p>';
```
[More details](html-render.md) on supported HTML/CSS, form controls, events, DOM manipulation, and Twig integration.

### Page Navigation {#html-pages}

Design-time SPA-style page navigation using `TTina4HTMLRender`.

```pascal
Tina4HTMLPages1.Renderer := Tina4HTMLRender1;
var Page := Tina4HTMLPages1.Pages.Add;
Page.PageName := 'home';
Page.IsDefault := True;
Page.HTMLContent.Text := '<h1>Home</h1><a href="#about">Go to About</a>';
```
[More details](html-pages.md) on Twig pages, programmatic navigation, and events.

<div v-pre>

### Twig Templates {#twig}

A Twig-compatible template engine for rendering dynamic HTML.

```pascal
var Twig := TTina4Twig.Create('C:\templates');
try
  Twig.SetVariable('name', 'Andre');
  Memo1.Lines.Text := Twig.Render('<h1>Hello {{ name }}</h1>');
finally
  Twig.Free;
end;
```
[More details](twig.md) on template syntax, filters, and functions.

</div>

### Core Utilities {#core-utilities}

`Tina4Core.pas` provides standalone utility functions for JSON, dates, encoding, HTTP, and database operations.

```pascal
// Convert between naming conventions
CamelCase('first_name');    // 'firstName'
SnakeCase('firstName');     // 'first_name'

// Date validation and conversion
IsDate('2024-01-15T10:30:00.000Z');  // True
GetJSONDate(Now);                     // '2024-06-15T14:30:00.000Z'

// Base64 encoding
var B64 := FileToBase64('C:\photos\avatar.jpg');
```
[More details](core.md) on all available utility functions.

### Working with Claude AI {#claude-ai}

Tina4 Delphi ships with an MCP (Model Context Protocol) server that gives [Claude Code](https://claude.com/claude-code) the ability to compile, run, and syntax-check Pascal code directly from the CLI.

**Install the MCP server:**

```bash
# From the tina4delphi repository
cd claude-pascal-mcp
uv sync
```

**Add it to your Claude Code settings** (`.claude/settings.json` or project-level):

```json
{
  "mcpServers": {
    "pascal-dev": {
      "command": "uv",
      "args": ["run", "--directory", "/path/to/tina4delphi/claude-pascal-mcp", "pascal-mcp"]
    }
  }
}
```

**What Claude can do with the MCP server:**

- **Compile Pascal** – Claude compiles your `.pas` files and reads compiler errors directly
- **Run Pascal** – compile and execute programs, capturing stdout/stderr
- **Syntax check** – fast syntax-only validation without linking
- **Parse forms** – read `.dfm`, `.fmx`, or `.lfm` form files and understand component structure
- **Auto-detect compilers** – finds Free Pascal (`fpc`), Delphi 32-bit (`dcc32`), and Delphi 64-bit (`dcc64`) on your system

This means Claude can write Delphi code, compile it to verify correctness, fix errors, and run test programs – all without leaving the conversation.

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">&uarr; Back to top</a>
</nav>
