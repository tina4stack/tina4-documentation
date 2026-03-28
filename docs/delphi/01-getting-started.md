# Chapter 1: Getting Started

## Your First 10 Minutes

A Delphi IDE. Two packages installed. One form. In ten minutes you will have a running FMX application that fetches live data from a REST API and displays it in a grid. The data will appear before you understand the plumbing. That is the point -- you ship first, then you learn.

---

## 1. What Is Tina4 Delphi

Tina4 Delphi is a design-time component library for Delphi 10.4+ (FireMonkey / FMX). Nine components, each solving one problem:

- **TTina4REST** for REST client configuration -- base URL, auth, headers
- **TTina4RESTRequest** for declarative REST calls -- link an endpoint, a MemTable, and execute
- **TTina4JSONAdapter** for static JSON to MemTable binding -- no HTTP required
- **TTina4HTMLRender** for rendering HTML with CSS on an FMX canvas -- forms, tables, images, events
- **TTina4HTMLPages** for SPA-style page navigation inside your desktop app
- **TTina4WebSocketClient** for real-time WebSocket communication with auto-reconnect and ping/pong keepalive
- **TTina4SocketServer** for raw TCP socket server functionality
- **TTina4WebServer** for hosting an embedded HTTP web server
- **TTina4Route** for declarative URL routing

Plus a core utility unit (`Tina4Core.pas`) with standalone functions for HTTP, JSON, database, encoding, and shell commands. There is also `TTina4Twig`, a plain `TObject` class (not a design-time component) for Twig-compatible template rendering.

### What It Is Not

Tina4 Delphi is not a framework. It does not take over your application. It does not impose an architecture. It does not require you to restructure your project. Drop components on a form. Set properties. Call methods. Your existing FireDAC connections, your existing business logic, your existing UI -- everything stays exactly where it is.

Tina4 Delphi is not VCL. It is FireMonkey only. If you need VCL support, you can still use `Tina4Core.pas` directly -- the utility functions have no FMX dependency.

---

## 2. Prerequisites

You need three things. Nothing else.

1. **Delphi 10.4 or later** -- any edition that includes FireMonkey and FireDAC.

2. **OpenSSL DLLs** -- required for HTTPS. Without them, every REST call to an HTTPS endpoint will fail silently or raise an exception.

3. **The Tina4 Delphi source** -- cloned from GitHub.

---

## 3. Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/tina4stack/tina4delphi.git
```

### Step 2: Open the Project Group

In the Delphi IDE, open the **Tina4DelphiProject** project group file. You will see two projects:

- **Tina4Delphi** -- the runtime package
- **Tina4DelphiDesign** -- the design-time package

### Step 3: Build and Install the Runtime Package

Right-click **Tina4Delphi** in the Project Manager and select **Build**. This compiles the runtime units but does not register anything in the IDE.

### Step 4: Build and Install the Design-Time Package

Right-click **Tina4DelphiDesign** and select **Build**, then **Install**. You should see a confirmation dialog:

> Package Tina4DelphiDesign has been installed. The following new component(s) have been registered: TTina4REST, TTina4RESTRequest, TTina4JSONAdapter, TTina4HTMLRender, TTina4HTMLPages, TTina4WebSocketClient, TTina4SocketServer, TTina4WebServer, TTina4Route.

### Step 5: Verify

Open the Tool Palette. Search for "Tina4". All nine components should appear under the **Tina4Delphi** category. If they do not, check that the output directories for both packages are on your IDE's library path.

---

## 4. SSL Setup

HTTPS calls require OpenSSL DLLs. Delphi's `TNetHTTPClient` (which Tina4 uses internally) will fail without them. The error is often cryptic -- an empty response, a 0 status code, or an access violation.

### Windows

Download the OpenSSL binaries for your Delphi version (typically OpenSSL 1.1.x for Delphi 10.4/11, or OpenSSL 3.x for Delphi 12+). You need two sets:

1. **32-bit DLLs** (`libssl-1_1.dll`, `libcrypto-1_1.dll`) -- copy to `C:\Windows\SysWOW64\`. The IDE runs as a 32-bit process and needs these to make HTTPS calls at design time and during debugging.

2. **64-bit DLLs** (`libssl-1_1-x64.dll`, `libcrypto-1_1-x64.dll`) -- copy to `C:\Windows\System32\`. Your compiled 64-bit application uses these at runtime.

### Quick Test

After placing the DLLs, create a blank FMX project and add this to a button click:

```pascal
procedure TForm1.Button1Click(Sender: TObject);
var
  StatusCode: Integer;
  Response: TBytes;
begin
  Response := SendHttpRequest(StatusCode, 'https://jsonplaceholder.typicode.com', '/posts/1');
  ShowMessage('Status: ' + StatusCode.ToString + ' / ' + TEncoding.UTF8.GetString(Response));
