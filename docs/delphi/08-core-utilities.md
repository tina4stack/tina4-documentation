# Chapter 8: Core Utilities

## The Swiss Army Knife You Already Have

Every Delphi project accumulates a `Utils.pas` file. String conversion functions. Date formatting helpers. JSON parsing wrappers. HTTP request boilerplate. File encoding routines. You write them once, copy them across projects, fix bugs in three places, forget to fix the fourth.

`Tina4Core.pas` is that utils file, already written and tested. Add it to your `uses` clause and you get string helpers, GUID generation, date utilities, Base64 encoding, JSON parsing, database-to-JSON conversion, JSON-to-MemTable population, HTTP requests, multipart file uploads, and shell command execution. No components to drop on a form. No configuration. Just functions.

```pascal
uses
  Tina4Core;
```

That single line gives you everything in this chapter.

---

## 1. String Helpers

### CamelCase

Converts `snake_case` to `camelCase`. This is the function that makes database field names feel natural in JSON:

```pascal
CamelCase('first_name');      // 'firstName'
CamelCase('id');              // 'id'
CamelCase('user_email');      // 'userEmail'
CamelCase('created_at');      // 'createdAt'
CamelCase('order_line_item'); // 'orderLineItem'
```

`GetJSONFromDB` uses this internally. When your database table has `first_name` and `last_name` columns, the JSON output automatically uses `firstName` and `lastName`.

### SnakeCase

The reverse -- converts `camelCase` back to `snake_case`. Used when mapping JSON keys back to database columns:

```pascal
SnakeCase('firstName');      // 'first_name'
SnakeCase('userEmail');      // 'user_email'
SnakeCase('createdAt');      // 'created_at'
SnakeCase('orderLineItem');  // 'order_line_item'
```

### When You Need Both

```pascal
// API sends camelCase JSON, database uses snake_case columns
var JSONKey := 'orderTotal';
var DBColumn := SnakeCase(JSONKey);  // 'order_total'

// Query returns snake_case, API expects camelCase
var DBField := 'shipping_address';
var APIField := CamelCase(DBField);  // 'shippingAddress'
```

---

## 2. GUID Generation

### GetGUID

Returns a new GUID string without braces:

```pascal
var ID := GetGUID;
// e.g. 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890'

// Use as a primary key
FDQuery1.SQL.Text := 'INSERT INTO documents (id, title) VALUES (:id, :title)';
FDQuery1.ParamByName('id').AsString := GetGUID;
FDQuery1.ParamByName('title').AsString := 'New Document';
FDQuery1.ExecSQL;
```

Each call produces a unique value. Use it for primary keys, session tokens, file names, or any situation that needs a globally unique identifier.

```pascal
// Generate unique filenames
var FileName := GetGUID + '.pdf';

// Create a batch ID for grouped operations
var BatchID := GetGUID;
for var I := 0 to Items.Count - 1 do
begin
  FDQuery1.SQL.Text := 'INSERT INTO batch_items (batch_id, item_id) VALUES (:batch, :item)';
  FDQuery1.ParamByName('batch').AsString := BatchID;
  FDQuery1.ParamByName('item').AsString := Items[I];
  FDQuery1.ExecSQL;
end;
```

---

## 3. Date Utilities

### IsDate

Checks whether a Variant value represents a valid date. Supports multiple formats:

```pascal
IsDate('2024-01-15');                  // True - ISO date
IsDate('2024-01-15T10:30:00');         // True - ISO datetime
IsDate('2024-01-15T10:30:00.000Z');    // True - ISO with milliseconds
IsDate('01/15/2024');                  // True - US date format
IsDate('2024-01-15 14:30:00');         // True - datetime with space
IsDate('42');                          // False - number
IsDate('hello');                       // False - string
IsDate('');                            // False - empty
```

Use it to validate user input or incoming API data:

```pascal
procedure TForm1.ValidateDateField(const AValue: string);
begin
  if not IsDate(AValue) then
    raise Exception.Create('Invalid date format: ' + AValue);
end;
```

### GetJSONDate

Converts a `TDateTime` to an ISO 8601 string -- the standard format for JSON APIs:

```pascal
GetJSONDate(Now);
// '2026-03-26T14:30:00.000Z'

GetJSONDate(EncodeDate(2026, 1, 1));
// '2026-01-01T00:00:00.000Z'
```

Use it when building JSON payloads:

