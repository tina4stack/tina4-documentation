# Chapter 2: REST APIs

## Two Ways to Talk to the Outside World

Your application needs data from somewhere. A customer database behind an API. A payment gateway. A weather service. A machine learning endpoint. Between your Delphi form and that data sits HTTP -- and two very different ways to make the call.

The first way is component-based. Drop `TTina4REST` and `TTina4RESTRequest` on your form. Set properties. Execute. The MemTable fills. You write no HTTP code, no JSON parsing, no threading boilerplate.

The second way is direct. Call `Tina4REST1.Get()` or `Tina4REST1.Post()` and get a `TJSONObject` back. Full control. Full responsibility -- including freeing the object.

This chapter covers both.

---

## 1. TTina4REST -- Base Configuration

Every REST call needs a server. `TTina4REST` holds that configuration so you set it once and every `TTina4RESTRequest` linked to it inherits the connection details.

### Design-Time Setup

Drop a `TTina4REST` on your form. In the Object Inspector:

| Property | Description | Example |
|---|---|---|
| `BaseUrl` | The root URL for all endpoints | `https://api.example.com/v1` |
| `Username` | HTTP Basic Auth username | `admin` |
| `Password` | HTTP Basic Auth password | `secret` |

### Runtime Configuration

```pascal
Tina4REST1.BaseUrl := 'https://api.example.com/v1';
Tina4REST1.Username := 'admin';
Tina4REST1.Password := 'secret';
```

### Bearer Token Authentication

Most modern APIs use Bearer tokens instead of Basic Auth. Call `SetBearer` after obtaining your token:

```pascal
Tina4REST1.SetBearer('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
```

This adds an `Authorization: Bearer <token>` header to every request made through this component. If you also set `Username` and `Password`, Basic Auth is used instead -- Bearer and Basic Auth are mutually exclusive.

### One Component Per API

If your application talks to multiple APIs, use multiple `TTina4REST` components:

```pascal
// API 1: Your backend
Tina4RESTBackend.BaseUrl := 'https://api.myapp.com/v1';
Tina4RESTBackend.SetBearer(AuthToken);

// API 2: Payment gateway
Tina4RESTPayments.BaseUrl := 'https://payments.stripe.com';
Tina4RESTPayments.SetBearer(StripeKey);

// API 3: Public data
Tina4RESTPublic.BaseUrl := 'https://api.open-meteo.com';
// No auth needed
```

---

## 2. Direct REST Calls

When you need full control over the request and response, call methods directly on `TTina4REST`. All five HTTP methods are supported. All return a `TJSONObject`. All require you to free the result.

### GET

```pascal
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := Tina4REST1.Get(StatusCode, '/users', 'page=1&limit=10');
  try
    if StatusCode = 200 then
      Memo1.Lines.Text := Response.Format
    else
      ShowMessage('Error: ' + StatusCode.ToString);
  finally
    Response.Free;
  end;
end;
```

The three parameters are: `StatusCode` (out), `EndPoint`, and `QueryParams`. The endpoint is appended to the `BaseUrl`. Query params are appended after a `?`.

### POST

```pascal
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := Tina4REST1.Post(StatusCode, '/users', '',
    '{"name": "Alice", "email": "alice@example.com"}');
  try
    if StatusCode = 201 then
      ShowMessage('User created: ' + Response.GetValue<String>('id'))
    else
      ShowMessage('Failed: ' + Response.ToString);
  finally
    Response.Free;
  end;
end;
```

### PATCH (Partial Update)

```pascal
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := Tina4REST1.Patch(StatusCode, '/users/42', '',
    '{"role": "admin"}');
  try
    if StatusCode = 200 then
      ShowMessage('User updated')
    else
      ShowMessage('Failed: ' + StatusCode.ToString);
  finally
    Response.Free;
  end;
end;
```

### PUT (Full Replace)

```pascal
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := Tina4REST1.Put(StatusCode, '/users/42', '',
    '{"name": "Alice", "email": "alice@new.com", "role": "admin"}');
  try
    // handle response
  finally
    Response.Free;
  end;
end;
```