end;
```

Add `Tina4Core` to your uses clause. If you see a JSON response with a status of 200, SSL is working. If you get a status of 0 or an exception, your DLLs are missing or the wrong bitness.

---

## 5. Available Components

Here is the full inventory. Each gets its own chapter, but knowing the landscape helps you plan.

| Component | What It Does | Typical Use Case |
|---|---|---|
| `TTina4REST` | Holds base URL, credentials, bearer token | One per API endpoint |
| `TTina4RESTRequest` | Executes a REST call, populates a MemTable | One per endpoint/action |
| `TTina4JSONAdapter` | Binds static JSON to a MemTable | Offline data, config files |
| `TTina4HTMLRender` | Renders HTML + CSS on an FMX canvas | Reports, dashboards, forms |
| `TTina4HTMLPages` | SPA navigation between pages | Multi-page desktop apps |
| `TTina4WebSocketClient` | WebSocket client with auto-reconnect and keepalive | Real-time data feeds, chat |
| `TTina4SocketServer` | Raw TCP socket server | Custom protocol servers |
| `TTina4WebServer` | Embedded HTTP web server | Local dashboards, APIs |
| `TTina4Route` | Declarative URL routing | REST endpoint definitions |

Additionally, `TTina4Twig` is a plain `TObject` class (not a design-time component) that provides a Twig-compatible template engine for dynamic HTML generation.

And the standalone utility functions in `Tina4Core.pas`:

| Function | What It Does |
|---|---|
| `SendHttpRequest` | Low-level HTTP with auth, headers, timeouts |
| `BytesToJSONObject` | Parse raw HTTP response bytes to `TJSONObject` |
| `GetJSONFromDB` | SQL query to JSON with camelCase, ISO dates, Base64 blobs |
| `PopulateMemTableFromJSON` | JSON to MemTable with Clear or Sync mode |
| `SendMultipartFormData` | File upload with form fields |
| `CamelCase` / `SnakeCase` | Name conversion between database and JSON |
| `GetGUID` | Generate a GUID string |
| `ExecuteShellCommand` | Run a shell command and capture output |

---

## 6. Your First App: API Data in a Grid

Time to build something real. You will fetch a list of posts from a public API and display them in a grid. No dummy data. No mocking. Live HTTP on your first try.

### Step 1: Create the Project

**File > New > Multi-Device Application > Blank Application**. Save it as `FirstTina4App`.

### Step 2: Drop Components on the Form

From the Tool Palette, add these components:

1. **TTina4REST** -- name it `Tina4REST1`
2. **TTina4RESTRequest** -- name it `Tina4RESTRequest1`
3. **TFDMemTable** -- name it `FDMemTable1` (from the FireDAC palette)
4. **TStringGrid** -- name it `StringGrid1` (from the Grids palette)
5. **TButton** -- name it `btnFetch`, set `Text` to `Fetch Posts`

### Step 3: Configure the REST Client

Select `Tina4REST1` and set these properties in the Object Inspector:

| Property | Value |
|---|---|
| `BaseUrl` | `https://jsonplaceholder.typicode.com` |

No username, no password, no bearer token. This is a public API.

### Step 4: Configure the REST Request

Select `Tina4RESTRequest1` and set:

| Property | Value |
|---|---|
| `Tina4REST` | `Tina4REST1` |
| `EndPoint` | `/posts` |
| `RequestType` | `Get` |
| `MemTable` | `FDMemTable1` |
| `SyncMode` | `Clear` |

The `DataKey` property can be left empty. When the API returns a JSON array at the root level (as jsonplaceholder does), the component handles it automatically.

### Step 5: Wire the Button

Double-click `btnFetch` and add:

```pascal
procedure TForm1.btnFetchClick(Sender: TObject);
begin
  Tina4RESTRequest1.ExecuteRESTCall;

  // Populate the grid from the MemTable
  StringGrid1.RowCount := FDMemTable1.RecordCount;

  // Clear existing columns and create from field definitions
  StringGrid1.ClearColumns;
  for var I := 0 to FDMemTable1.FieldCount - 1 do
  begin
    var Col := TStringColumn.Create(StringGrid1);
    Col.Header := FDMemTable1.Fields[I].FieldName;
    StringGrid1.AddObject(Col);
  end;

  // Populate rows
  FDMemTable1.First;
  var Row := 0;
  while not FDMemTable1.Eof do
  begin
    for var C := 0 to FDMemTable1.FieldCount - 1 do
      StringGrid1.Cells[C, Row] := FDMemTable1.Fields[C].AsString;
    Inc(Row);
    FDMemTable1.Next;
  end;
end;
```

Add `Tina4REST, Tina4RESTRequest, FMX.Grid.Style` to your uses clause.

### Step 6: Run

