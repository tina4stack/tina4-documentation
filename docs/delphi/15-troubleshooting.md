# Chapter 14: Troubleshooting

## When Things Go Wrong

The app compiles. It launches. You click the button to fetch users. Nothing happens. No error message. No crash. Just silence. The UI sits there. You check the endpoint -- it is correct. You check the auth -- it is set. You add a `ShowMessage` after the REST call and discover the status code is 0. Zero. The request never completed. You look at the SSL DLLs and realize you put 32-bit DLLs in System32 and 64-bit DLLs in SysWOW64. Backwards.

Every problem in this chapter has been hit by a real developer. Every fix has been verified. The format is the same throughout: Problem, Cause, Fix. Find your symptom, read the cause, apply the fix.

---

## 1. SSL Errors

### "Could not load SSL library"

**Problem**: REST calls fail with the error "Could not load SSL library" or the HTTP client raises an `ENetHTTPClientException` mentioning SSL.

**Cause**: The OpenSSL DLLs are missing or have the wrong bitness. Delphi's HTTP client needs platform-matched DLLs:
- The IDE is 32-bit, so it needs 32-bit DLLs
- Your compiled 64-bit app needs 64-bit DLLs
- Windows has confusing folder names: `SysWOW64` is for 32-bit, `System32` is for 64-bit

**Fix**:

```
32-bit DLLs (libeay32.dll, ssleay32.dll)
  --> C:\Windows\SysWOW64\         (for the IDE, design-time testing)
  --> Your app's output directory   (if compiling as Win32)

64-bit DLLs (libcrypto-3-x64.dll, libssl-3-x64.dll)
  --> C:\Windows\System32\         (for compiled 64-bit apps)
  --> Your app's output directory   (alternative)
```

Verify you have the correct files:

```pascal
// Add this to FormCreate to diagnose SSL at startup
procedure TFormMain.CheckSSL;
begin
  {$IFDEF WIN64}
  if not FileExists('libcrypto-3-x64.dll') and
     not FileExists('C:\Windows\System32\libcrypto-3-x64.dll') then
    ShowMessage('WARNING: 64-bit SSL DLLs not found');
  {$ENDIF}
  {$IFDEF WIN32}
  if not FileExists('libeay32.dll') and
     not FileExists('C:\Windows\SysWOW64\libeay32.dll') then
    ShowMessage('WARNING: 32-bit SSL DLLs not found');
  {$ENDIF}
end;
```

### Certificate Verification Failures

**Problem**: HTTPS calls fail with "certificate verify failed" or "unable to get local issuer certificate."

**Cause**: The server's SSL certificate cannot be verified against a trusted CA bundle. Common with internal APIs, self-signed certificates, or corporate proxies.

**Fix for development** -- disable certificate validation (never do this in production):

```pascal
uses
  System.Net.HttpClient;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  { Development only -- accepts any certificate }
  REST.ValidateServerCertificate := False;
end;
```

