# Chapter 3: JSON & Data Binding

## The Bridge Between APIs and Grids

Your API returns JSON. Your grid displays MemTable rows. Between these two worlds sits a translation layer -- field names need converting, dates need formatting, nested objects need flattening, and records need matching for updates. Tina4 Delphi handles all of this with a set of utility functions and one component.

This chapter covers the full JSON pipeline: parsing raw strings, converting database queries to JSON, populating MemTables from JSON, syncing changes, and binding data declaratively with `TTina4JSONAdapter`.

---

## 1. JSON Parsing Utilities

Before you can work with JSON data, you need to parse it. `Tina4Core.pas` provides four parsing functions that handle the common cases.

### StrToJSONObject

Parses a JSON string into a `TJSONObject`. Returns `nil` if parsing fails -- always check with `Assigned`.

```pascal
uses Tina4Core;

var Obj := StrToJSONObject('{"name": "Alice", "age": 30, "active": true}');
try
  if Assigned(Obj) then
  begin
    ShowMessage(Obj.GetValue<String>('name'));     // 'Alice'
    ShowMessage(Obj.GetValue<Integer>('age').ToString);  // '30'
    ShowMessage(Obj.GetValue<Boolean>('active').ToString); // 'True'
  end
  else
    ShowMessage('Invalid JSON');
finally
  Obj.Free;
end;
```

### StrToJSONArray

Parses a JSON string into a `TJSONArray`. Use this when the root element is an array:

```pascal
var Arr := StrToJSONArray('[{"id": 1}, {"id": 2}, {"id": 3}]');
try
  if Assigned(Arr) then
    for var I := 0 to Arr.Count - 1 do
      ShowMessage((Arr.Items[I] as TJSONObject).GetValue<String>('id'));
finally
  Arr.Free;
end;
```

### StrToJSONValue

When you do not know whether the input is an object, array, string, number, or boolean:

```pascal
var Val := StrToJSONValue(SomeInput);
try
  if Val is TJSONObject then
    ProcessObject(Val as TJSONObject)
  else if Val is TJSONArray then
    ProcessArray(Val as TJSONArray)
  else
    ShowMessage('Primitive: ' + Val.Value);
finally
  Val.Free;
end;
```

### BytesToJSONObject

Parses raw `TBytes` directly -- the typical output of `SendHttpRequest`:

```pascal
var
  StatusCode: Integer;
  Response: TBytes;
begin
  Response := SendHttpRequest(StatusCode, 'https://api.example.com', '/users');
  var JSON := BytesToJSONObject(Response);
  try
    if Assigned(JSON) then
      Memo1.Lines.Text := JSON.Format;
  finally
    JSON.Free;
  end;
end;
```

### GetJSONFieldName

Strips surrounding quotes from a JSON field name. Useful when iterating `TJSONPair` elements:

```pascal
GetJSONFieldName('"firstName"');  // 'firstName'
GetJSONFieldName('age');          // 'age'
```

---

## 2. TTina4JSONAdapter -- Static JSON to MemTable

`TTina4JSONAdapter` is the declarative way to bind JSON data to a `TFDMemTable`. Drop it on your form, set the JSON, set the data key, and execute. No parsing code. No field definition code. No population loops.

### From Static JSON

```pascal
// Design-time or runtime:
Tina4JSONAdapter1.MemTable := FDMemTable1;
Tina4JSONAdapter1.DataKey := 'products';
Tina4JSONAdapter1.JSONData.Text :=
  '{"products": [' +
  '  {"id": "1", "name": "Widget", "price": 9.99},' +
  '  {"id": "2", "name": "Gadget", "price": 24.99},' +
  '  {"id": "3", "name": "Doohickey", "price": 4.50}' +
  ']}';
Tina4JSONAdapter1.Execute;
// FDMemTable1 now has 3 rows with id, name, price columns
```

### From MasterSource

Link the adapter to a `TTina4RESTRequest` and it auto-executes whenever the master's `OnExecuteDone` fires:

