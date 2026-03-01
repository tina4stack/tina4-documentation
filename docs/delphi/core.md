# Core Utilities

::: tip
`Tina4Core.pas` provides standalone utility functions for strings, dates, encoding, JSON, database operations, HTTP requests, and shell commands.
:::

## String Helpers {#strings}

### CamelCase {#camelcase}

Converts `snake_case` to `camelCase`. Used when converting database field names to JSON keys.

```pascal
CamelCase('first_name');    // 'firstName'
CamelCase('id');            // 'id'
CamelCase('user_email');    // 'userEmail'
```

### SnakeCase {#snakecase}

Converts `camelCase` to `snake_case`. Used when mapping JSON keys back to database columns.

```pascal
SnakeCase('firstName');   // 'first_name'
SnakeCase('userEmail');   // 'user_email'
```

## GUID {#guid}

### GetGUID {#getguid}

Returns a new GUID string without surrounding braces.

```pascal
var ID := GetGUID;  // e.g. 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890'
```

## Date Utilities {#dates}

### IsDate {#isdate}

Checks whether a Variant value represents a date. Supports ISO 8601, `YYYY-MM-DD HH:NN:SS`, `YYYY-MM-DD`, and `MM/DD/YYYY` formats.

```pascal
IsDate('2024-01-15');                  // True
IsDate('2024-01-15T10:30:00');         // True
IsDate('2024-01-15T10:30:00.000Z');    // True
IsDate('01/15/2024');                  // True
IsDate(42);                            // False
```

### GetJSONDate {#getjsondate}

Converts a `TDateTime` to an ISO 8601 string.

```pascal
GetJSONDate(Now);  // '2024-06-15T14:30:00.000Z'
```

### JSONDateToDateTime {#jsondatetodatetime}

Converts an ISO 8601 date string back to a `TDateTime`.

```pascal
var DT := JSONDateToDateTime('2024-06-15T14:30:00.000Z');
```

## Encoding {#encoding}

### DecodeBase64 {#decodebase64}

Decodes a Base64-encoded string to plain UTF-8.

```pascal
DecodeBase64('SGVsbG8gV29ybGQ=');  // 'Hello World'
```

### FileToBase64 {#filetobase64}

Reads a file and returns its content as Base64.

```pascal
var B64 := FileToBase64('C:\photos\avatar.jpg');
```

### BitmapToBase64EncodedString {#bitmaptobase64}

Encodes an FMX `TBitmap` to a Base64 string with optional resizing.

```pascal
var Encoded := BitmapToBase64EncodedString(MyBitmap);           // resize to 256x256
var Encoded := BitmapToBase64EncodedString(MyBitmap, False);    // no resize
var Encoded := BitmapToBase64EncodedString(MyBitmap, True, 128, 128);
```

### BitmapToSkiaWepPEncodedString {#bitmaptowebp}

Encodes an FMX `TBitmap` to a WebP Base64 string using Skia. Requires the `SKIA` define.

```pascal
var WebPData := BitmapToSkiaWepPEncodedString(MyBitmap, 90);  // quality 90
```

## JSON Parsing {#json}

### StrToJSONObject {#strtojsonobject}

Parses a JSON string into a `TJSONObject`. Returns `nil` on failure.

```pascal
var Obj := StrToJSONObject('{"name": "Andre", "age": 30}');
try
  if Assigned(Obj) then
    ShowMessage(Obj.GetValue<String>('name'));
finally
  Obj.Free;
end;
```

### StrToJSONArray {#strtojsonarray}

Parses a JSON string into a `TJSONArray`.

```pascal
var Arr := StrToJSONArray('[1, 2, 3]');
```

### StrToJSONValue {#strtojsonvalue}

Parses a JSON string into a `TJSONValue`. Useful when the input could be an object, array, or primitive.

### BytesToJSONObject {#bytestojsonobject}

Parses a `TBytes` buffer (e.g. an HTTP response body) into a `TJSONObject`.

```pascal
var Obj := BytesToJSONObject(ResponseBytes);
```

### GetJSONFieldName {#getjsonfieldname}

Strips surrounding quotes from a JSON field name string.

```pascal
GetJSONFieldName('"firstName"');  // 'firstName'
```

## Database to JSON {#db-to-json}

### GetJSONFromDB {#getjsonfromdb}

Executes a SQL query and returns results as a `TJSONObject`. Field names are automatically converted to camelCase. Blob fields are Base64-encoded. DateTime fields are formatted as ISO 8601.