Press **F9**. Click **Fetch Posts**. The grid fills with 100 posts from the API -- id, userId, title, and body columns. If it does not work, check the SSL setup from Section 4.

### What Just Happened

One component configured the base URL. Another component made the HTTP call, parsed the JSON response, created field definitions from the JSON structure, and populated a MemTable. You wrote zero HTTP code. Zero JSON parsing code. Zero field-definition code. The component chain handled all of it.

---

## 7. Quick Wins with Tina4Core

You do not always need components. `Tina4Core.pas` gives you standalone functions you can call from anywhere. Here are one-liners that solve common problems:

### Fetch JSON from an API

```pascal
uses Tina4Core;

var
  StatusCode: Integer;
  Response: TBytes;
  JSON: TJSONObject;
begin
  Response := SendHttpRequest(StatusCode, 'https://api.example.com', '/users');
  JSON := BytesToJSONObject(Response);
  try
    ShowMessage(JSON.ToString);
  finally
    JSON.Free;
  end;
end;
```

### Database Query to JSON

```pascal
var JSON := GetJSONFromDB(FDConnection1, 'SELECT * FROM customers WHERE active = 1');
try
  Memo1.Lines.Text := JSON.Format;
finally
  JSON.Free;
end;
// Output: {"records": [{"id": "1", "firstName": "Alice", ...}, ...]}
// Note: field names auto-convert from snake_case to camelCase
```

### JSON to MemTable

```pascal
var JSONStr := '{"users": [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]}';
PopulateMemTableFromJSON(FDMemTable1, 'users', JSONStr);
// FDMemTable1 now has 2 rows with id and name columns
```

### Upload a File

```pascal
var
  StatusCode: Integer;
begin
  SendMultipartFormData(
    StatusCode,
    'https://api.example.com',
    'upload/document',
    ['userId', '42', 'description', 'Q4 Report'],  // form fields
    ['file', 'C:\reports\q4.pdf'],                   // file field
    '', 'admin', 'secret');                           // auth
end;
```

### Convert Between Naming Conventions

```pascal
CamelCase('first_name');    // 'firstName'
CamelCase('user_email');    // 'userEmail'
SnakeCase('firstName');     // 'first_name'
SnakeCase('userEmail');     // 'user_email'
```

---

## 8. Exercise: Build a Weather Dashboard

Build an FMX application that fetches weather data from a public API and displays it in a MemTable-backed grid.

### Requirements

1. Use `TTina4REST` configured with `https://api.open-meteo.com` (no API key needed)
2. Use `TTina4RESTRequest` to call `/v1/forecast?latitude=52.52&longitude=13.41&hourly=temperature_2m`
3. Display the hourly temperatures in a `TStringGrid`
4. Add a `TEdit` for latitude and a `TEdit` for longitude so the user can change the location
5. Add a "Refresh" button that re-fetches with the new coordinates

### Hints

- The Open-Meteo API returns JSON with nested structure. The hourly data is under the `hourly` key.
- Set `DataKey` to `hourly` on the `TTina4RESTRequest` -- but note this API returns parallel arrays (`time` and `temperature_2m`), not an array of objects. You may need to use `Tina4Core.SendHttpRequest` directly and parse manually.
- Use `BytesToJSONObject` to parse the response, then extract the arrays yourself.

### Solution