### DELETE

```pascal
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := Tina4REST1.Delete(StatusCode, '/users/42');
  try
    if StatusCode = 204 then
      ShowMessage('Deleted')
    else
      ShowMessage('Failed: ' + StatusCode.ToString);
  finally
    Response.Free;
  end;
end;
```

### Method Reference

| Method | Signature | HTTP Verb |
|---|---|---|
| `Get` | `Get(var StatusCode: Integer; EndPoint: string; QueryParams: string = ''): TJSONObject` | GET |
| `Post` | `Post(var StatusCode: Integer; EndPoint: string; QueryParams: string = ''; Body: string = ''): TJSONObject` | POST |
| `Patch` | `Patch(var StatusCode: Integer; EndPoint: string; QueryParams: string = ''; Body: string = ''): TJSONObject` | PATCH |
| `Put` | `Put(var StatusCode: Integer; EndPoint: string; QueryParams: string = ''; Body: string = ''): TJSONObject` | PUT |
| `Delete` | `Delete(var StatusCode: Integer; EndPoint: string; QueryParams: string = ''): TJSONObject` | DELETE |

---

## 3. Authentication Patterns

### Basic Auth

Set `Username` and `Password` on `TTina4REST`. Every request includes an `Authorization: Basic` header automatically:

```pascal
Tina4REST1.BaseUrl := 'https://api.example.com';
Tina4REST1.Username := 'apiuser';
Tina4REST1.Password := 'apipassword';
```

### Bearer Token (Static)

If you have a long-lived API key or token:

```pascal
Tina4REST1.BaseUrl := 'https://api.example.com';
Tina4REST1.SetBearer('your-api-key-here');
```

### Bearer Token (Login Flow)

Most apps require a login step that returns a short-lived token:

```pascal
procedure TForm1.Login;
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  // Use a temporary REST component with no auth for the login call
  Tina4REST1.BaseUrl := 'https://api.example.com';

  Response := Tina4REST1.Post(StatusCode, '/auth/login', '',
    Format('{"email": "%s", "password": "%s"}',
      [edtEmail.Text, edtPassword.Text]));
  try
    if StatusCode = 200 then
    begin
      var Token := Response.GetValue<String>('token');
      Tina4REST1.SetBearer(Token);
      ShowMessage('Logged in successfully');
    end
    else
      ShowMessage('Login failed: ' + Response.GetValue<String>('message'));
  finally
    Response.Free;
  end;
end;
```

### Custom Headers

For APIs that require custom headers (API keys in headers, tenant IDs, etc.), use `SendHttpRequest` from `Tina4Core` directly:

```pascal
uses Tina4Core;

var
  StatusCode: Integer;
  Headers: TNetHeaders;
  Response: TBytes;
begin
  SetLength(Headers, 2);
  Headers[0] := TNameValuePair.Create('X-API-Key', 'my-key-123');
  Headers[1] := TNameValuePair.Create('X-Tenant-Id', 'acme-corp');

  Response := SendHttpRequest(StatusCode,
    'https://api.example.com', '/data', '', '',
    'application/json', 'utf-8', '', '', Headers);
end;
```

---

## 4. TTina4RESTRequest -- Declarative REST

Direct calls give you control. `TTina4RESTRequest` gives you convenience. Link it to a `TTina4REST`, set properties, and execute. The component handles the HTTP call, parses the JSON response, creates MemTable field definitions, and populates the table. One method call.

### Basic GET with Auto MemTable Population

Drop these on your form:
- `TTina4REST` (name: `Tina4REST1`)
- `TTina4RESTRequest` (name: `Tina4RESTRequest1`)
- `TFDMemTable` (name: `FDMemTable1`)

Configure `Tina4RESTRequest1`:

| Property | Value |
|---|---|
| `Tina4REST` | `Tina4REST1` |
| `EndPoint` | `/users` |
| `RequestType` | `Get` |
| `DataKey` | `records` |
| `MemTable` | `FDMemTable1` |
| `SyncMode` | `Clear` |

Execute:

```pascal
Tina4RESTRequest1.ExecuteRESTCall;
// FDMemTable1 now contains all users from the "records" array
```

The `DataKey` tells the component which JSON key contains the array of records. If your API returns `{"records": [...]}`, set `DataKey` to `records`. If the response is a bare JSON array `[...]`, leave `DataKey` empty.

### POST with RequestBody

```pascal
Tina4RESTRequest1.RequestType := TTina4RequestType.Post;
Tina4RESTRequest1.EndPoint := '/users';
Tina4RESTRequest1.RequestBody.Text :=
  '{"name": "Alice", "email": "alice@example.com", "role": "editor"}';
Tina4RESTRequest1.ExecuteRESTCall;
```

The `RequestBody` is a `TStringList`. Set it with `.Text` for single-line JSON, or use `.Add` for multiline construction.

### PUT / PATCH / DELETE

Change the `RequestType` property:

```pascal
// Update
Tina4RESTRequest1.RequestType := TTina4RequestType.Put;
Tina4RESTRequest1.EndPoint := '/users/42';
Tina4RESTRequest1.RequestBody.Text := '{"name": "Alice Updated"}';
Tina4RESTRequest1.ExecuteRESTCall;

// Delete
Tina4RESTRequest1.RequestType := TTina4RequestType.Delete;
Tina4RESTRequest1.EndPoint := '/users/42';
Tina4RESTRequest1.ExecuteRESTCall;
```

---

## 5. Master/Detail with Parameter Injection

This is where `TTina4RESTRequest` earns its keep. Set a `MasterSource` and the detail request injects field values from the master's MemTable into the endpoint, request body, and query params using `{fieldName}` placeholders.

### Setup

```pascal
// Master: fetches all customers
Tina4RESTRequest1.Tina4REST := Tina4REST1;
Tina4RESTRequest1.EndPoint := '/customers';
Tina4RESTRequest1.DataKey := 'records';
Tina4RESTRequest1.MemTable := FDMemTableCustomers;
Tina4RESTRequest1.RequestType := TTina4RequestType.Get;

// Detail: fetches orders for the selected customer
Tina4RESTRequest2.Tina4REST := Tina4REST1;
Tina4RESTRequest2.MasterSource := Tina4RESTRequest1;
Tina4RESTRequest2.EndPoint := '/customers/{id}/orders';
Tina4RESTRequest2.DataKey := 'records';
Tina4RESTRequest2.MemTable := FDMemTableOrders;
Tina4RESTRequest2.RequestType := TTina4RequestType.Get;
```

When the master executes and the user navigates to a customer with `id = 5`, the detail's endpoint becomes `/customers/5/orders`. The `{id}` placeholder is replaced with the current value of the `id` field from `FDMemTableCustomers`.

### How It Works

1. The master request executes and populates `FDMemTableCustomers`.
2. When you scroll to a different row in `FDMemTableCustomers`, the detail request re-executes automatically.
3. The detail request scans its `EndPoint`, `RequestBody`, and `QueryParams` for `{fieldName}` patterns.
4. Each pattern is replaced with the current field value from the master's MemTable.

### Multiple Placeholders

You can use multiple placeholders:

```pascal
Tina4RESTRequest2.EndPoint := '/customers/{customerId}/orders';
Tina4RESTRequest2.RequestBody.Text :=
  '{"customerId": "{customerId}", "status": "active"}';
```

---

## 6. POST from SourceMemTable

Sometimes you need to send data that already exists in a MemTable -- an import batch, a modified dataset, user edits. Instead of manually serializing rows to JSON, link a `SourceMemTable`:

```pascal
Tina4RESTRequest1.RequestType := TTina4RequestType.Post;
Tina4RESTRequest1.EndPoint := '/import/products';
Tina4RESTRequest1.SourceMemTable := FDMemTableProducts;
Tina4RESTRequest1.SourceIgnoreFields := 'internal_id,temp_flag';
Tina4RESTRequest1.SourceIgnoreBlanks := True;
Tina4RESTRequest1.ExecuteRESTCall;
```