```pascal
var Order := TJSONObject.Create;
try
  Order.AddPair('id', GetGUID);
  Order.AddPair('createdAt', GetJSONDate(Now));
  Order.AddPair('total', TJSONNumber.Create(99.99));
  // Send to API...
finally
  Order.Free;
end;
```

### JSONDateToDateTime

Converts an ISO 8601 date string back to a `TDateTime`:

```pascal
var DT := JSONDateToDateTime('2026-03-26T14:30:00.000Z');
// DT is now a TDateTime you can use with FormatDateTime, DateUtils, etc.

ShowMessage(FormatDateTime('dd/mm/yyyy hh:nn', DT));
// '26/03/2026 14:30'
```

The round-trip works cleanly:

```pascal
var Original := Now;
var JSON := GetJSONDate(Original);
var Restored := JSONDateToDateTime(JSON);
// Original and Restored represent the same point in time
```

---

## 4. Encoding

### DecodeBase64

Decodes a Base64-encoded string back to plain UTF-8:

```pascal
DecodeBase64('SGVsbG8gV29ybGQ=');
// 'Hello World'

// Decode an API token
var Token := DecodeBase64(EncodedToken);
```

### FileToBase64

Reads an entire file and returns its content as a Base64 string. Works with any file type:

```pascal
var B64 := FileToBase64('C:\photos\avatar.jpg');
// B64 now contains the Base64-encoded JPEG data

// Embed in JSON for API upload
var Payload := TJSONObject.Create;
try
  Payload.AddPair('filename', 'avatar.jpg');
  Payload.AddPair('data', FileToBase64('C:\photos\avatar.jpg'));
  Payload.AddPair('mimeType', 'image/jpeg');
  // POST to API...
finally
  Payload.Free;
end;
```

### BitmapToBase64EncodedString

Encodes an FMX `TBitmap` to a Base64 string with optional resizing. The default resize is 256x256 pixels -- ideal for thumbnails and avatars:

```pascal
// Default: resize to 256x256
var Encoded := BitmapToBase64EncodedString(Image1.Bitmap);

// No resize -- keep original dimensions
var Encoded := BitmapToBase64EncodedString(Image1.Bitmap, False);

// Custom resize
var Encoded := BitmapToBase64EncodedString(Image1.Bitmap, True, 128, 128);
var Encoded := BitmapToBase64EncodedString(Image1.Bitmap, True, 512, 512);
```

Practical use -- capture and upload a profile photo:

```pascal
procedure TForm1.ButtonUploadClick(Sender: TObject);
var
  StatusCode: Integer;
  Encoded: string;
begin
  Encoded := BitmapToBase64EncodedString(ImageAvatar.Bitmap, True, 200, 200);

  var Body := TJSONObject.Create;
  try
    Body.AddPair('userId', '1001');
    Body.AddPair('avatar', Encoded);

    SendHttpRequest(StatusCode,
      'https://api.example.com', '/users/1001/avatar', '',
      Body.ToString, 'application/json', 'utf-8', '', '', nil, 'Tina4Delphi',
      TTina4RequestType.Patch);

    if StatusCode = 200 then
      ShowMessage('Avatar uploaded')
    else
      ShowMessage('Upload failed: ' + StatusCode.ToString);
  finally
    Body.Free;
  end;
end;
```

### BitmapToSkiaWepPEncodedString

Encodes an FMX `TBitmap` to a WebP Base64 string using Skia. Requires the `SKIA` compiler define. WebP produces smaller files than JPEG at the same quality:

```pascal
{$IFDEF SKIA}
var WebPData := BitmapToSkiaWepPEncodedString(Image1.Bitmap, 90);
// quality parameter: 0-100 (higher = better quality, larger size)
{$ENDIF}
```

---

## 5. JSON Parsing

### StrToJSONObject

Parses a JSON string into a `TJSONObject`. Returns `nil` if parsing fails -- always check:

```pascal
var Obj := StrToJSONObject('{"name": "Andre", "age": 30}');
try
  if Assigned(Obj) then
  begin
    var Name := Obj.GetValue<String>('name');   // 'Andre'
    var Age := Obj.GetValue<Integer>('age');     // 30
    ShowMessage(Name + ' is ' + Age.ToString);
  end
  else
    ShowMessage('Invalid JSON');
finally
  Obj.Free;
end;
```

### StrToJSONArray

Parses a JSON array string:

```pascal
var Arr := StrToJSONArray('[1, 2, 3, 4, 5]');
try
  if Assigned(Arr) then
    for var I := 0 to Arr.Count - 1 do
      ShowMessage(Arr.Items[I].Value);
finally
  Arr.Free;
end;
```