**Fix for production** -- ensure the server has a valid certificate from a trusted CA (Let's Encrypt, DigiCert, etc.).

### Self-Signed Certificate Handling

**Problem**: You need to connect to an internal API that uses a self-signed certificate.

**Cause**: The HTTP client rejects certificates not signed by a trusted CA.

**Fix**: Accept the specific certificate by validating its thumbprint:

```pascal
procedure TFormMain.OnValidateServerCertificate(
  const Sender: TObject;
  const ARequest: TURLRequest;
  const Certificate: TCertificate;
  var Accepted: Boolean);
begin
  { Accept only your known self-signed certificate }
  if Certificate.Subject.Contains('CN=myapi.internal') then
    Accepted := True
  else
    Accepted := Certificate.IsValid;
end;
```

---

## 2. REST Issues

### 401 Unauthorized

**Problem**: Every REST call returns status 401.

**Cause 1**: Bearer token expired.

```pascal
// Check if token is set
if REST.GetBearer.IsEmpty then
  ShowMessage('No bearer token set -- user needs to log in');
```

**Cause 2**: Wrong authentication type. The API expects Basic Auth but you are sending Bearer, or vice versa.

```pascal
// Basic Auth
REST.Username := 'admin';
REST.Password := 'secret';

// Bearer Auth -- do NOT set Username/Password
REST.SetBearer('eyJhbGciOiJIUzI1NiJ9...');

// Both set? Bearer takes priority, but the server might reject
// the extra Authorization header. Clear one:
REST.Username := '';
REST.Password := '';
REST.SetBearer(Token);
```

**Cause 3**: Token format wrong. Some APIs want `Bearer <token>`, others want just the token. TTina4REST adds the `Bearer ` prefix automatically via `SetBearer`. Do not add it yourself:

```pascal
// WRONG -- double prefix: "Bearer Bearer eyJ..."
REST.SetBearer('Bearer eyJhbGciOiJIUzI1NiJ9...');

// RIGHT
REST.SetBearer('eyJhbGciOiJIUzI1NiJ9...');
```

### 404 Not Found

**Problem**: Status code 404 on a valid endpoint.

**Cause 1**: Trailing slash mismatch. The API expects `/users` but you send `/users/`.

```pascal
// Try both
RESTUsers.EndPoint := '/users';   // no trailing slash
RESTUsers.EndPoint := '/users/';  // with trailing slash
```

**Cause 2**: BaseUrl includes a path that is duplicated in the EndPoint.

```pascal
// WRONG -- requests /v1/v1/users
REST.BaseUrl := 'https://api.example.com/v1';
RESTUsers.EndPoint := '/v1/users';

// RIGHT
REST.BaseUrl := 'https://api.example.com/v1';
RESTUsers.EndPoint := '/users';
```

### 500 Internal Server Error

**Problem**: Server returns 500 on POST/PATCH requests.

**Cause**: The request body is malformed or missing required fields.

**Fix**: Log the request body before sending:

```pascal
var Body := '{"name": "Andre"}';
// Log it
Memo1.Lines.Add('Sending: ' + Body);

var Response := REST.Post(StatusCode, '/users', '', Body);
```

Common body issues:
- Missing `Content-Type: application/json` header (TTina4REST sets this automatically)
- Unescaped quotes in string values
- Wrong field names (camelCase vs snake_case)

### Timeout Errors

**Problem**: REST calls hang for 30+ seconds, then fail.

**Cause**: Default timeout is too long, or the server is unresponsive.

**Fix**:

```pascal
// Set a reasonable timeout (milliseconds)
REST.Timeout := 10000;  // 10 seconds

// Handle timeout in async calls
RESTUsers.OnExecuteDone := procedure(Sender: TObject)
begin
  TThread.Synchronize(nil, procedure
  begin
    if RESTUsers.LastStatusCode = 0 then
      ShowMessage('Request timed out or network error')
    else
      ProcessResponse;
  end);
end;
```

### CORS Issues When Calling Web APIs

**Problem**: Browser-based APIs return CORS errors. Your Delphi app gets unexpected responses.

**Cause**: CORS is a browser security feature. Desktop applications do not have CORS restrictions. If you are getting errors, the issue is something else (wrong URL, authentication, SSL).

**Fix**: CORS is not relevant for Delphi desktop apps. Check the actual error message -- it is likely a network, SSL, or auth issue disguised by a generic error message.

---

## 3. JSON Issues

### Access Violation Parsing Malformed JSON

**Problem**: `StrToJSONObject` crashes with an access violation.

**Cause**: The input string is not valid JSON, and you are using the result without checking for nil.

**Fix**:

```pascal
// WRONG
var Obj := StrToJSONObject(ResponseText);
ShowMessage(Obj.GetValue<string>('name'));  // AV if Obj is nil

// RIGHT
var Obj := StrToJSONObject(ResponseText);
try
  if Assigned(Obj) then
    ShowMessage(Obj.GetValue<string>('name'))
  else
    ShowMessage('Failed to parse JSON: ' + ResponseText.Substring(0, 100));
finally
  Obj.Free;
end;
```

### Field Names Not Matching

**Problem**: `FieldByName('firstName')` raises "Field not found" but the data is there.

**Cause**: `PopulateMemTableFromJSON` and `GetFieldDefsFromJSONObject` convert camelCase to snake_case when the `ASnakeCase` parameter is `True` (which is the default in some contexts).

**Fix**: Use the correct field name:

```pascal
// If JSON has "firstName" and snake_case conversion is on:
MemTable.FieldByName('first_name').AsString;  // RIGHT
MemTable.FieldByName('firstName').AsString;    // WRONG -- raises exception

// Check what fields exist:
for var I := 0 to MemTable.FieldCount - 1 do
  Memo1.Lines.Add(MemTable.Fields[I].FieldName);
```

### Nested Objects Becoming ftMemo

**Problem**: A nested JSON object like `{"address": {"city": "Cape Town"}}` becomes a single `ftMemo` field instead of separate fields.

**Cause**: `GetFieldDefsFromJSONObject` stores nested objects and arrays as `ftMemo` fields containing the JSON string. This is by design -- MemTables do not support nested structures.

**Fix**: Parse the nested JSON from the memo field:

```pascal
var AddressJSON := MemTable.FieldByName('address').AsString;
var Addr := StrToJSONObject(AddressJSON);
try
  if Assigned(Addr) then
    ShowMessage('City: ' + Addr.GetValue<string>('city'));
finally
  Addr.Free;
end;
```

Or use a separate TTina4JSONAdapter to extract the nested data into its own MemTable.

### Large JSON Causing Out of Memory

**Problem**: Parsing a very large JSON response (100MB+) causes the app to run out of memory.

**Cause**: Delphi's `TJSONObject` loads the entire document into memory. Combined with string copies during parsing, memory usage can be 3-5x the JSON size.

**Fix**: Use pagination to limit response size:

```pascal
RESTUsers.QueryParams := 'page=1&limit=100';  // Fetch 100 at a time
```

If the API does not support pagination, process the response in chunks or use streaming JSON parsers.

---

## 4. MemTable Issues

### "Field not found"

**Problem**: `MemTable.FieldByName('user_name')` raises "Field 'user_name' not found."

**Cause 1**: The API changed its response format and the field name is different.

**Fix**: List all fields to see what actually exists:

```pascal
procedure TFormMain.DebugMemTableFields(ATable: TFDMemTable);
begin
  if not ATable.Active then
  begin
    ShowMessage('MemTable is not active');
    Exit;
  end;

  var Fields := '';
  for var I := 0 to ATable.FieldCount - 1 do
    Fields := Fields + ATable.Fields[I].FieldName + ' (' +
      ATable.Fields[I].ClassName + ')' + #13#10;
  ShowMessage(Fields);
end;
```

**Cause 2**: The MemTable was never populated -- `ExecuteRESTCall` failed silently.

**Fix**: Check `LastStatusCode` before accessing MemTable data:

```pascal
RESTUsers.ExecuteRESTCall;
if RESTUsers.LastStatusCode = 200 then
begin
  // Safe to access MemTable
  MemUsers.First;
end
else
  ShowMessage('REST call failed: ' + RESTUsers.LastStatusCode.ToString);
```

### Duplicate Key Violations in Sync Mode

**Problem**: `PopulateMemTableFromJSON` raises an index violation error when using Sync mode.

**Cause**: `IndexFieldNames` is set to a field that has duplicate values in the data, or the index was not created properly.

**Fix**:

```pascal
// Make sure the index field is unique in the data
RESTUsers.SyncMode := TTina4RestSyncMode.Sync;
RESTUsers.IndexFieldNames := 'id';  // 'id' must be unique

// If you need a compound key:
RESTUsers.IndexFieldNames := 'user_id;order_id';
```

### IndexFieldNames Not Set for Sync Mode

**Problem**: Sync mode does not update existing records -- it keeps appending duplicates.

**Cause**: `IndexFieldNames` is empty. Without it, the MemTable cannot match existing rows.

**Fix**:

```pascal
// WRONG -- Sync mode without index just appends
RESTUsers.SyncMode := TTina4RestSyncMode.Sync;
// IndexFieldNames is empty

// RIGHT
RESTUsers.SyncMode := TTina4RestSyncMode.Sync;
RESTUsers.IndexFieldNames := 'id';
```

### Data Type Mismatches

**Problem**: `FieldByName('price').AsFloat` returns 0 even though the JSON has `"price": "29.99"`.

**Cause**: The JSON value is a string `"29.99"`, not a number `29.99`. The field was created as `ftString`.

**Fix**: Convert explicitly:

```pascal
var PriceStr := MemTable.FieldByName('price').AsString;
var Price := StrToFloatDef(PriceStr, 0.0);
```

Or use `AsFloat` which does automatic conversion for most cases, but verify the field type:

```pascal
// Debug the field type
ShowMessage(MemTable.FieldByName('price').DataType.ToString);
// If it shows ftString, the JSON sent "29.99" as a string
```

---

## 5. HTML Renderer Issues

### Elements Not Displaying

**Problem**: You set `HTML.Text` but nothing appears in the renderer.

**Cause 1**: The renderer has zero width or height.

```pascal
// Check dimensions
ShowMessage(Format('Renderer size: %dx%d',
  [Round(Renderer.Width), Round(Renderer.Height)]));
```

**Cause 2**: The HTML has a syntax error that prevents rendering.

**Fix**: Start with minimal HTML and build up:

```pascal
// Test with minimal HTML first
Renderer.HTML.Text := '<p>Test</p>';
// If this works, add more content gradually
```

### CSS Not Applying

**Problem**: CSS classes or styles are ignored.

**Cause**: The renderer supports a subset of CSS. Some properties are not implemented.

**Fix**: Check the supported CSS list in the documentation. Use inline styles as a fallback:

```pascal
// If a CSS class does not work:
'<div class="my-custom-class">Text</div>'  // might not work

// Use inline styles instead:
'<div style="color: red; font-size: 18px;">Text</div>'  // works
```

Supported CSS includes: `color`, `background-color`, `font-size`, `font-family`, `font-weight`, `padding`, `margin`, `border`, `border-radius`, `width`, `height`, `display`, `text-align`, and more. Complex selectors like `:nth-child` or `@media` queries are not supported.

### Form Controls Not Appearing

**Problem**: `<input>` or `<select>` elements are not visible.

**Cause**: The form control type is not supported, or the element is hidden by CSS.

**Fix**: Check supported form elements:

```pascal
// Supported input types:
'<input type="text">'       // works
'<input type="password">'   // works
'<input type="email">'      // works
'<input type="checkbox">'   // works
'<input type="radio">'      // works
'<input type="submit">'     // works
'<input type="button">'     // works
'<input type="file">'       // works
'<input type="date">'       // might not render as date picker
'<input type="range">'      // might not render as slider
'<textarea>'                // works
'<select><option>'          // works
```

### onclick Not Firing

**Problem**: Clicking an element with `onclick="App:MyMethod('test')"` does nothing.

**Cause 1**: The object was not registered with `RegisterObject`.

```pascal
// Must be called before setting HTML
Renderer.RegisterObject('App', Self);
```

**Cause 2**: The method does not exist or has the wrong signature.

```pascal
// The method must be published or public
// Parameter types must match what the onclick passes

// WRONG -- private method, not found by RTTI
private
  procedure MyMethod(const Value: string);

// RIGHT -- public method
public
  procedure MyMethod(Value: String);
```

**Cause 3**: Wrong quote escaping in the onclick attribute.

```pascal
// WRONG -- mismatched quotes
'<span onclick="App:MyMethod("test")">Click</span>'

// RIGHT -- use single quotes inside double, or escape
'<span onclick="App:MyMethod(''test'')">Click</span>'
```

**Cause 4**: The element is overlapped by another element. The click hits the wrong element.

**Fix**: Add a distinct `style="cursor: pointer; z-index: 10;"` and ensure nothing overlaps.

### Images Not Loading

**Problem**: `<img src="https://...">` shows a broken image or empty space.

**Cause 1**: Cache directory not set or not writable.

```pascal
Renderer.CacheEnabled := True;
Renderer.CacheDir := TPath.Combine(TPath.GetDocumentsPath, 'MyAppCache');
ForceDirectories(Renderer.CacheDir);  // Create if it does not exist
```

**Cause 2**: HTTPS image URL but SSL DLLs not installed.

**Fix**: Install SSL DLLs as described in Section 1.

**Cause 3**: The image URL returns a redirect that the renderer does not follow.

**Fix**: Use the final URL directly, or download the image separately and use a `data:` URI:

```pascal
var B64 := FileToBase64('downloaded_image.jpg');
Renderer.HTML.Text := '<img src="data:image/jpeg;base64,' + B64 + '">';
```

---

## 6. Page Navigation Issues

### Default Page Not Showing

**Problem**: The app starts with a blank renderer. No page is displayed.

**Cause**: No page has `IsDefault := True`.

**Fix**:

```pascal
var LoginPage := Pages.Pages.Add;
LoginPage.PageName := 'login';
LoginPage.IsDefault := True;  // This page shows on startup
LoginPage.HTMLContent.Text := '<h1>Login</h1>';
```

### Links Not Navigating

**Problem**: Clicking `<a href="#dashboard">` does not change the page.

**Cause 1**: The `href` value does not match any `PageName`.

```pascal
// Link href:     #dashboard
// Page.PageName: Dashboard   <-- case mismatch

// Fix: make them match exactly
Page.PageName := 'dashboard';  // lowercase
// HTML: <a href="#dashboard">  // matches
```

**Cause 2**: The renderer is not linked to the Pages component.

```pascal
Pages.Renderer := Renderer;  // Must be set
```

### OnBeforeNavigate Not Cancelling

**Problem**: Setting `Allow := False` in `OnBeforeNavigate` does not prevent navigation.

**Cause**: The `Allow` parameter is a `var` parameter. Make sure your event handler signature matches:

```pascal
// WRONG -- parameter not passed by reference
procedure TFormMain.BeforeNav(Sender: TObject;
  const FromPage, ToPage: string; Allow: Boolean);  // missing 'var'

// RIGHT
procedure TFormMain.BeforeNav(Sender: TObject;
  const FromPage, ToPage: string; var Allow: Boolean);
begin
  if (ToPage <> 'login') and (not IsAuthenticated) then
    Allow := False;  // Prevents navigation
end;
```

---

## 7. Twig Template Issues

### Template Not Rendering

**Problem**: Setting `Twig.Text` produces empty output or the raw template text.

**Cause 1**: Wrong template path for file-based templates.

```pascal
// Check the path exists
ShowMessage(Pages.TwigTemplatePath);
ShowMessage(BoolToStr(DirectoryExists(Pages.TwigTemplatePath), True));
```

**Cause 2**: Template syntax error. A missing `{% endif %}` or unmatched braces.

**Fix**: Test with a minimal template:

```pascal
Renderer.Twig.Text := '<p>{{ name }}</p>';
// If this works, the issue is in your complex template
```

### Variables Empty

**Problem**: Template renders but variables show as empty.

**Cause**: Variables were not set before the template was assigned.

```pascal
// WRONG -- template renders before variables are set
Renderer.Twig.Text := '<h1>{{ title }}</h1>';
Renderer.SetTwigVariable('title', 'Hello');

// RIGHT -- set variables first
Renderer.SetTwigVariable('title', 'Hello');
Renderer.Twig.Text := '<h1>{{ title }}</h1>';
```

### Includes Failing

**Problem**: `{% include 'header.html' %}` does not work. The template renders without the included content.

**Cause**: `TwigTemplatePath` is not set or points to the wrong directory.

**Fix**:

```pascal
// Set the base path for includes
Pages.TwigTemplatePath := 'C:\MyApp\templates';
// or
Renderer.TwigTemplatePath := 'C:\MyApp\templates';

// The included file must exist at:
// C:\MyApp\templates\header.html
```

---

## 8. WebSocket Issues

### Connection Refused

**Problem**: WebSocket connection fails immediately.

**Cause 1**: Wrong URL scheme. Use `wss://` for secure or `ws://` for insecure.

```pascal
// WRONG
FWebSocket.URL := 'https://api.example.com/ws';

// RIGHT
FWebSocket.URL := 'wss://api.example.com/ws';
```

**Cause 2**: Server not running or firewall blocking the port.

**Fix**: Test the WebSocket URL with a browser-based tool (like websocat or a browser extension) to verify the server is reachable.

### Messages Not Receiving

**Problem**: WebSocket connects successfully but `OnMessage` never fires.

**Cause 1**: `OnMessage` event not wired up.

```pascal
// WRONG -- event handler not assigned
FWebSocket.Connect;

// RIGHT
FWebSocket.OnMessage := procedure(Sender: TObject; const Msg: string)
begin
  TThread.Synchronize(nil, procedure
  begin
    ProcessMessage(Msg);
  end);
end;
FWebSocket.Connect;
```

**Cause 2**: The server sends binary messages, not text. Check server documentation.

**Cause 3**: The server requires a subscription message after connecting.

```pascal
FWebSocket.OnConnect := procedure(Sender: TObject)
begin
  { Some servers require subscribing to channels }
  FWebSocket.Send('{"action": "subscribe", "channel": "notifications"}');
end;
```

### Auto-Reconnect Not Working

**Problem**: After a disconnect, the WebSocket does not reconnect.

**Cause**: Auto-reconnect properties not configured.

**Fix**:

```pascal
FWebSocket.AutoReconnect := True;
FWebSocket.ReconnectInterval := 5000;  // 5 seconds between attempts

FWebSocket.OnDisconnect := procedure(Sender: TObject)
begin
  TThread.Synchronize(nil, procedure
  begin
    ShowNotification('Connection lost. Reconnecting...');
  end);
end;

FWebSocket.OnReconnect := procedure(Sender: TObject)
begin
  TThread.Synchronize(nil, procedure
  begin
    ShowNotification('Reconnected.');
    { Re-authenticate if needed }
    FWebSocket.Send('{"action": "auth", "token": "' + FBearerToken + '"}');
  end);
end;
```

---

## 9. Diagnostic Checklists

### TTina4REST Checklist

When REST calls are not working:

1. Is `BaseUrl` set and correct (no trailing slash)?
2. Is the endpoint path correct (starts with `/`)?
3. Are SSL DLLs installed for the correct bitness?
4. Is authentication set (`SetBearer` or `Username`/`Password`)?
5. What status code comes back? (0 = network error, 401 = auth, 404 = wrong path)
6. Can you reach the URL from a browser or curl?

### TTina4HTMLRender Checklist

When the renderer is not displaying correctly:

1. Does the renderer have non-zero width and height?
2. Is `RegisterObject` called for RTTI onclick?
3. Are the methods public (not private)?
4. Is the HTML valid (all tags closed)?
5. Are images using HTTPS (SSL DLLs needed)?
6. Is `CacheDir` writable?

### TTina4HTMLPages Checklist

When pages are not navigating:

1. Is `Renderer` linked to a TTina4HTMLRender?
2. Does at least one page have `IsDefault := True`?
3. Do `href` values match `PageName` values (case-sensitive)?
4. Is `OnBeforeNavigate` blocking with `Allow := False`?
5. Is the page collection empty?

### TTina4RESTRequest Checklist

When data is not loading into MemTable:

1. Is `Tina4REST` linked to a TTina4REST component?
2. Is `EndPoint` set correctly?
3. Is `DataKey` set to the correct JSON key?
4. Is `MemTable` linked to a TFDMemTable?
5. Does the API response contain the expected `DataKey`?
6. Is `SyncMode` set correctly? (Sync needs `IndexFieldNames`)

---

## 10. Quick Reference: Error to Fix

| Symptom | Likely Cause | Section |
|---|---|---|
| "Could not load SSL library" | Wrong bitness SSL DLLs | 1 |
| Status code 0 | Network error or timeout | 2 |
| Status code 401 | Token expired or wrong auth | 2 |
| Status code 404 | Wrong endpoint or double path | 2 |
| Access violation on JSON parse | nil result not checked | 3 |
| "Field not found" on MemTable | snake_case conversion | 4 |
| Blank renderer | Zero width/height or empty HTML | 5 |
| onclick does nothing | RegisterObject missing | 5 |
| No default page shown | IsDefault not set | 6 |
| Twig variables empty | Set after template assigned | 7 |
| WebSocket not connecting | Wrong URL scheme (https vs wss) | 8 |
| UI freezes on REST call | Synchronous call, use async | Ch. 13 |
| Memory leak | TJSONObject not freed | Ch. 13 |

---

## Summary

Most Tina4 Delphi issues fall into five categories:

1. **SSL configuration** -- wrong DLL bitness, missing DLLs, certificate issues
2. **REST communication** -- wrong endpoints, auth problems, missing error handling
3. **JSON structure** -- nil checks, field name mismatches, nested object handling
4. **HTML rendering** -- registration, event wiring, CSS support limits
5. **Threading** -- synchronous calls blocking UI, missing TThread.Synchronize

When something does not work, start with the diagnostic checklist for the component involved. Check the status code. Log the response. Verify the field names. Nine times out of ten, the fix is in this chapter.