The component serializes all rows from `FDMemTableProducts` to a JSON array and sends it as the POST body. Fields listed in `SourceIgnoreFields` are excluded. If `SourceIgnoreBlanks` is `True`, fields with empty values are omitted from each row.

---

## 7. Async Execution

REST calls block the main thread. For a quick local API, that is fine. For a slow endpoint or a large response, your UI freezes. `ExecuteRESTCallAsync` runs the request in a background thread.

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  Tina4RESTRequest1.OnExecuteDone := HandleRequestDone;
end;

procedure TForm1.HandleRequestDone(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    ShowMessage('Loaded ' + FDMemTable1.RecordCount.ToString + ' records');
    // Update your grid or UI here -- you are now on the main thread
  end);
end;

procedure TForm1.btnFetchClick(Sender: TObject);
begin
  btnFetch.Enabled := False;
  Tina4RESTRequest1.ExecuteRESTCallAsync;
end;
```

### Thread Safety Rules

1. **Never access UI controls from the background thread.** The `OnExecuteDone` event fires on the background thread. Wrap all UI updates in `TThread.Synchronize`.
2. **The MemTable is populated before `OnExecuteDone` fires.** You can read the MemTable inside the synchronized block.
3. **Disable buttons while the request is in flight.** Re-enable them in `OnExecuteDone`.

---

## 8. Events

### OnExecuteDone

Fires after the REST call completes and the MemTable is populated (if configured). Use it for post-processing, UI updates, or chaining requests:

```pascal
procedure TForm1.Request1ExecuteDone(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    lblCount.Text := Format('%d records loaded', [FDMemTable1.RecordCount]);

    // Chain: now fetch details for the first record
    if FDMemTable1.RecordCount > 0 then
    begin
      FDMemTable1.First;
      Tina4RESTRequest2.ExecuteRESTCall;
    end;
  end);
end;
```

### OnAddRecord

Fires for each record added to the MemTable during population. Use it for custom field transformations, filtering, or logging:

```pascal
procedure TForm1.Request1AddRecord(Sender: TObject);
begin
  // Access the MemTable -- the cursor is on the newly added record
  var Status := FDMemTable1.FieldByName('status').AsString;
  if Status = 'inactive' then
    FDMemTable1.Delete;  // Remove inactive records during import
end;
```

---

## 9. Complete Example: Customer Management Panel

A real-world scenario. List customers. View details. Create new ones. Update existing ones. Four operations, four REST calls, one form.

### Form Design

- `TTina4REST` (name: `restAPI`, BaseUrl: `https://api.example.com/v1`)
- `TTina4RESTRequest` (name: `reqListCustomers`)
- `TTina4RESTRequest` (name: `reqCreateCustomer`)
- `TTina4RESTRequest` (name: `reqUpdateCustomer`)
- `TFDMemTable` (name: `mtCustomers`)
- `TStringGrid` (name: `gridCustomers`)
- `TEdit` (name: `edtName`)
- `TEdit` (name: `edtEmail`)
- `TButton` (name: `btnLoad`, Text: `Load`)
- `TButton` (name: `btnSave`, Text: `Save`)
- `TLabel` (name: `lblStatus`)

### Implementation