### StrToJSONValue

Parses any JSON value -- object, array, string, number, boolean, or null. Use when you do not know the structure in advance:

```pascal
var Val := StrToJSONValue(APIResponse);
if Val is TJSONObject then
  // Handle object
else if Val is TJSONArray then
  // Handle array
else if Val is TJSONString then
  // Handle string
```

### BytesToJSONObject

Parses a `TBytes` buffer into a `TJSONObject`. This is the bridge between raw HTTP responses and structured JSON:

```pascal
var
  StatusCode: Integer;
  Response: TBytes;
begin
  Response := SendHttpRequest(StatusCode, 'https://api.example.com', '/users');

  var JSON := BytesToJSONObject(Response);
  try
    if Assigned(JSON) then
    begin
      // Process the response
      var Records := JSON.GetValue<TJSONArray>('records');
      ShowMessage('Found ' + Records.Count.ToString + ' users');
    end;
  finally
    JSON.Free;
  end;
end;
```

### GetJSONFieldName

Strips surrounding quotes from a JSON field name string:

```pascal
GetJSONFieldName('"firstName"');  // 'firstName'
GetJSONFieldName('"id"');         // 'id'
GetJSONFieldName('name');         // 'name' (no change)
```

---

## 6. Database to JSON

### GetJSONFromDB

Executes a SQL query and returns the results as a `TJSONObject`. Three automatic conversions happen:

1. **Field names** are converted from `snake_case` to `camelCase`
2. **DateTime fields** are formatted as ISO 8601
3. **Blob fields** are encoded as Base64

```pascal
// Simple query
var Result := GetJSONFromDB(FDConnection1, 'SELECT * FROM users');
// {"records": [{"id": "1", "firstName": "Andre", "email": "andre@test.com"}, ...]}

// Custom dataset key
var Result := GetJSONFromDB(FDConnection1, 'SELECT * FROM products', nil, 'products');
// {"products": [{"id": "1", "productName": "Widget"}, ...]}
```

### With Parameters

```pascal
var Params := TFDParams.Create;
try
  Params.Add('status', 'active');
  Params.Add('minAge', 18);

  var Result := GetJSONFromDB(FDConnection1,
    'SELECT * FROM users WHERE status = :status AND age >= :minAge',
    Params);
  try
    Memo1.Lines.Text := Result.Format(2);
  finally
    Result.Free;
  end;
finally
  Params.Free;
end;
```

### Serving JSON from a Database

Combine `GetJSONFromDB` with an HTTP response to build an instant API:

```pascal
procedure TForm1.HandleGetUsers;
var
  Result: TJSONObject;
begin
  Result := GetJSONFromDB(FDConnection1,
    'SELECT id, first_name, last_name, email, created_at ' +
    'FROM users WHERE active = 1 ORDER BY last_name');
  try
    // Result is ready to send as an API response:
    // {
    //   "records": [
    //     {"id": "1", "firstName": "Andre", "lastName": "Van Zuydam",
    //      "email": "andre@test.com", "createdAt": "2026-03-15T10:30:00.000Z"},
    //     ...
    //   ]
    // }
    Memo1.Lines.Text := Result.Format(2);
  finally
    Result.Free;
  end;
end;
```

### GetJSONFromTable

Converts rows in a `TFDMemTable` or `TFDTable` to JSON:

```pascal
// Basic conversion
var JSON := GetJSONFromTable(FDMemTable1);
// {"records": [{"id": "1", "name": "Item 1"}, ...]}

// Ignore specific fields (e.g., sensitive data)
var JSON := GetJSONFromTable(FDMemTable1, 'records', 'password,secret_key');

// Ignore blank values (smaller JSON)
var JSON := GetJSONFromTable(FDMemTable1, 'records', '', True);
```

---

## 7. JSON to MemTable

### GetFieldDefsFromJSONObject

Creates field definitions on a `TFDMemTable` from a `TJSONObject` structure. Call this before populating the table if you need auto-created fields:

```pascal
var JSONObj := StrToJSONObject(
  '{"firstName": "Andre", "age": 30, "address": {"city": "Cape Town"}}');
try
  GetFieldDefsFromJSONObject(JSONObj, FDMemTable1, True);
  // Creates fields:
  //   first_name (ftString)  -- camelCase converted to snake_case
  //   age (ftString)
  //   address (ftMemo)       -- nested objects become memo fields
finally
  JSONObj.Free;
end;
```

The third parameter controls snake_case conversion:

```pascal
// With snake_case conversion (True) -- good for database-style field names
GetFieldDefsFromJSONObject(JSONObj, MemTable, True);
// firstName -> first_name

// Without conversion (False) -- keeps camelCase
GetFieldDefsFromJSONObject(JSONObj, MemTable, False);
// firstName -> firstName
```

### PopulateMemTableFromJSON

Populates a `TFDMemTable` from a JSON string. Two sync modes control how existing data is handled:

**Clear mode** (default) -- empties the table, then appends all records:

```pascal
PopulateMemTableFromJSON(FDMemTable1, 'records',
  '{"records": [{"id": "1", "name": "Alice"}, {"id": "2", "name": "Bob"}]}');
// FDMemTable1 now has exactly 2 records
```

**Sync mode** -- matches existing records by a key field, updates them, and inserts new ones:

```pascal
// First load
PopulateMemTableFromJSON(FDMemTable1, 'records',
  '{"records": [{"id": "1", "name": "Alice"}, {"id": "2", "name": "Bob"}]}');

// Later: sync with updated data
PopulateMemTableFromJSON(FDMemTable1, 'records',
  '{"records": [{"id": "1", "name": "Alice Updated"}, {"id": "3", "name": "Charlie"}]}',
  'id', TTina4RestSyncMode.Sync);
// FDMemTable1 now has 3 records:
//   id=1: "Alice Updated" (updated)
//   id=2: "Bob" (unchanged)
//   id=3: "Charlie" (inserted)
```

### PopulateTableFromJSON

Inserts or updates rows directly into a **database table** (not a MemTable) from JSON. Uses a primary key for upsert logic:

```pascal
var Result := PopulateTableFromJSON(
  FDConnection1,
  'users',                    // table name
  '{"response": [{"name": "Alice"}, {"name": "Bob"}]}',
  'response',                 // JSON key containing the array
  'id');                      // primary key field for upsert

// Rows are inserted or updated directly in the 'users' table
```

This is the fastest way to sync remote API data into a local database.

---

## 8. HTTP Requests

### SendHttpRequest

Low-level HTTP function that returns raw `TBytes`. Supports GET, POST, PATCH, PUT, and DELETE:

```pascal
var
  StatusCode: Integer;
  Response: TBytes;
begin
  // Simple GET
  Response := SendHttpRequest(StatusCode,
    'https://api.example.com', '/users');

  if StatusCode = 200 then
  begin
    var JSON := BytesToJSONObject(Response);
    try
      // Process response...
    finally
      JSON.Free;
    end;
  end;
end;
```

### POST with JSON Body

```pascal
var
  StatusCode: Integer;
  Body: string;
begin
  Body := '{"name": "Andre", "email": "andre@test.com"}';

  SendHttpRequest(StatusCode,
    'https://api.example.com',   // base URL
    '/users',                     // endpoint
    '',                           // query params
    Body,                         // request body
    'application/json',           // content type
    'utf-8',                      // charset
    '', '',                       // username, password (for Basic Auth)
    nil,                          // custom headers
    'Tina4Delphi',               // user agent
    TTina4RequestType.Post);      // request type

  case StatusCode of
    201: ShowMessage('User created');
    400: ShowMessage('Bad request');
    401: ShowMessage('Unauthorized');
    500: ShowMessage('Server error');
  end;
end;
```

### With Basic Auth

```pascal
Response := SendHttpRequest(StatusCode,
  'https://api.example.com', '/secure/data',
  '', '',
  'application/json', 'utf-8',
  'myuser', 'mypassword');
```

### PATCH and DELETE

```pascal
// Update a user
SendHttpRequest(StatusCode,
  'https://api.example.com', '/users/1001', '',
  '{"name": "Andre Updated"}',
  'application/json', 'utf-8', '', '', nil, 'Tina4Delphi',
  TTina4RequestType.Patch);

// Delete a user
SendHttpRequest(StatusCode,
  'https://api.example.com', '/users/1001', '',
  '', 'application/json', 'utf-8', '', '', nil, 'Tina4Delphi',
  TTina4RequestType.Delete);
```

### SendMultipartFormData

Sends a multipart/form-data POST for file uploads with optional form fields:

```pascal
var
  StatusCode: Integer;
  Response: TBytes;
begin
  Response := SendMultipartFormData(
    StatusCode,
    'https://api.example.com',      // base URL
    'upload/avatar',                 // endpoint
    ['userId', '1001',              // form fields (key-value pairs)
     'caption', 'Profile photo'],
    ['avatar', 'C:\photos\me.jpg'], // files (field name, file path)
    '',                              // query params
    'myuser', 'mypassword');         // auth

  if StatusCode = 200 then
    ShowMessage('Upload successful');
end;
```