```pascal
// Simple query
var Result := GetJSONFromDB(Connection, 'SELECT * FROM users');
// {"records": [{"id": "1", "firstName": "Andre", ...}, ...]}

// With custom dataset name
var Result := GetJSONFromDB(Connection, 'SELECT * FROM cats', nil, 'cats');
// {"cats": [{"id": "1", "name": "Whiskers"}, ...]}

// With parameters
var Params := TFDParams.Create;
try
  Params.Add('status', 'active');
  Result := GetJSONFromDB(Connection,
    'SELECT * FROM users WHERE status = :status', Params);
finally
  Params.Free;
end;
```

### GetJSONFromTable {#getjsonfromtable}

Converts all rows in a `TFDMemTable` or `TFDTable` to a JSON object. Supports ignoring specific fields and blank values.

```pascal
// Basic conversion
var JSON := GetJSONFromTable(MemTable);
// {"records": [{"id": "1", "name": "Item1"}, ...]}

// Ignore specific fields
var JSON := GetJSONFromTable(MemTable, 'records', 'password,secret_key');

// Ignore blank values
var JSON := GetJSONFromTable(MemTable, 'records', '', True);
```

## JSON to MemTable {#json-to-memtable}

### GetFieldDefsFromJSONObject {#getfielddefs}

Creates field definitions on a `TFDMemTable` from a `TJSONObject` structure. Nested objects/arrays become `ftMemo` fields. Optionally transforms field names to snake_case.

```pascal
var JSONObj := StrToJSONObject('{"firstName": "Andre", "address": {"city": "Cape Town"}}');
GetFieldDefsFromJSONObject(JSONObj, MemTable, True);
// Creates fields: first_name (ftString), address (ftMemo)
```

### PopulateMemTableFromJSON {#populatememtable}

Populates a `TFDMemTable` from JSON with two sync modes:

| Sync Mode | Behavior |
|---|---|
| `Clear` (default) | Empties table first, then appends all records |
| `Sync` | Matches by `IndexFieldNames`, updates existing or inserts new |

```pascal
// Clear mode — replaces all data
PopulateMemTableFromJSON(MemTable, 'records',
  '{"records": [{"id": "1", "name": "Alice"}]}');

// Sync mode — update existing, insert new
PopulateMemTableFromJSON(MemTable, 'records',
  '{"records": [{"id": "1", "name": "Alice Updated"}]}',
  'id', TTina4RestSyncMode.Sync);
```

### PopulateTableFromJSON {#populatetable}

Inserts or updates rows directly into a database table from JSON. Uses a primary key for upsert logic.

```pascal
var Result := PopulateTableFromJSON(
  FDConnection1, 'users',
  '{"response": [{"name": "Alice"}, {"name": "Bob"}]}',
  'response', 'id');
```

## HTTP Requests {#http}

### SendHttpRequest {#sendhttprequest}

Low-level HTTP request function returning raw `TBytes`. Supports GET, POST, PATCH, PUT, and DELETE with Basic Auth, custom headers, and timeouts.

```pascal
var
  StatusCode: Integer;
  Response: TBytes;
begin
  // Simple GET
  Response := SendHttpRequest(StatusCode, 'https://api.example.com', '/users');

  // POST with JSON body
  Response := SendHttpRequest(StatusCode,
    'https://api.example.com', '/users', '',
    '{"name": "Andre"}',
    'application/json', 'utf-8', '', '', nil, 'Tina4Delphi',
    TTina4RequestType.Post);

  // With Basic Auth
  Response := SendHttpRequest(StatusCode,
    'https://api.example.com', '/secure', '', '',
    'application/json', 'utf-8', 'myuser', 'mypassword');

  var JSON := BytesToJSONObject(Response);
end;
```

### SendMultipartFormData {#sendmultipart}

Sends a multipart/form-data POST request for file uploads with optional form fields.

```pascal
var
  StatusCode: Integer;
  Response: TBytes;
begin
  Response := SendMultipartFormData(
    StatusCode,
    'https://api.example.com',
    'upload/avatar',
    ['userId', '1001', 'caption', 'Profile photo'],
    ['avatar', 'C:\photos\me.jpg'],
    '', 'myuser', 'mypassword');
end;
```

## Shell Commands {#shell}

### ExecuteShellCommand {#executeshellcommand}

Runs a shell command and captures its stdout output. Works on Windows, Linux, and macOS.

```pascal
var
  Output: String;
  ExitCode: Integer;
begin
  ExitCode := ExecuteShellCommand('dir C:\temp', Output);
  ShowMessage(Output);
end;
```