```pascal
unit CustomerPanel;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Grid, FMX.Grid.Style, FMX.ScrollBox, FMX.Layouts,
  FireDAC.Comp.Client,
  Tina4REST, Tina4RESTRequest;

type
  TfrmCustomers = class(TForm)
    restAPI: TTina4REST;
    reqListCustomers: TTina4RESTRequest;
    reqCreateCustomer: TTina4RESTRequest;
    reqUpdateCustomer: TTina4RESTRequest;
    mtCustomers: TFDMemTable;
    gridCustomers: TStringGrid;
    edtName: TEdit;
    edtEmail: TEdit;
    btnLoad: TButton;
    btnSave: TButton;
    lblStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure gridCustomersSelectCell(Sender: TObject; const ACol, ARow: Integer;
      var CanSelect: Boolean);
  private
    FSelectedId: string;
    procedure SetupRequests;
    procedure RefreshGrid;
    procedure SetStatus(const Msg: string);
  end;

var
  frmCustomers: TfrmCustomers;

implementation

{$R *.fmx}

procedure TfrmCustomers.FormCreate(Sender: TObject);
begin
  restAPI.BaseUrl := 'https://api.example.com/v1';
  restAPI.SetBearer('your-token-here');
  FSelectedId := '';
  SetupRequests;
end;

procedure TfrmCustomers.SetupRequests;
begin
  // List customers
  reqListCustomers.Tina4REST := restAPI;
  reqListCustomers.EndPoint := '/customers';
  reqListCustomers.RequestType := TTina4RequestType.Get;
  reqListCustomers.DataKey := 'records';
  reqListCustomers.MemTable := mtCustomers;
  reqListCustomers.SyncMode := TTina4RestSyncMode.Clear;

  // Create customer
  reqCreateCustomer.Tina4REST := restAPI;
  reqCreateCustomer.EndPoint := '/customers';
  reqCreateCustomer.RequestType := TTina4RequestType.Post;

  // Update customer
  reqUpdateCustomer.Tina4REST := restAPI;
  reqUpdateCustomer.RequestType := TTina4RequestType.Put;
end;

procedure TfrmCustomers.btnLoadClick(Sender: TObject);
begin
  reqListCustomers.ExecuteRESTCall;
  RefreshGrid;
  SetStatus(Format('Loaded %d customers', [mtCustomers.RecordCount]));
end;

procedure TfrmCustomers.btnSaveClick(Sender: TObject);
var
  Body: string;
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Body := Format('{"name": "%s", "email": "%s"}',
    [edtName.Text, edtEmail.Text]);

  if FSelectedId <> '' then
  begin
    // Update existing customer
    Response := restAPI.Put(StatusCode,
      '/customers/' + FSelectedId, '', Body);
    try
      if StatusCode = 200 then
        SetStatus('Customer updated')
      else
        SetStatus('Update failed: ' + StatusCode.ToString);
    finally
      Response.Free;
    end;
  end
  else
  begin
    // Create new customer
    Response := restAPI.Post(StatusCode, '/customers', '', Body);
    try
      if StatusCode = 201 then
        SetStatus('Customer created')
      else
        SetStatus('Create failed: ' + StatusCode.ToString);
    finally
      Response.Free;
    end;
  end;

  // Refresh the list
  FSelectedId := '';
  edtName.Text := '';
  edtEmail.Text := '';
  btnLoadClick(nil);
end;

procedure TfrmCustomers.gridCustomersSelectCell(Sender: TObject;
  const ACol, ARow: Integer; var CanSelect: Boolean);
begin
  if ARow < mtCustomers.RecordCount then
  begin
    mtCustomers.RecNo := ARow + 1;
    FSelectedId := mtCustomers.FieldByName('id').AsString;
    edtName.Text := mtCustomers.FieldByName('name').AsString;
    edtEmail.Text := mtCustomers.FieldByName('email').AsString;
  end;
end;

procedure TfrmCustomers.RefreshGrid;
begin
  gridCustomers.RowCount := mtCustomers.RecordCount;
  gridCustomers.ClearColumns;

  var ColId := TStringColumn.Create(gridCustomers);
  ColId.Header := 'ID';
  ColId.Width := 50;
  gridCustomers.AddObject(ColId);

  var ColName := TStringColumn.Create(gridCustomers);
  ColName.Header := 'Name';
  ColName.Width := 200;
  gridCustomers.AddObject(ColName);

  var ColEmail := TStringColumn.Create(gridCustomers);
  ColEmail.Header := 'Email';
  ColEmail.Width := 250;
  gridCustomers.AddObject(ColEmail);

  mtCustomers.First;
  var Row := 0;
  while not mtCustomers.Eof do
  begin
    gridCustomers.Cells[0, Row] := mtCustomers.FieldByName('id').AsString;
    gridCustomers.Cells[1, Row] := mtCustomers.FieldByName('name').AsString;
    gridCustomers.Cells[2, Row] := mtCustomers.FieldByName('email').AsString;
    Inc(Row);
    mtCustomers.Next;
  end;
end;

procedure TfrmCustomers.SetStatus(const Msg: string);
begin
  lblStatus.Text := Msg;
end;

end.
```