Multiple files:

```pascal
Response := SendMultipartFormData(
  StatusCode,
  'https://api.example.com', 'upload/documents',
  ['projectId', '42'],
  ['doc1', 'C:\docs\spec.pdf',
   'doc2', 'C:\docs\design.pdf',
   'doc3', 'C:\docs\timeline.xlsx'],
  '', '', '');
```

---

## 9. Shell Commands

### ExecuteShellCommand

Runs a shell command and captures stdout. Works on Windows, Linux, and macOS:

```pascal
var
  Output: String;
  ExitCode: Integer;
begin
  // Windows
  ExitCode := ExecuteShellCommand('dir C:\temp', Output);
  ShowMessage(Output);

  // macOS / Linux
  ExitCode := ExecuteShellCommand('ls -la /tmp', Output);
  ShowMessage(Output);
end;
```

Check the exit code:

```pascal
var
  Output: String;
  ExitCode: Integer;
begin
  ExitCode := ExecuteShellCommand('ping -n 4 google.com', Output);

  if ExitCode = 0 then
    ShowMessage('Ping successful:' + sLineBreak + Output)
  else
    ShowMessage('Ping failed with exit code: ' + ExitCode.ToString);
end;
```

### Cross-Platform Commands

```pascal
procedure TForm1.RunCommand(const ACommand: string);
var
  Output: String;
  ExitCode: Integer;
begin
  ExitCode := ExecuteShellCommand(ACommand, Output);
  MemoOutput.Lines.Text := Output;
  LabelExitCode.Text := 'Exit code: ' + ExitCode.ToString;
end;

// Usage:
{$IFDEF MSWINDOWS}
RunCommand('ipconfig /all');
{$ELSE}
RunCommand('ifconfig');
{$ENDIF}
```

---

## 10. Complete Example: File Upload Utility

Build a utility that selects an image, resizes it, encodes to Base64, uploads via multipart form data, and displays the server response.

```pascal
unit UploadForm;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Objects,
  FMX.Dialogs, FMX.Layouts, FMX.Memo,
  Tina4Core;

type
  TFormUpload = class(TForm)
    ImagePreview: TImage;
    ButtonSelect: TButton;
    ButtonUpload: TButton;
    LabelStatus: TLabel;
    MemoResponse: TMemo;
    OpenDialog1: TOpenDialog;
    LabelFileInfo: TLabel;
    procedure ButtonSelectClick(Sender: TObject);
    procedure ButtonUploadClick(Sender: TObject);
  private
    FSelectedFile: string;
    procedure UpdateFileInfo;
  end;

var
  FormUpload: TFormUpload;

implementation

{$R *.fmx}

procedure TFormUpload.ButtonSelectClick(Sender: TObject);
begin
  OpenDialog1.Filter := 'Image files|*.jpg;*.jpeg;*.png;*.bmp|All files|*.*';

  if OpenDialog1.Execute then
  begin
    FSelectedFile := OpenDialog1.FileName;
    ImagePreview.Bitmap.LoadFromFile(FSelectedFile);
    UpdateFileInfo;
    ButtonUpload.Enabled := True;
    LabelStatus.Text := 'Image selected. Ready to upload.';
  end;
end;

procedure TFormUpload.UpdateFileInfo;
var
  FileSize: Int64;
  Info: TSearchRec;
begin
  if FindFirst(FSelectedFile, faAnyFile, Info) = 0 then
  begin
    FileSize := Info.Size;
    FindClose(Info);

    LabelFileInfo.Text := Format('File: %s | Size: %s | Dimensions: %dx%d',
      [ExtractFileName(FSelectedFile),
       FormatFloat('#,##0', FileSize) + ' bytes',
       Round(ImagePreview.Bitmap.Width),
       Round(ImagePreview.Bitmap.Height)]);
  end;
end;

procedure TFormUpload.ButtonUploadClick(Sender: TObject);
var
  StatusCode: Integer;
  Response: TBytes;
  Encoded: string;
begin
  if FSelectedFile.IsEmpty then
  begin
    ShowMessage('Please select an image first');
    Exit;
  end;

  LabelStatus.Text := 'Resizing image...';
  Application.ProcessMessages;

  // Resize and encode to Base64
  Encoded := BitmapToBase64EncodedString(ImagePreview.Bitmap, True, 512, 512);

  LabelStatus.Text := Format('Encoded to Base64 (%d chars). Uploading...',
    [Length(Encoded)]);
  Application.ProcessMessages;

  // Method 1: Upload as multipart form data (file upload)
  Response := SendMultipartFormData(
    StatusCode,
    'https://api.example.com',
    'upload/image',
    ['userId', '1001',
     'description', 'Uploaded from Delphi'],
    ['image', FSelectedFile],
    '', '', '');

  if StatusCode in [200, 201] then
  begin
    LabelStatus.Text := 'Upload successful!';

    var JSON := BytesToJSONObject(Response);
    try
      if Assigned(JSON) then
        MemoResponse.Lines.Text := JSON.Format(2)
      else
        MemoResponse.Lines.Text := TEncoding.UTF8.GetString(Response);
    finally
      JSON.Free;
    end;
  end
  else
  begin
    LabelStatus.Text := 'Upload failed: HTTP ' + StatusCode.ToString;
    MemoResponse.Lines.Text := TEncoding.UTF8.GetString(Response);
  end;
end;

end.
```