```pascal
// The REST request fetches data that contains embedded JSON
Tina4RESTRequest1.EndPoint := '/dashboard';
Tina4RESTRequest1.MemTable := FDMemTableDashboard;

// The adapter extracts a nested array from the response
Tina4JSONAdapter1.MasterSource := Tina4RESTRequest1;
Tina4JSONAdapter1.DataKey := 'recentOrders';
Tina4JSONAdapter1.MemTable := FDMemTableOrders;
// When Tina4RESTRequest1 completes, FDMemTableOrders auto-populates
```

This works well for APIs that return complex nested responses. The REST request gets the whole response into one MemTable. The JSON adapter extracts a specific nested array into another MemTable.

### Sync Mode

By default, `Execute` clears the MemTable and replaces all data. For incremental updates, use `Sync` mode:

```pascal
Tina4JSONAdapter1.SyncMode := TTina4RestSyncMode.Sync;
Tina4JSONAdapter1.IndexFieldNames := 'id';
```

| Sync Mode | Behavior |
|---|---|
| `Clear` (default) | Empties the table first, then appends all records |
| `Sync` | Matches records by `IndexFieldNames`, updates existing rows, inserts new ones |

`Sync` mode requires `IndexFieldNames` to be set. This is the field (or fields) used to match existing rows against incoming JSON records. Without it, sync mode cannot determine which rows to update.

---

## 3. Database to JSON

Going the other direction -- from database to JSON -- is equally common. You query a database and need to send the results to a REST API, save to a file, or display in an HTML template.

### GetJSONFromDB

Executes a SQL query and returns the results as a `TJSONObject`. Three automatic conversions happen:

1. **Field names** convert from `snake_case` to `camelCase` (e.g., `first_name` becomes `firstName`)
2. **DateTime fields** format as ISO 8601 (e.g., `2024-06-15T14:30:00.000Z`)
3. **Blob fields** encode as Base64

```pascal
// Simple query
var Result := GetJSONFromDB(FDConnection1, 'SELECT * FROM users');
try
  Memo1.Lines.Text := Result.Format;
  // {"records": [
  //   {"id": "1", "firstName": "Alice", "email": "alice@example.com", ...},
  //   {"id": "2", "firstName": "Bob", "email": "bob@example.com", ...}
  // ]}
finally
  Result.Free;
end;
```

The default dataset key is `records`. To use a custom key:

```pascal
var Result := GetJSONFromDB(FDConnection1,
  'SELECT * FROM cats', nil, 'cats');
// {"cats": [{"id": "1", "name": "Whiskers"}, ...]}
```

### With Parameters

Use `TFDParams` for parameterized queries to prevent SQL injection:

```pascal
var Params := TFDParams.Create;
try
  Params.Add('status', 'active');
  Params.Add('minAge', 18);

  var Result := GetJSONFromDB(FDConnection1,
    'SELECT * FROM users WHERE status = :status AND age >= :minAge',
    Params);
  try
    Memo1.Lines.Text := Result.Format;
  finally
    Result.Free;
  end;
finally
  Params.Free;
end;
```

### GetJSONFromTable

Converts an existing `TFDMemTable` or `TFDTable` to JSON. Useful when you have data already loaded and need to serialize it:

```pascal
// Basic conversion
var JSON := GetJSONFromTable(FDMemTable1);
try
  Memo1.Lines.Text := JSON.Format;
  // {"records": [{"id": "1", "name": "Item1"}, ...]}
finally
  JSON.Free;
end;
```

Ignore specific fields (passwords, internal IDs):

```pascal
var JSON := GetJSONFromTable(FDMemTable1, 'records', 'password,internal_id');
```

Ignore blank values to reduce payload size:

```pascal
var JSON := GetJSONFromTable(FDMemTable1, 'records', '', True);
// Fields with empty string values are omitted from each record
```

---

## 4. JSON to MemTable

The reverse pipeline. You have JSON data and need it in a `TFDMemTable` for display, editing, or further processing.

### GetFieldDefsFromJSONObject

Creates field definitions on a MemTable from a JSON object's structure. You call this once to set up the schema, then populate rows:

```pascal
var JSONObj := StrToJSONObject(
  '{"firstName": "Alice", "age": 30, "address": {"city": "Cape Town"}}');
try
  GetFieldDefsFromJSONObject(JSONObj, FDMemTable1, True);
  // Creates fields:
  //   first_name : ftString  (camelCase converted to snake_case with True flag)
  //   age        : ftString
  //   address    : ftMemo    (nested object becomes ftMemo)
  FDMemTable1.CreateDataSet;
finally
  JSONObj.Free;
end;
```

The third parameter controls snake_case conversion. Pass `True` to convert `firstName` to `first_name`. Pass `False` to keep JSON field names as-is.

Nested objects and arrays become `ftMemo` fields containing the serialized JSON string.

### PopulateMemTableFromJSON

The main workhorse. Takes a JSON string, extracts the array at the specified data key, and populates a MemTable. If the MemTable has no field definitions, they are created automatically from the first JSON object.

#### Clear Mode (Default)

Empties the table and replaces all data:

```pascal
var JSONStr :=
  '{"records": [' +
  '  {"id": "1", "name": "Alice", "email": "alice@example.com"},' +
  '  {"id": "2", "name": "Bob", "email": "bob@example.com"}' +
  ']}';

PopulateMemTableFromJSON(FDMemTable1, 'records', JSONStr);
// FDMemTable1 has 2 rows, any previous data is gone
```

#### Sync Mode

Matches existing rows by key fields and updates them. New rows are inserted. Existing rows not in the JSON are left unchanged:

```pascal
// Initial load
PopulateMemTableFromJSON(FDMemTable1, 'records',
  '{"records": [{"id": "1", "name": "Alice"}, {"id": "2", "name": "Bob"}]}');

// Later: update Alice, add Charlie, Bob stays unchanged
PopulateMemTableFromJSON(FDMemTable1, 'records',
  '{"records": [{"id": "1", "name": "Alice Updated"}, {"id": "3", "name": "Charlie"}]}',
  'id', TTina4RestSyncMode.Sync);

// Result: 3 rows
//   id=1: Alice Updated (updated)
//   id=2: Bob (unchanged)
//   id=3: Charlie (inserted)
```

The fourth parameter is `IndexFieldNames` -- the field(s) used for matching. For composite keys, separate with semicolons: `'tenantId;userId'`.

### PopulateTableFromJSON

Inserts or updates rows directly into a database table (not a MemTable) from JSON. Uses a primary key for upsert logic:

```pascal
var Result := PopulateTableFromJSON(
  FDConnection1,           // database connection
  'users',                 // table name
  '{"response": [{"name": "Alice"}, {"name": "Bob"}]}',
  'response',              // data key
  'id');                   // primary key field for upsert
```

This is useful for bulk imports -- JSON data goes directly to the database without an intermediate MemTable.

---

## 5. Naming Conventions

Tina4 Delphi automatically converts between naming conventions at every boundary:

| Direction | From | To | Example |
|---|---|---|---|
| Database to JSON | `snake_case` | `camelCase` | `first_name` becomes `firstName` |
| JSON to MemTable | `camelCase` | `snake_case` (optional) | `firstName` becomes `first_name` |

### CamelCase

```pascal
CamelCase('first_name');     // 'firstName'
CamelCase('id');             // 'id'
CamelCase('user_email');     // 'userEmail'
CamelCase('created_at');     // 'createdAt'
```

### SnakeCase

```pascal
SnakeCase('firstName');      // 'first_name'
SnakeCase('userEmail');      // 'user_email'
SnakeCase('createdAt');      // 'created_at'
```

This matters because databases typically use `snake_case` column names while JSON APIs use `camelCase` keys. Tina4 handles the translation transparently when using `GetJSONFromDB` and `GetFieldDefsFromJSONObject`.

---

## 6. Complete Example: Data Import/Export Tool

A realistic scenario: fetch data from an API, display it in a grid, let the user edit rows, and push changes back to the API.