---

## 10. Exercise: Product Catalog

Build a product management application with the following features:

### Requirements

1. Fetch products from `GET /products` (use jsonplaceholder or your own API)
2. Display products in a `TStringGrid`
3. Add a search `TEdit` that filters products by title (client-side filtering on the MemTable)
4. Add a form to create new products via `POST /products`
5. Use async execution for the initial load with a loading indicator

### Solution

```pascal
unit ProductCatalog;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Grid, FMX.Grid.Style, FMX.ScrollBox, FMX.Layouts,
  FireDAC.Comp.Client,
  Tina4REST, Tina4RESTRequest;

type
  TfrmProducts = class(TForm)
    restAPI: TTina4REST;
    reqProducts: TTina4RESTRequest;
    mtProducts: TFDMemTable;
    gridProducts: TStringGrid;
    edtSearch: TEdit;
    edtTitle: TEdit;
    edtPrice: TEdit;
    btnCreate: TButton;
    lblLoading: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure edtSearchChangeTracking(Sender: TObject);
    procedure btnCreateClick(Sender: TObject);
  private
    procedure OnProductsLoaded(Sender: TObject);
    procedure RefreshGrid;
    procedure FilterGrid(const SearchText: string);
  end;

var
  frmProducts: TfrmProducts;

implementation

{$R *.fmx}

procedure TfrmProducts.FormCreate(Sender: TObject);
begin
  restAPI.BaseUrl := 'https://jsonplaceholder.typicode.com';

  reqProducts.Tina4REST := restAPI;
  reqProducts.EndPoint := '/posts'; // Using posts as stand-in for products
  reqProducts.RequestType := TTina4RequestType.Get;
  reqProducts.MemTable := mtProducts;
  reqProducts.SyncMode := TTina4RestSyncMode.Clear;

  reqProducts.OnExecuteDone := OnProductsLoaded;

  lblLoading.Text := 'Loading products...';
  lblLoading.Visible := True;
  reqProducts.ExecuteRESTCallAsync;
end;

procedure TfrmProducts.OnProductsLoaded(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    lblLoading.Visible := False;
    RefreshGrid;
  end);
end;

procedure TfrmProducts.RefreshGrid;
begin
  gridProducts.RowCount := mtProducts.RecordCount;
  gridProducts.ClearColumns;

  for var I := 0 to mtProducts.FieldCount - 1 do
  begin
    var Col := TStringColumn.Create(gridProducts);
    Col.Header := mtProducts.Fields[I].FieldName;
    Col.Width := 150;
    gridProducts.AddObject(Col);
  end;

  mtProducts.First;
  var Row := 0;
  while not mtProducts.Eof do
  begin
    for var C := 0 to mtProducts.FieldCount - 1 do
      gridProducts.Cells[C, Row] := mtProducts.Fields[C].AsString;
    Inc(Row);
    mtProducts.Next;
  end;
end;

procedure TfrmProducts.edtSearchChangeTracking(Sender: TObject);
begin
  FilterGrid(edtSearch.Text);
end;

procedure TfrmProducts.FilterGrid(const SearchText: string);
var
  Row: Integer;
begin
  if SearchText = '' then
  begin
    RefreshGrid;
    Exit;
  end;

  Row := 0;
  gridProducts.RowCount := 0;

  mtProducts.First;
  while not mtProducts.Eof do
  begin
    var Title := mtProducts.FieldByName('title').AsString;
    if Title.ToLower.Contains(SearchText.ToLower) then
    begin
      gridProducts.RowCount := Row + 1;
      for var C := 0 to mtProducts.FieldCount - 1 do
        gridProducts.Cells[C, Row] := mtProducts.Fields[C].AsString;
      Inc(Row);
    end;
    mtProducts.Next;
  end;
end;

procedure TfrmProducts.btnCreateClick(Sender: TObject);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := restAPI.Post(StatusCode, '/posts', '',
    Format('{"title": "%s", "body": "%s", "userId": 1}',
      [edtTitle.Text, edtPrice.Text]));
  try
    if StatusCode = 201 then
    begin
      ShowMessage('Product created with ID: ' + Response.GetValue<String>('id'));
      edtTitle.Text := '';
      edtPrice.Text := '';
    end
    else
      ShowMessage('Failed: ' + StatusCode.ToString);
  finally
    Response.Free;
  end;
end;

end.
```