---

## 11. Complete Example: Database Sync Tool

Fetch JSON from a remote API, compare with a local database, and sync changes using `PopulateTableFromJSON`.

```pascal
unit SyncForm;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Memo,
  FMX.Layouts, FMX.Dialogs,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async,
  FireDAC.Phys.SQLite, FireDAC.DApt,
  Tina4Core;

type
  TFormSync = class(TForm)
    FDConnection1: TFDConnection;
    FDMemTableLocal: TFDMemTable;
    FDMemTableRemote: TFDMemTable;
    ButtonSync: TButton;
    ButtonCompare: TButton;
    MemoLog: TMemo;
    LabelStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure ButtonCompareClick(Sender: TObject);
    procedure ButtonSyncClick(Sender: TObject);
  private
    procedure Log(const AMessage: string);
    procedure FetchRemoteData;
    procedure LoadLocalData;
    procedure CompareAndReport;
    procedure SyncToLocal;
  end;

var
  FormSync: TFormSync;

implementation

{$R *.fmx}

procedure TFormSync.FormCreate(Sender: TObject);
begin
  // Setup SQLite connection
  FDConnection1.Params.Clear;
  FDConnection1.Params.Add('DriverID=SQLite');
  FDConnection1.Params.Add('Database=C:\MyApp\data\local.db');
  FDConnection1.Connected := True;

  // Ensure the products table exists
  FDConnection1.ExecSQL(
    'CREATE TABLE IF NOT EXISTS products (' +
    '  id TEXT PRIMARY KEY,' +
    '  name TEXT,' +
    '  price REAL,' +
    '  stock INTEGER,' +
    '  updated_at TEXT' +
    ')');

  Log('Database connected. Ready to sync.');
end;

procedure TFormSync.Log(const AMessage: string);
begin
  MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AMessage);
end;

procedure TFormSync.FetchRemoteData;
var
  StatusCode: Integer;
  Response: TBytes;
  JSON: TJSONObject;
begin
  Log('Fetching remote data...');
  LabelStatus.Text := 'Fetching from API...';
  Application.ProcessMessages;

  Response := SendHttpRequest(StatusCode,
    'https://api.example.com', '/products', 'limit=1000');

  if StatusCode <> 200 then
  begin
    Log('API error: HTTP ' + StatusCode.ToString);
    Exit;
  end;

  var JSONStr := TEncoding.UTF8.GetString(Response);

  // Populate remote MemTable
  PopulateMemTableFromJSON(FDMemTableRemote, 'records', JSONStr);
  Log('Fetched ' + FDMemTableRemote.RecordCount.ToString + ' remote products');
end;

procedure TFormSync.LoadLocalData;
var
  Result: TJSONObject;
begin
  Log('Loading local data...');

  Result := GetJSONFromDB(FDConnection1, 'SELECT * FROM products');
  try
    if Assigned(Result) then
    begin
      PopulateMemTableFromJSON(FDMemTableLocal, 'records', Result.ToString);
      Log('Loaded ' + FDMemTableLocal.RecordCount.ToString + ' local products');
    end;
  finally
    Result.Free;
  end;
end;

procedure TFormSync.CompareAndReport;
var
  LocalCount, RemoteCount: Integer;
  NewCount, UpdatedCount: Integer;
begin
  LocalCount := FDMemTableLocal.RecordCount;
  RemoteCount := FDMemTableRemote.RecordCount;
  NewCount := 0;
  UpdatedCount := 0;

  // Check each remote record against local
  FDMemTableRemote.First;
  while not FDMemTableRemote.Eof do
  begin
    var RemoteID := FDMemTableRemote.FieldByName('id').AsString;

    if FDMemTableLocal.Locate('id', RemoteID) then
    begin
      // Check if updated
      var RemoteName := FDMemTableRemote.FieldByName('name').AsString;
      var LocalName := FDMemTableLocal.FieldByName('name').AsString;
      if RemoteName <> LocalName then
        Inc(UpdatedCount);
    end
    else
      Inc(NewCount);

    FDMemTableRemote.Next;
  end;

  Log('---');
  Log('Comparison Results:');
  Log('  Local records:  ' + LocalCount.ToString);
  Log('  Remote records: ' + RemoteCount.ToString);
  Log('  New records:    ' + NewCount.ToString);
  Log('  Changed records: ' + UpdatedCount.ToString);
  Log('---');
end;

procedure TFormSync.ButtonCompareClick(Sender: TObject);
begin
  FetchRemoteData;
  LoadLocalData;
  CompareAndReport;
  LabelStatus.Text := 'Comparison complete';
end;

procedure TFormSync.ButtonSyncClick(Sender: TObject);
begin
  FetchRemoteData;
  SyncToLocal;
  LoadLocalData;  // Reload to verify
  LabelStatus.Text := 'Sync complete';
end;

procedure TFormSync.SyncToLocal;
var
  StatusCode: Integer;
  Response: TBytes;
begin
  Log('Syncing remote data to local database...');
  LabelStatus.Text := 'Syncing...';
  Application.ProcessMessages;

  // Fetch fresh data
  Response := SendHttpRequest(StatusCode,
    'https://api.example.com', '/products', 'limit=1000');

  if StatusCode <> 200 then
  begin
    Log('Sync failed: HTTP ' + StatusCode.ToString);
    Exit;
  end;

  var JSONStr := TEncoding.UTF8.GetString(Response);

  // Upsert into the database table
  var Result := PopulateTableFromJSON(
    FDConnection1,
    'products',     // table name
    JSONStr,        // JSON data
    'records',      // JSON array key
    'id');          // primary key for upsert

  Log('Sync complete. Processed records.');
end;

end.
```