```pascal
unit ImportExport;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Grid, FMX.Grid.Style, FMX.ScrollBox, FMX.Memo, FMX.Layouts,
  FireDAC.Comp.Client,
  Tina4Core, Tina4REST, Tina4RESTRequest;

type
  TfrmImportExport = class(TForm)
    restAPI: TTina4REST;
    mtData: TFDMemTable;
    gridData: TStringGrid;
    btnFetch: TButton;
    btnPushChanges: TButton;
    memoLog: TMemo;
    lblStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnFetchClick(Sender: TObject);
    procedure btnPushChangesClick(Sender: TObject);
  private
    procedure RefreshGrid;
    procedure Log(const Msg: string);
  end;

var
  frmImportExport: TfrmImportExport;

implementation

{$R *.fmx}

procedure TfrmImportExport.FormCreate(Sender: TObject);
begin
  restAPI.BaseUrl := 'https://jsonplaceholder.typicode.com';
end;

procedure TfrmImportExport.btnFetchClick(Sender: TObject);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Log('Fetching users...');

  Response := restAPI.Get(StatusCode, '/users');
  try
    if StatusCode <> 200 then
    begin
      Log('Failed: HTTP ' + StatusCode.ToString);
      Exit;
    end;

    // The response is a JSON array, but Tina4REST wraps it
    // Use PopulateMemTableFromJSON for direct control
    PopulateMemTableFromJSON(mtData, '', Response.ToString);
    RefreshGrid;
    Log(Format('Loaded %d users', [mtData.RecordCount]));
  finally
    Response.Free;
  end;
end;

procedure TfrmImportExport.btnPushChangesClick(Sender: TObject);
var
  StatusCode: Integer;
  Response: TJSONObject;
  JSON: TJSONObject;
begin
  // Serialize the MemTable to JSON
  JSON := GetJSONFromTable(mtData);
  try
    Log('Pushing changes...');
    Log('Payload: ' + JSON.ToString);

    // In a real app, POST this to your API
    Response := restAPI.Post(StatusCode, '/users', '', JSON.ToString);
    try
      if StatusCode in [200, 201] then
        Log('Changes pushed successfully')
      else
        Log('Push failed: HTTP ' + StatusCode.ToString);
    finally
      Response.Free;
    end;
  finally
    JSON.Free;
  end;
end;

procedure TfrmImportExport.RefreshGrid;
begin
  gridData.RowCount := mtData.RecordCount;
  gridData.ClearColumns;

  for var I := 0 to mtData.FieldCount - 1 do
  begin
    var Col := TStringColumn.Create(gridData);
    Col.Header := mtData.Fields[I].FieldName;
    Col.Width := 150;
    gridData.AddObject(Col);
  end;

  mtData.First;
  var Row := 0;
  while not mtData.Eof do
  begin
    for var C := 0 to mtData.FieldCount - 1 do
      gridData.Cells[C, Row] := mtData.Fields[C].AsString;
    Inc(Row);
    mtData.Next;
  end;
end;

procedure TfrmImportExport.Log(const Msg: string);
begin
  memoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' ' + Msg);
end;

end.
```

---

## 7. Complete Example: Master-Detail Pattern

Customers in the top grid. Orders for the selected customer in the bottom grid. The orders grid updates automatically when you select a different customer.