```pascal
unit WeatherForm;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Grid, FMX.Grid.Style, FMX.ScrollBox,
  FireDAC.Comp.Client,
  Tina4Core;

type
  TfrmWeather = class(TForm)
    edtLatitude: TEdit;
    edtLongitude: TEdit;
    btnRefresh: TButton;
    StringGrid1: TStringGrid;
    lblLatitude: TLabel;
    lblLongitude: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
  private
    FMemTable: TFDMemTable;
    procedure FetchWeather;
  end;

var
  frmWeather: TfrmWeather;

implementation

{$R *.fmx}

procedure TfrmWeather.FormCreate(Sender: TObject);
begin
  edtLatitude.Text := '52.52';
  edtLongitude.Text := '13.41';

  FMemTable := TFDMemTable.Create(Self);
  FMemTable.FieldDefs.Add('Time', ftString, 25);
  FMemTable.FieldDefs.Add('Temperature', ftFloat);
  FMemTable.CreateDataSet;
end;

procedure TfrmWeather.btnRefreshClick(Sender: TObject);
begin
  FetchWeather;
end;

procedure TfrmWeather.FetchWeather;
var
  StatusCode: Integer;
  Response: TBytes;
  JSON: TJSONObject;
  Times, Temps: TJSONArray;
  I: Integer;
begin
  Response := SendHttpRequest(StatusCode,
    'https://api.open-meteo.com',
    '/v1/forecast',
    Format('latitude=%s&longitude=%s&hourly=temperature_2m',
      [edtLatitude.Text, edtLongitude.Text]));

  if StatusCode <> 200 then
  begin
    ShowMessage('API returned status: ' + StatusCode.ToString);
    Exit;
  end;

  JSON := BytesToJSONObject(Response);
  try
    if not Assigned(JSON) then
    begin
      ShowMessage('Invalid JSON response');
      Exit;
    end;

    var Hourly := JSON.GetValue<TJSONObject>('hourly');
    Times := Hourly.GetValue<TJSONArray>('time');
    Temps := Hourly.GetValue<TJSONArray>('temperature_2m');

    FMemTable.EmptyDataSet;
    for I := 0 to Times.Count - 1 do
    begin
      FMemTable.Append;
      FMemTable.FieldByName('Time').AsString := Times.Items[I].Value;
      FMemTable.FieldByName('Temperature').AsFloat := Temps.Items[I].AsType<Double>;
      FMemTable.Post;
    end;

    // Populate grid
    StringGrid1.RowCount := FMemTable.RecordCount;
    StringGrid1.ClearColumns;

    var ColTime := TStringColumn.Create(StringGrid1);
    ColTime.Header := 'Time';
    ColTime.Width := 200;
    StringGrid1.AddObject(ColTime);

    var ColTemp := TStringColumn.Create(StringGrid1);
    ColTemp.Header := 'Temperature (C)';
    ColTemp.Width := 150;
    StringGrid1.AddObject(ColTemp);

    FMemTable.First;
    var Row := 0;
    while not FMemTable.Eof do
    begin
      StringGrid1.Cells[0, Row] := FMemTable.FieldByName('Time').AsString;
      StringGrid1.Cells[1, Row] := FormatFloat('0.0', FMemTable.FieldByName('Temperature').AsFloat);
      Inc(Row);
      FMemTable.Next;
    end;
  finally
    JSON.Free;
  end;
end;

end.
```

---

## 9. Common Gotchas

### SSL DLLs Missing

**Symptom**: Status code 0, empty response, or `ENetHTTPClientException`.

**Fix**: Place the correct OpenSSL DLLs in the right directories. 32-bit in `SysWOW64` (for the IDE), 64-bit in `System32` (for your compiled app). Check the DLL version matches your Delphi version.

### Wrong DLL Bitness

**Symptom**: Works in the IDE (32-bit debugger) but fails in a 64-bit release build, or vice versa.

**Fix**: You need both sets. The IDE is 32-bit. Your release build is (usually) 64-bit. Both paths need the correct DLLs.

### Design-Time Package Not Installed

**Symptom**: Components do not appear in the Tool Palette.

**Fix**: Build the runtime package first, then install the design-time package. The design-time package depends on the runtime package. If you skip the runtime build, the install will fail silently or with cryptic linker errors.

### Library Path Missing

**Symptom**: Compiling your project gives "File not found" errors for Tina4 units.

**Fix**: Add the Tina4 source directory to your project's search path, or to the IDE's global library path under **Tools > Options > Delphi Options > Library > Library Path**.

### TJSONObject Memory Leaks

**Symptom**: Growing memory usage over time.

**Fix**: Every `TJSONObject` returned by `Get`, `Post`, `BytesToJSONObject`, `GetJSONFromDB`, etc. must be freed by the caller. Always use `try..finally` blocks. Delphi does not have garbage collection.

---

## 10. What Just Happened

Ten minutes. Two packages installed. One form built. And you covered:

1. Installing the Tina4 component library
2. Setting up SSL for HTTPS
3. Configuring a REST client with `TTina4REST`
4. Fetching data with `TTina4RESTRequest`
5. Automatic JSON-to-MemTable population
6. Standalone utility functions from `Tina4Core`
7. A complete working exercise with solution

The rest of this book goes deep on each component. But you already have a working app. You already have data flowing from an API to your UI. Everything from here is precision and power.

---

## Summary

| What | How |
|---|---|
| Install runtime | Build **Tina4Delphi** package |
| Install design-time | Build and install **Tina4DelphiDesign** package |
| SSL (IDE, 32-bit) | Copy 32-bit DLLs to `SysWOW64` |
| SSL (app, 64-bit) | Copy 64-bit DLLs to `System32` |
| REST base config | `TTina4REST` -- set `BaseUrl`, auth |
| Fetch + populate | `TTina4RESTRequest` -- set endpoint, MemTable, call `ExecuteRESTCall` |
| Raw HTTP | `SendHttpRequest(StatusCode, BaseUrl, Endpoint)` |
| Parse response | `BytesToJSONObject(ResponseBytes)` |
| DB to JSON | `GetJSONFromDB(Connection, SQL)` |
| JSON to MemTable | `PopulateMemTableFromJSON(MemTable, Key, JSON)` |
| File upload | `SendMultipartFormData(...)` |
| Name conversion | `CamelCase(snake)` / `SnakeCase(camel)` |