---

## 12. Exercise: CLI Wrapper

**Build a command-line wrapper** that executes shell commands from a Delphi form, captures and displays output, and supports common operations.

### Requirements

1. A text input for custom commands
2. Quick-action buttons for common operations: Ping, Traceroute, Directory listing, IP configuration
3. Output display with timestamps
4. Cross-platform command detection (Windows vs macOS/Linux)
5. Exit code display

### Solution

```pascal
unit CLIForm;

interface

uses
  System.SysUtils, System.Types, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Memo, FMX.Layouts,
  Tina4Core;

type
  TFormCLI = class(TForm)
    EditCommand: TEdit;
    ButtonRun: TButton;
    ButtonPing: TButton;
    ButtonTrace: TButton;
    ButtonDir: TButton;
    ButtonIPConfig: TButton;
    ButtonClear: TButton;
    MemoOutput: TMemo;
    LabelExitCode: TLabel;
    LabelPlatform: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure ButtonRunClick(Sender: TObject);
    procedure ButtonPingClick(Sender: TObject);
    procedure ButtonTraceClick(Sender: TObject);
    procedure ButtonDirClick(Sender: TObject);
    procedure ButtonIPConfigClick(Sender: TObject);
    procedure ButtonClearClick(Sender: TObject);
    procedure EditCommandKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
  private
    procedure RunCommand(const ACommand: string);
    function IsWindows: Boolean;
  end;

var
  FormCLI: TFormCLI;

implementation

{$R *.fmx}

function TFormCLI.IsWindows: Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure TFormCLI.FormCreate(Sender: TObject);
begin
  if IsWindows then
    LabelPlatform.Text := 'Platform: Windows'
  else
    LabelPlatform.Text := 'Platform: macOS / Linux';
end;

procedure TFormCLI.RunCommand(const ACommand: string);
var
  Output: String;
  ExitCode: Integer;
begin
  MemoOutput.Lines.Add('');
  MemoOutput.Lines.Add('=== ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ===');
  MemoOutput.Lines.Add('$ ' + ACommand);
  MemoOutput.Lines.Add('');

  LabelExitCode.Text := 'Running...';
  Application.ProcessMessages;

  ExitCode := ExecuteShellCommand(ACommand, Output);

  MemoOutput.Lines.Add(Output);
  MemoOutput.Lines.Add('');

  if ExitCode = 0 then
    LabelExitCode.Text := 'Exit code: 0 (success)'
  else
    LabelExitCode.Text := 'Exit code: ' + ExitCode.ToString + ' (error)';

  // Scroll to bottom
  MemoOutput.GoToTextEnd;
end;

procedure TFormCLI.ButtonRunClick(Sender: TObject);
begin
  if EditCommand.Text.Trim.IsEmpty then
  begin
    ShowMessage('Enter a command to run');
    Exit;
  end;

  RunCommand(EditCommand.Text.Trim);
end;

procedure TFormCLI.EditCommandKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
    ButtonRunClick(Sender);
end;

procedure TFormCLI.ButtonPingClick(Sender: TObject);
begin
  if IsWindows then
    RunCommand('ping -n 4 google.com')
  else
    RunCommand('ping -c 4 google.com');
end;

procedure TFormCLI.ButtonTraceClick(Sender: TObject);
begin
  if IsWindows then
    RunCommand('tracert google.com')
  else
    RunCommand('traceroute google.com');
end;

procedure TFormCLI.ButtonDirClick(Sender: TObject);
begin
  if IsWindows then
    RunCommand('dir')
  else
    RunCommand('ls -la');
end;

procedure TFormCLI.ButtonIPConfigClick(Sender: TObject);
begin
  if IsWindows then
    RunCommand('ipconfig')
  else
    RunCommand('ifconfig');
end;

procedure TFormCLI.ButtonClearClick(Sender: TObject);
begin
  MemoOutput.Lines.Clear;
  LabelExitCode.Text := '';
end;

end.
```