```pascal
unit MasterDetail;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls,
  FMX.Grid, FMX.Grid.Style, FMX.ScrollBox, FMX.Layouts,
  FireDAC.Comp.Client,
  Tina4Core, Tina4REST, Tina4RESTRequest, Tina4JSONAdapter;

type
  TfrmMasterDetail = class(TForm)
    restAPI: TTina4REST;
    reqCustomers: TTina4RESTRequest;
    adapterOrders: TTina4JSONAdapter;
    mtCustomers: TFDMemTable;
    mtOrders: TFDMemTable;
    gridCustomers: TStringGrid;
    gridOrders: TStringGrid;
    btnLoad: TButton;
    lblCustomerCount: TLabel;
    lblOrderCount: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure gridCustomersSelectCell(Sender: TObject; const ACol, ARow: Integer;
      var CanSelect: Boolean);
  private
    FOrdersData: TJSONObject;
    procedure RefreshCustomerGrid;
    procedure LoadOrdersForCustomer(CustomerId: string);
    procedure RefreshOrderGrid;
  end;

var
  frmMasterDetail: TfrmMasterDetail;

implementation

{$R *.fmx}

procedure TfrmMasterDetail.FormCreate(Sender: TObject);
begin
  restAPI.BaseUrl := 'https://api.example.com/v1';
  restAPI.SetBearer('your-token-here');

  reqCustomers.Tina4REST := restAPI;
  reqCustomers.EndPoint := '/customers';
  reqCustomers.RequestType := TTina4RequestType.Get;
  reqCustomers.DataKey := 'records';
  reqCustomers.MemTable := mtCustomers;
  reqCustomers.SyncMode := TTina4RestSyncMode.Clear;

  FOrdersData := nil;
end;

procedure TfrmMasterDetail.btnLoadClick(Sender: TObject);
begin
  reqCustomers.ExecuteRESTCall;
  RefreshCustomerGrid;
  lblCustomerCount.Text := Format('%d customers', [mtCustomers.RecordCount]);

  // Auto-select first customer
  if mtCustomers.RecordCount > 0 then
  begin
    mtCustomers.First;
    LoadOrdersForCustomer(mtCustomers.FieldByName('id').AsString);
  end;
end;

procedure TfrmMasterDetail.gridCustomersSelectCell(Sender: TObject;
  const ACol, ARow: Integer; var CanSelect: Boolean);
begin
  if ARow < mtCustomers.RecordCount then
  begin
    mtCustomers.RecNo := ARow + 1;
    LoadOrdersForCustomer(mtCustomers.FieldByName('id').AsString);
  end;
end;

procedure TfrmMasterDetail.LoadOrdersForCustomer(CustomerId: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := restAPI.Get(StatusCode,
    '/customers/' + CustomerId + '/orders');
  try
    if StatusCode = 200 then
    begin
      PopulateMemTableFromJSON(mtOrders, 'records', Response.ToString);
      RefreshOrderGrid;
      lblOrderCount.Text := Format('%d orders', [mtOrders.RecordCount]);
    end
    else
    begin
      mtOrders.EmptyDataSet;
      RefreshOrderGrid;
      lblOrderCount.Text := '0 orders';
    end;
  finally
    Response.Free;
  end;
end;

procedure TfrmMasterDetail.RefreshCustomerGrid;
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

procedure TfrmMasterDetail.RefreshOrderGrid;
begin
  gridOrders.RowCount := mtOrders.RecordCount;
  gridOrders.ClearColumns;

  for var I := 0 to mtOrders.FieldCount - 1 do
  begin
    var Col := TStringColumn.Create(gridOrders);
    Col.Header := mtOrders.Fields[I].FieldName;
    Col.Width := 120;
    gridOrders.AddObject(Col);
  end;

  mtOrders.First;
  var Row := 0;
  while not mtOrders.Eof do
  begin
    for var C := 0 to mtOrders.FieldCount - 1 do
      gridOrders.Cells[C, Row] := mtOrders.Fields[C].AsString;
    Inc(Row);
    mtOrders.Next;
  end;
end;

end.
```

---

## 8. Exercise: JSON Viewer

Build a universal JSON viewer that can load any JSON file, auto-create MemTable fields, display the data in a grid, and allow editing.

### Requirements

1. An "Open File" button that loads a `.json` file from disk
2. A `TEdit` for specifying the data key (default: `records`)
3. Auto-detect field definitions from the JSON structure
4. Display the data in a `TStringGrid`
5. Allow the user to edit cells in the grid
6. A "Save" button that writes the modified data back to the JSON file

### Solution