---

## 11. Common Gotchas

### Forgetting to Free TJSONObject

**Symptom**: Memory usage grows over time. ReportMemoryLeaksOnShutdown shows leaks.

**Fix**: Every `Get`, `Post`, `Patch`, `Put`, and `Delete` call returns a `TJSONObject` that you own. Always wrap in `try..finally`:

```pascal
var Response := Tina4REST1.Get(StatusCode, '/data');
try
  // use Response
finally
  Response.Free;  // Always. Every time.
end;
```

### Not Checking StatusCode

**Symptom**: Application crashes when trying to read fields from an error response.

**Fix**: Always check the status code before accessing response data:

```pascal
Response := Tina4REST1.Get(StatusCode, '/users/999');
try
  if StatusCode = 200 then
    ProcessUser(Response)
  else if StatusCode = 404 then
    ShowMessage('User not found')
  else
    ShowMessage('Unexpected error: ' + StatusCode.ToString);
finally
  Response.Free;
end;
```

### Async Thread Safety

**Symptom**: Intermittent access violations, garbled UI, or "Canvas does not allow drawing" errors.

**Fix**: Never touch UI controls from `OnExecuteDone` without `TThread.Synchronize`:

```pascal
// WRONG -- will crash randomly
procedure TForm1.OnDone(Sender: TObject);
begin
  lblStatus.Text := 'Done';  // Main thread violation
end;

// CORRECT
procedure TForm1.OnDone(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    lblStatus.Text := 'Done';  // Safe -- runs on main thread
  end);
end;
```

### DataKey Mismatch

**Symptom**: MemTable is empty after a successful request.

**Fix**: Check that `DataKey` matches the JSON structure. If the API returns `{"data": [...]}`, set `DataKey` to `data`. If it returns `{"results": [...]}`, set it to `results`. If the response is a bare array `[...]`, leave `DataKey` empty.

### BaseUrl Trailing Slash

**Symptom**: 404 errors on endpoints that work in the browser.

**Fix**: Do not include a trailing slash on `BaseUrl`. The endpoint already starts with `/`:

```pascal
// WRONG
Tina4REST1.BaseUrl := 'https://api.example.com/v1/';
// Endpoint '/users' becomes 'https://api.example.com/v1//users'

// CORRECT
Tina4REST1.BaseUrl := 'https://api.example.com/v1';
```

---

## Summary

| What | How |
|---|---|
| Base configuration | `TTina4REST` -- set `BaseUrl`, auth |
| Basic Auth | Set `Username` and `Password` |
| Bearer token | `SetBearer('token')` |
| Direct GET | `Tina4REST1.Get(StatusCode, '/endpoint', 'params')` |
| Direct POST | `Tina4REST1.Post(StatusCode, '/endpoint', '', Body)` |
| Direct PATCH | `Tina4REST1.Patch(StatusCode, '/endpoint', '', Body)` |
| Direct PUT | `Tina4REST1.Put(StatusCode, '/endpoint', '', Body)` |
| Direct DELETE | `Tina4REST1.Delete(StatusCode, '/endpoint')` |
| Declarative GET | `TTina4RESTRequest` -- set endpoint, MemTable, `ExecuteRESTCall` |
| Master/Detail | Set `MasterSource`, use `{fieldName}` placeholders |
| POST from MemTable | Set `SourceMemTable`, call `ExecuteRESTCall` |
| Async | `ExecuteRESTCallAsync` + `OnExecuteDone` + `TThread.Synchronize` |
| Memory rule | Every `TJSONObject` returned must be freed by the caller |