---

## Common Gotchas

**TJSONObject memory leaks.** Every `TJSONObject`, `TJSONArray`, or `TJSONValue` you create owns its children. When you call `Free` on the parent, all children are freed too. But if you create one and forget to free it, you leak memory. The pattern is always `try/finally`:

```pascal
var Obj := StrToJSONObject(SomeString);
if Assigned(Obj) then
try
  // Use Obj...
finally
  Obj.Free;
end;
```

Do NOT free children of a `TJSONObject` separately -- the parent owns them:

```pascal
// Wrong -- double free
var Obj := StrToJSONObject('{"items": [1,2,3]}');
var Arr := Obj.GetValue<TJSONArray>('items');
Arr.Free;   // CRASH! Obj owns Arr
Obj.Free;

// Right
var Obj := StrToJSONObject('{"items": [1,2,3]}');
try
  var Arr := Obj.GetValue<TJSONArray>('items');
  // Use Arr... don't free it
finally
  Obj.Free;  // Frees everything
end;
```

**TBytes vs String conversion.** HTTP responses come back as `TBytes`. To get a string:

```pascal
var Text := TEncoding.UTF8.GetString(Response);
```

To go the other way:

```pascal
var Bytes := TEncoding.UTF8.GetBytes(MyString);
```

Never assume ASCII. Always use `TEncoding.UTF8`.

**Cross-platform shell commands.** `ExecuteShellCommand` works differently on Windows and macOS/Linux. Windows uses `cmd.exe`, macOS/Linux uses `/bin/sh`. Always use conditional compilation for platform-specific commands:

```pascal
{$IFDEF MSWINDOWS}
ExitCode := ExecuteShellCommand('dir /b C:\temp', Output);
{$ELSE}
ExitCode := ExecuteShellCommand('ls /tmp', Output);
{$ENDIF}
```

**GetJSONFromDB field name conversion.** The automatic `snake_case` to `camelCase` conversion is helpful, but it means your JSON keys will not match your database column names. If you need exact column names in your JSON, use `GetJSONFromTable` which does not convert names by default.

**PopulateMemTableFromJSON field matching.** When using Sync mode, the `IndexFieldNames` must be set on the MemTable before calling `PopulateMemTableFromJSON`. If the field names do not match (camelCase vs snake_case), sync will insert duplicates instead of updating:

```pascal
// Set the index field BEFORE populating
FDMemTable1.IndexFieldNames := 'id';

// Now sync works correctly
PopulateMemTableFromJSON(FDMemTable1, 'records', JSONData,
  'id', TTina4RestSyncMode.Sync);
```

**SendHttpRequest timeout.** The default timeout is system-dependent. For slow APIs or large uploads, you may get a timeout before the request completes. Pass a timeout parameter when available, or use `TTina4RESTRequest` with async execution for long-running requests.