```pascal
unit JSONViewer;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Grid, FMX.Grid.Style, FMX.ScrollBox, FMX.Dialogs, FMX.Layouts,
  FireDAC.Comp.Client,
  Tina4Core;

type
  TfrmJSONViewer = class(TForm)
    btnOpen: TButton;
    btnSave: TButton;
    edtDataKey: TEdit;
    gridData: TStringGrid;
    mtData: TFDMemTable;
    lblStatus: TLabel;
    lblDataKey: TLabel;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    procedure btnOpenClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FCurrentFile: string;
    FOriginalJSON: string;
    procedure LoadJSON(const FileName: string);
    procedure RefreshGrid;
  end;

var
  frmJSONViewer: TfrmJSONViewer;

implementation

{$R *.fmx}

procedure TfrmJSONViewer.FormCreate(Sender: TObject);
begin
  edtDataKey.Text := 'records';
  OpenDialog1.Filter := 'JSON files (*.json)|*.json|All files (*.*)|*.*';
  SaveDialog1.Filter := 'JSON files (*.json)|*.json';
end;

procedure TfrmJSONViewer.btnOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    LoadJSON(OpenDialog1.FileName);
end;

procedure TfrmJSONViewer.LoadJSON(const FileName: string);
var
  JSONStr: string;
  DataKey: string;
begin
  FCurrentFile := FileName;
  JSONStr := TFile.ReadAllText(FileName);
  FOriginalJSON := JSONStr;
  DataKey := edtDataKey.Text;

  // Clear existing data
  mtData.Close;
  mtData.FieldDefs.Clear;

  // Try to parse and detect structure
  var JSONVal := StrToJSONValue(JSONStr);
  try
    if JSONVal is TJSONArray then
    begin
      // Root is an array -- wrap it for PopulateMemTableFromJSON
      var Wrapped := Format('{"%s": %s}', [DataKey, JSONStr]);
      PopulateMemTableFromJSON(mtData, DataKey, Wrapped);
    end
    else if JSONVal is TJSONObject then
    begin
      PopulateMemTableFromJSON(mtData, DataKey, JSONStr);
    end
    else
    begin
      lblStatus.Text := 'JSON is neither an object nor an array';
      Exit;
    end;
  finally
    JSONVal.Free;
  end;

  RefreshGrid;
  lblStatus.Text := Format('Loaded %d records from %s',
    [mtData.RecordCount, ExtractFileName(FileName)]);
end;

procedure TfrmJSONViewer.RefreshGrid;
begin
  gridData.RowCount := mtData.RecordCount;
  gridData.ClearColumns;

  for var I := 0 to mtData.FieldCount - 1 do
  begin
    var Col := TStringColumn.Create(gridData);
    Col.Header := mtData.Fields[I].FieldName;
    Col.Width := 150;
    gridData.AddObject(Col);
  end;

  mtData.First;
  var Row := 0;
  while not mtData.Eof do
  begin
    for var C := 0 to mtData.FieldCount - 1 do
      gridData.Cells[C, Row] := mtData.Fields[C].AsString;
    Inc(Row);
    mtData.Next;
  end;
end;

procedure TfrmJSONViewer.btnSaveClick(Sender: TObject);
var
  JSON: TJSONObject;
  FileName: string;
begin
  // Read grid edits back into MemTable
  mtData.First;
  var Row := 0;
  while not mtData.Eof do
  begin
    mtData.Edit;
    for var C := 0 to mtData.FieldCount - 1 do
      mtData.Fields[C].AsString := gridData.Cells[C, Row];
    mtData.Post;
    Inc(Row);
    mtData.Next;
  end;

  // Serialize to JSON
  JSON := GetJSONFromTable(mtData, edtDataKey.Text);
  try
    if FCurrentFile <> '' then
      FileName := FCurrentFile
    else if SaveDialog1.Execute then
      FileName := SaveDialog1.FileName
    else
      Exit;

    TFile.WriteAllText(FileName, JSON.Format);
    lblStatus.Text := 'Saved to ' + ExtractFileName(FileName);
  finally
    JSON.Free;
  end;
end;

end.
```

---

## 9. Common Gotchas

### TJSONObject Memory Management

**Symptom**: Memory leaks reported by `ReportMemoryLeaksOnShutdown`.

**Fix**: Every function that returns a `TJSONObject` -- `StrToJSONObject`, `BytesToJSONObject`, `GetJSONFromDB`, `GetJSONFromTable`, `Get`, `Post`, etc. -- creates an object on the heap. You must free it:

```pascal
// Pattern: always use try..finally
var Obj := StrToJSONObject(SomeString);
try
  // work with Obj
finally
  Obj.Free;
end;
```

Do not free child objects extracted with `GetValue<TJSONObject>` or `GetValue<TJSONArray>` -- they are owned by the parent. Freeing the parent frees all children.

### Nested JSON Becoming ftMemo Fields

**Symptom**: A field contains `{"city": "Cape Town", "zip": "8001"}` instead of the expected flat value.

**Explanation**: When `GetFieldDefsFromJSONObject` encounters a nested JSON object or array, it creates an `ftMemo` field containing the serialized JSON string. This is by design -- there is no automatic flattening.

**Fix**: If you need flat fields, pre-process the JSON to flatten it before populating the MemTable. Or use a second `TTina4JSONAdapter` to extract nested data into a separate MemTable.

### Sync Mode Without IndexFieldNames

**Symptom**: Duplicate rows appear in the MemTable after sync.

**Fix**: When using `TTina4RestSyncMode.Sync`, you must set `IndexFieldNames`. Without it, the sync has no way to match incoming records to existing rows, so it appends everything:

```pascal
// WRONG -- no index, sync inserts duplicates
PopulateMemTableFromJSON(mtData, 'records', JSONStr,
  '', TTina4RestSyncMode.Sync);

// CORRECT -- match by id field
PopulateMemTableFromJSON(mtData, 'records', JSONStr,
  'id', TTina4RestSyncMode.Sync);
```

### DataKey Does Not Exist

**Symptom**: MemTable is empty after `PopulateMemTableFromJSON`, even though the JSON contains data.

**Fix**: Verify the data key matches the actual JSON structure. Common mismatches:

```pascal
// API returns {"data": [...]}
PopulateMemTableFromJSON(mtData, 'records', JSONStr);  // WRONG: no "records" key
PopulateMemTableFromJSON(mtData, 'data', JSONStr);     // CORRECT

// API returns a bare array [...]
PopulateMemTableFromJSON(mtData, 'records', JSONStr);   // WRONG: no wrapper object
// Wrap it first:
var Wrapped := '{"records": ' + JSONStr + '}';
PopulateMemTableFromJSON(mtData, 'records', Wrapped);   // CORRECT
```

### Date Fields Not Parsing

**Symptom**: Date values appear as raw strings like `2024-06-15T14:30:00.000Z` instead of `TDateTime` values.

**Explanation**: `PopulateMemTableFromJSON` creates all fields as `ftString` by default (auto-detected from JSON, which has no date type). Dates are stored as strings.

**Fix**: Use `IsDate` and `JSONDateToDateTime` for explicit conversion:

```pascal
if IsDate(mtData.FieldByName('createdAt').AsString) then
begin
  var DT := JSONDateToDateTime(mtData.FieldByName('createdAt').AsString);
  // DT is now a TDateTime you can format or compare
end;
```

---

## Summary

| What | How |
|---|---|
| Parse JSON string | `StrToJSONObject(str)` / `StrToJSONArray(str)` |
| Parse HTTP response | `BytesToJSONObject(bytes)` |
| JSON adapter | `TTina4JSONAdapter` -- set `MemTable`, `DataKey`, `JSONData`, `Execute` |
| Adapter from REST | Set `MasterSource` to a `TTina4RESTRequest` |
| Sync mode | `SyncMode := Sync` + `IndexFieldNames := 'id'` |
| DB to JSON | `GetJSONFromDB(Connection, SQL)` -- auto camelCase, ISO dates |
| Table to JSON | `GetJSONFromTable(MemTable)` |
| JSON to MemTable | `PopulateMemTableFromJSON(MemTable, DataKey, JSON)` |
| JSON to DB | `PopulateTableFromJSON(Connection, TableName, JSON, DataKey, PK)` |
| Field defs from JSON | `GetFieldDefsFromJSONObject(JSONObj, MemTable, SnakeCase)` |
| camelCase convert | `CamelCase('snake_name')` |
| snake_case convert | `SnakeCase('camelName')` |
| Date check | `IsDate(Value)` |
| Date to ISO | `GetJSONDate(DateTime)` |
| ISO to Date | `JSONDateToDateTime(ISOString)` |
