# Chapter 13: Design Patterns & Best Practices

## What We Learned the Hard Way

You call `REST.Get` and forget to free the response. The app leaks memory. You parse JSON in the main thread and the UI freezes for two seconds. You hardcode the API key in the source and push it to GitHub. You rebuild the entire HTML page when only one label needs updating.

Every pattern in this chapter was discovered through real-world mistakes. Every best practice exists because someone did it the wrong way first. This is the chapter you read before you ship -- and the chapter you return to when something breaks and you cannot figure out why.

---

## 1. Memory Management

Delphi does not have a garbage collector. Every object you create must be freed. The Tina4 components create `TJSONObject` instances that you own. If you do not free them, the memory leaks silently until the application crashes.

### The try/finally Pattern

Every `TJSONObject` returned by `TTina4REST` must be freed:

```pascal
// WRONG -- leaks memory if an exception occurs between Get and Free
var Response := REST.Get(StatusCode, '/users');
ShowMessage(Response.ToString);
Response.Free;

// RIGHT -- guaranteed cleanup
var Response := REST.Get(StatusCode, '/users');
try
  ShowMessage(Response.ToString);
finally
  Response.Free;
end;
```

This applies to every REST method: `Get`, `Post`, `Patch`, `Put`, `Delete`. They all return a `TJSONObject` that you own.

### Parsing JSON Safely

`StrToJSONObject` returns `nil` on failure. Always check:

```pascal
// WRONG -- access violation if JSON is malformed
var Obj := StrToJSONObject(SomeString);
ShowMessage(Obj.GetValue<string>('name'));
Obj.Free;

// RIGHT -- nil check before use
var Obj := StrToJSONObject(SomeString);
try
  if Assigned(Obj) then
    ShowMessage(Obj.GetValue<string>('name'))
  else
    ShowMessage('Invalid JSON');
finally
  Obj.Free;  // Free is safe to call on nil
end;
```

### Component Ownership

Components dropped on a form at design time are owned by the form. The form frees them automatically. Components created at runtime need explicit ownership:

```pascal
// Owned by Self (the form) -- freed automatically
var Adapter := TTina4JSONAdapter.Create(Self);
Adapter.MemTable := FDMemTable1;

// No owner -- you must free it yourself
var Twig := TTina4Twig.Create(nil);
try
  Twig.Render('template.html', Variables);
finally
  Twig.Free;
end;
```

Rule of thumb: if the component lives for the form's lifetime, pass `Self` as owner. If it is temporary, pass `nil` and use try/finally.

### MemTable Lifecycle

`TFDMemTable` does not connect to a database, so it does not need explicit cleanup of connections. But be aware of when data is valid:

```pascal
// WRONG -- MemTable might not be active
ShowMessage(MemUsers.FieldByName('name').AsString);

// RIGHT -- check Active and RecordCount
if MemUsers.Active and (MemUsers.RecordCount > 0) then
  ShowMessage(MemUsers.FieldByName('name').AsString)
else
  ShowMessage('No data loaded');
```

---

## 2. Async Patterns

### The Problem with Synchronous Calls

`ExecuteRESTCall` blocks the main thread. The UI freezes until the response arrives. On a slow network, the user sees a frozen window and thinks the app crashed.

```pascal
// WRONG -- blocks UI thread
RESTUsers.ExecuteRESTCall;  // 2-second freeze
UpdateUI;
```

### The Async Solution

```pascal
// RIGHT -- non-blocking
RESTUsers.OnExecuteDone := procedure(Sender: TObject)
begin
  TThread.Synchronize(nil, procedure
  begin
    UpdateUI;
  end);
end;
RESTUsers.ExecuteRESTCallAsync;
```

`ExecuteRESTCallAsync` runs the HTTP call on a background thread. When it completes, `OnExecuteDone` fires. But `OnExecuteDone` fires on the background thread, not the main thread. You must use `TThread.Synchronize` to update UI controls.

### Loading Indicators

Show a loading state while the async call runs:

```pascal
procedure TFormMain.FetchUsersAsync;
begin
  { Show loading }
  Renderer.SetElementText('userTableBody', 'Loading...');
  Renderer.SetElementVisible('loadingSpinner', True);

  RESTUsers.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      { Hide loading, show data }
      Renderer.SetElementVisible('loadingSpinner', False);
      RefreshUserTable;
    end);
  end;
  RESTUsers.ExecuteRESTCallAsync;
end;
```

### Multiple Concurrent Requests

When you need data from multiple endpoints simultaneously:

```pascal
procedure TFormMain.LoadDashboard;
var
  StatsLoaded, UsersLoaded: Boolean;
begin
  StatsLoaded := False;
  UsersLoaded := False;

  Renderer.HTML.Text :=
    '<div style="padding: 20px;">' +
    '  <p id="loadStatus">Loading dashboard data...</p>' +
    '</div>';

  RESTStats.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      StatsLoaded := True;
      if StatsLoaded and UsersLoaded then
        RenderFullDashboard;
    end);
  end;

  RESTUsers.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      UsersLoaded := True;
      if StatsLoaded and UsersLoaded then
        RenderFullDashboard;
    end);
  end;

  RESTStats.ExecuteRESTCallAsync;
  RESTUsers.ExecuteRESTCallAsync;
end;
```

Both requests fire simultaneously. The dashboard renders when both complete. This is faster than sequential calls.

### Cancellation and Timeouts

The underlying HTTP client supports timeouts. Set them on the TTina4REST component:

```pascal
REST.Timeout := 10000;  // 10 seconds

RESTUsers.OnExecuteDone := procedure(Sender: TObject)
begin
  TThread.Synchronize(nil, procedure
  begin
    if RESTUsers.LastStatusCode = 0 then
      ShowNotification('Request timed out.', True)
    else
      RefreshUserTable;
  end);
end;
RESTUsers.ExecuteRESTCallAsync;
```

---

## 3. Error Handling Patterns

### Status Code Checking

Every REST response has a status code. Check it before using the data:

```pascal
procedure TFormMain.HandleResponse(StatusCode: Integer; Response: TJSONObject);
begin
  case StatusCode of
    200:
      ProcessData(Response);
    201:
      ShowNotification('Created successfully.');
    204:
      ShowNotification('Deleted successfully.');
    400:
      ShowNotification('Bad request: check your input.', True);
    401:
      begin
        ShowNotification('Session expired. Please log in again.', True);
        DoLogout;
      end;
    403:
      ShowNotification('Access denied.', True);
    404:
      ShowNotification('Resource not found.', True);
    422:
      begin
        { Extract validation errors from response }
        if Assigned(Response) then
        begin
          var Errors := Response.GetValue<TJSONArray>('errors');
          if Assigned(Errors) then
          begin
            var Msg := '';
            for var I := 0 to Errors.Count - 1 do
              Msg := Msg + Errors.Items[I].GetValue<string>('message') + #13#10;
            ShowNotification(Msg.Trim, True);
          end;
        end
        else
          ShowNotification('Validation failed.', True);
      end;
    500..599:
      ShowNotification('Server error. Please try again later.', True);
  else
    ShowNotification('Unexpected response: ' + StatusCode.ToString, True);
  end;
end;
```

### JSON Parse Failure

Never assume JSON parsing will succeed:

```pascal
// WRONG -- crashes on malformed JSON
var Users := Response.GetValue<TJSONArray>('records');
for var I := 0 to Users.Count - 1 do
  ProcessUser(Users.Items[I] as TJSONObject);

// RIGHT -- defensive parsing
var UsersValue := Response.FindValue('records');
if (UsersValue <> nil) and (UsersValue is TJSONArray) then
begin
  var Users := UsersValue as TJSONArray;
  for var I := 0 to Users.Count - 1 do
  begin
    if Users.Items[I] is TJSONObject then
      ProcessUser(Users.Items[I] as TJSONObject);
  end;
end
else
  ShowNotification('Unexpected response format.', True);
```

### Network Error Handling

Wrap REST calls in exception handlers:

```pascal
procedure TFormMain.SafeFetch(const EndPoint: string; OnDone: TProc<TJSONObject>);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  try
    Response := REST.Get(StatusCode, EndPoint, '');
    try
      if StatusCode = 200 then
        OnDone(Response)
      else
        HandleResponse(StatusCode, Response);
    finally
      Response.Free;
    end;
  except
    on E: ENetHTTPClientException do
    begin
      if E.Message.Contains('SSL') then
        ShowNotification('SSL error: check your SSL DLL configuration.', True)
      else if E.Message.Contains('Timeout') then
        ShowNotification('Request timed out. Check your network.', True)
      else
        ShowNotification('Network error: ' + E.Message, True);
    end;
    on E: Exception do
      ShowNotification('Error: ' + E.Message, True);
  end;
end;
```

### User-Friendly Error Messages in HTML

Display errors in the HTML renderer instead of using ShowMessage dialogs:

```pascal
procedure TFormMain.ShowError(const Msg: string);
begin
  Renderer.SetElementVisible('errorBanner', True);
  Renderer.SetElementText('errorBanner', Msg);
  Renderer.SetElementStyle('errorBanner', 'background-color', '#e74c3c');
  Renderer.SetElementStyle('errorBanner', 'color', 'white');
  Renderer.SetElementStyle('errorBanner', 'padding', '12px');
  Renderer.SetElementStyle('errorBanner', 'border-radius', '4px');

  TTask.Run(procedure
  begin
    Sleep(5000);
    TThread.Synchronize(nil, procedure
    begin
      Renderer.SetElementVisible('errorBanner', False);
    end);
  end);
end;
```

---

## 4. Design-Time vs Runtime

### What to Configure in Object Inspector

Set these properties at design time -- they rarely change:

| Component | Property | Why |
|---|---|---|
| `TTina4REST` | `BaseUrl` | The API base URL is fixed per deployment |
| `TTina4RESTRequest` | `Tina4REST` | Links never change at runtime |
| `TTina4RESTRequest` | `DataKey` | JSON key is defined by the API |
| `TTina4RESTRequest` | `MemTable` | Target MemTable is fixed |
| `TTina4HTMLPages` | `Renderer` | Renderer link is permanent |
| `TTina4HTMLRender` | `CacheEnabled` | Caching policy is global |

### What to Configure in Code

Set these at runtime -- they depend on user actions or environment:

```pascal
// Auth tokens change on login
REST.SetBearer(Token);

// Endpoints change based on context
RESTUsers.EndPoint := '/users/' + UserId + '/orders';

// Query params change with search/pagination
RESTUsers.QueryParams := 'page=2&search=admin';

// HTML content changes with data
Renderer.HTML.Text := BuildDynamicHTML;

// Twig variables change per render
Pages.SetTwigVariable('userName', CurrentUser.Name);
```

### When to Create Components Dynamically

Create components at runtime when:
- The number of instances depends on data (e.g., one TTina4RESTRequest per API entity)
- The component is temporary (e.g., a one-time report renderer)
- You need a pool of workers

```pascal
function TFormMain.CreateRESTRequest(const EndPoint, DataKey: string;
  AMemTable: TFDMemTable): TTina4RESTRequest;
begin
  Result := TTina4RESTRequest.Create(Self);
  Result.Tina4REST := REST;
  Result.EndPoint := EndPoint;
  Result.DataKey := DataKey;
  Result.MemTable := AMemTable;
  Result.RequestType := TTina4RequestType.Get;
  Result.SyncMode := TTina4RestSyncMode.Clear;
end;

// Usage
var ReqOrders := CreateRESTRequest('/orders', 'records', MemOrders);
try
  ReqOrders.ExecuteRESTCall;
  // process MemOrders
finally
  ReqOrders.Free;
end;
```

---

## 5. Data Flow Patterns

### Unidirectional: API to MemTable to UI

The most common pattern. Data flows in one direction:

```
API Response --> PopulateMemTableFromJSON --> MemTable --> HTML Render
```

```pascal
procedure TFormMain.LoadProducts;
begin
  RESTProducts.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      { MemTable is populated automatically by RESTRequest }
      { Now render it }
      RenderProductTable;
    end);
  end;
  RESTProducts.ExecuteRESTCallAsync;
end;

procedure TFormMain.RenderProductTable;
var
  HTML: string;
begin
  HTML := '<table>';
  MemProducts.First;
  while not MemProducts.Eof do
  begin
    HTML := HTML +
      '<tr>' +
      '  <td>' + MemProducts.FieldByName('name').AsString + '</td>' +
      '  <td>' + MemProducts.FieldByName('price').AsString + '</td>' +
      '</tr>';
    MemProducts.Next;
  end;
  HTML := HTML + '</table>';
  Renderer.HTML.Text := HTML;
end;
```

### Bidirectional: UI to API to MemTable to UI

User fills a form, submits it, the API processes it, the response refreshes the data:

```
HTML Form --> onclick/OnFormSubmit --> POST to API --> Refresh MemTable --> Re-render
```

```pascal
procedure TFormMain.HandleFormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
var
  StatusCode: Integer;
  Body: TJSONObject;
  Response: TJSONObject;
begin
  if FormName = 'productForm' then
  begin
    Body := TJSONObject.Create;
    try
      Body.AddPair('name', FormData.Values['name']);
      Body.AddPair('price', FormData.Values['price']);

      Response := REST.Post(StatusCode, '/products', '', Body.ToString);
      try
        if StatusCode = 201 then
        begin
          { Refresh the list to include the new product }
          RESTProducts.ExecuteRESTCall;
          RenderProductTable;
          ShowNotification('Product created.');
        end
        else
          ShowError('Failed to create product.');
      finally
        Response.Free;
      end;
    finally
      Body.Free;
    end;
  end;
end;
```

### Event-Driven: WebSocket to UI

Real-time updates bypass the request/response cycle:

```
WebSocket Message --> Parse JSON --> Update MemTable or UI directly
```

```pascal
FWebSocket.OnMessage := procedure(Sender: TObject; const Msg: string)
begin
  TThread.Synchronize(nil, procedure
  var
    JSON: TJSONObject;
  begin
    JSON := StrToJSONObject(Msg);
    try
      if Assigned(JSON) then
      begin
        var EventType := JSON.GetValue<string>('type', '');

        if EventType = 'user.created' then
        begin
          { Add to MemTable without full refresh }
          MemUsers.Append;
          MemUsers.FieldByName('id').AsString :=
            JSON.GetValue<string>('data.id');
          MemUsers.FieldByName('name').AsString :=
            JSON.GetValue<string>('data.name');
          MemUsers.Post;
          RenderUserTable;
        end
        else if EventType = 'stats.updated' then
        begin
          { Refresh stats }
          FetchStats;
        end;
      end;
    finally
      JSON.Free;
    end;
  end);
end;
```

---

## 6. Performance

### MemTable SyncMode for Incremental Updates

When polling an API for updates, use `Sync` mode instead of `Clear`:

```pascal
// WRONG for polling -- clears and rebuilds the entire table
RESTUsers.SyncMode := TTina4RestSyncMode.Clear;

// RIGHT for polling -- updates existing rows, adds new ones
RESTUsers.SyncMode := TTina4RestSyncMode.Sync;
RESTUsers.IndexFieldNames := 'id';
```

In `Sync` mode, the MemTable matches rows by `IndexFieldNames`. Existing rows are updated in place. New rows are inserted. Bound controls (grids, lists) update smoothly without flickering.

### Minimizing HTML Re-renders

Do not rebuild the entire HTML when only one element changes:

```pascal
// WRONG -- rebuilds entire page, resets scroll position, flickers
Renderer.HTML.Text := BuildFullPageHTML;

// RIGHT -- update just the element that changed
Renderer.SetElementText('userCount', NewCount.ToString);
Renderer.SetElementStyle('statusDot', 'background-color', '#2ecc71');
Renderer.SetElementVisible('loadingSpinner', False);
```

Use `SetElementText`, `SetElementStyle`, `SetElementVisible`, and `SetElementValue` for surgical updates. Full re-renders should only happen when the page structure changes.

### Image Caching

Enable disk-based caching for images loaded in TTina4HTMLRender:

```pascal
Renderer.CacheEnabled := True;
Renderer.CacheDir := TPath.Combine(TPath.GetDocumentsPath, 'MyAppCache');
```

Without caching, every page render re-downloads all images. With caching, images are loaded from disk after the first download. This makes page transitions near-instant.

### Lazy Loading with Pagination

Do not load all records at once. Use pagination:

```pascal
procedure TFormMain.FetchPage(APage: Integer);
begin
  RESTUsers.QueryParams := Format('page=%d&limit=20', [APage]);
  RESTUsers.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      RenderUserTable;
      RenderPaginationControls(APage);
    end);
  end;
  RESTUsers.ExecuteRESTCallAsync;
end;
```

Twenty records per page. The user clicks Next to load more. The API does the heavy lifting.

---

## 7. Security

### Never Hardcode Credentials

```pascal
// WRONG -- credentials in source code
REST.Username := 'admin';
REST.Password := 'P@ssw0rd123';

// RIGHT -- read from config file or environment
var Config := TIniFile.Create(TPath.Combine(
  TPath.GetDocumentsPath, 'myapp.ini'));
try
  REST.BaseUrl := Config.ReadString('API', 'BaseUrl', '');
  // Do not store credentials in config either
  // Use login flow with bearer tokens instead
finally
  Config.Free;
end;
```

### Token Refresh Pattern

Bearer tokens expire. Handle 401 responses with a refresh flow:

```pascal
procedure TFormMain.ExecuteWithRefresh(const EndPoint: string;
  OnSuccess: TProc<TJSONObject>);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := REST.Get(StatusCode, EndPoint, '');
  try
    if StatusCode = 401 then
    begin
      { Try to refresh the token }
      var RefreshResponse := REST.Post(StatusCode, '/auth/refresh', '',
        '{"refresh_token": "' + FRefreshToken + '"}');
      try
        if StatusCode = 200 then
        begin
          FBearerToken := RefreshResponse.GetValue<string>('token');
          FRefreshToken := RefreshResponse.GetValue<string>('refresh_token');
          REST.SetBearer(FBearerToken);

          { Retry the original request }
          Response.Free;
          Response := REST.Get(StatusCode, EndPoint, '');
          if StatusCode = 200 then
            OnSuccess(Response)
          else
            DoLogout;
        end
        else
          DoLogout;
      finally
        RefreshResponse.Free;
      end;
    end
    else if StatusCode = 200 then
      OnSuccess(Response)
    else
      HandleResponse(StatusCode, Response);
  finally
    Response.Free;
  end;
end;
```

### HTTPS Only

Never send credentials or tokens over HTTP. Always use HTTPS:

```pascal
// WRONG
REST.BaseUrl := 'http://api.example.com';

// RIGHT
REST.BaseUrl := 'https://api.example.com';
```

If your development server does not have SSL, use a self-signed certificate and configure the HTTP client to accept it during development only.

---

## 8. Project Organization

### Separate Data Modules

Keep REST components and MemTables in a data module, not on the main form:

```pascal
// DataModule.pas
unit DataModule;

interface

uses
  System.Classes, FireDAC.Comp.Client, Data.DB,
  Tina4REST, Tina4RESTRequest;

type
  TDM = class(TDataModule)
    REST: TTina4REST;
    RESTUsers: TTina4RESTRequest;
    RESTProducts: TTina4RESTRequest;
    MemUsers: TFDMemTable;
    MemProducts: TFDMemTable;
  end;

var
  DM: TDM;

// In MainUnit:
uses DataModule;

procedure TFormMain.LoadUsers;
begin
  DM.RESTUsers.ExecuteRESTCall;
  RenderUserTable(DM.MemUsers);
end;
```

### Template File Organization

Store Twig templates in a structured directory:

```
templates/
  layouts/
    base.html              -- Base layout with <head> and structure
    sidebar.html           -- Sidebar navigation component
  pages/
    dashboard.html         -- Dashboard page
    users/
      list.html            -- User list
      detail.html          -- User detail card
      form.html            -- User create/edit form
  components/
    stat-card.html         -- Reusable stat card
    data-table.html        -- Reusable data table
    notification.html      -- Notification toast
```

### Resource Management

For deployed applications, embed templates as resources or deploy them alongside the executable:

```pascal
procedure TFormMain.FormCreate(Sender: TObject);
begin
  { Templates are relative to the executable }
  Pages.TwigTemplatePath := TPath.Combine(
    ExtractFilePath(ParamStr(0)), 'templates');

  { Or use a configurable path }
  var ConfigPath := TPath.Combine(TPath.GetDocumentsPath, 'MyApp');
  ForceDirectories(ConfigPath);
end;
```

---

## 9. Complete Example: Refactoring a Poorly Written App

Here is a bad implementation. Read it and find the problems:

```pascal
// BAD CODE -- how many issues can you spot?
procedure TForm1.Button1Click(Sender: TObject);
var
  Resp: TJSONObject;
  SC: Integer;
begin
  Tina4REST1.BaseUrl := 'http://api.example.com';
  Tina4REST1.Username := 'admin';
  Tina4REST1.Password := 'admin123';

  Resp := Tina4REST1.Get(SC, '/users');
  var Users := Resp.GetValue<TJSONArray>('records');
  var HTML := '<table>';
  for var I := 0 to Users.Count - 1 do
  begin
    var U := Users.Items[I] as TJSONObject;
    HTML := HTML + '<tr><td>' + U.GetValue<string>('name') + '</td></tr>';
  end;
  HTML := HTML + '</table>';
  Tina4HTMLRender1.HTML.Text := HTML;
end;
```

Problems found:

1. **HTTP, not HTTPS** -- credentials sent in plain text
2. **Hardcoded credentials** -- username and password in source code
3. **BaseUrl set in click handler** -- should be set once in FormCreate
4. **No try/finally** -- `Resp` is never freed, memory leak
5. **No nil check on Resp** -- crashes if request fails
6. **No status code check** -- processes data even on 404 or 500
7. **No exception handling** -- network errors crash the app
8. **Synchronous call in UI thread** -- freezes the interface
9. **No type checking on JSON values** -- crashes on unexpected structure
10. **Component names are defaults** -- `Button1`, `Tina4REST1` tell you nothing

Here is the refactored version:

```pascal
unit UserListUnit;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls,
  Tina4REST, Tina4RESTRequest, Tina4HTMLRender,
  FireDAC.Comp.Client;

type
  TFormUserList = class(TForm)
    REST: TTina4REST;
    RESTUsers: TTina4RESTRequest;
    MemUsers: TFDMemTable;
    Renderer: TTina4HTMLRender;
    ButtonLoad: TButton;
    procedure FormCreate(Sender: TObject);
    procedure ButtonLoadClick(Sender: TObject);
  private
    procedure RenderUserTable;
    procedure ShowError(const Msg: string);
  end;

implementation

{$R *.fmx}

procedure TFormUserList.FormCreate(Sender: TObject);
begin
  REST.BaseUrl := 'https://api.example.com';
  { Token set after login -- never hardcode credentials }

  RESTUsers.Tina4REST := REST;
  RESTUsers.EndPoint := '/users';
  RESTUsers.DataKey := 'records';
  RESTUsers.MemTable := MemUsers;
end;

procedure TFormUserList.ButtonLoadClick(Sender: TObject);
begin
  ButtonLoad.Enabled := False;
  Renderer.HTML.Text := '<p>Loading...</p>';

  RESTUsers.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      ButtonLoad.Enabled := True;

      if RESTUsers.LastStatusCode = 200 then
        RenderUserTable
      else if RESTUsers.LastStatusCode = 401 then
        ShowError('Please log in first.')
      else
        ShowError('Failed to load users.');
    end);
  end;
  RESTUsers.ExecuteRESTCallAsync;
end;

procedure TFormUserList.RenderUserTable;
var
  HTML: string;
begin
  HTML := '<table style="width: 100%; border-collapse: collapse;">';
  HTML := HTML + '<tr style="background: #2c3e50; color: white;">' +
    '<th style="padding: 10px;">Name</th></tr>';

  if MemUsers.Active and (MemUsers.RecordCount > 0) then
  begin
    MemUsers.First;
    while not MemUsers.Eof do
    begin
      HTML := HTML + '<tr><td style="padding: 10px; border-bottom: 1px solid #eee;">' +
        MemUsers.FieldByName('name').AsString + '</td></tr>';
      MemUsers.Next;
    end;
  end
  else
    HTML := HTML + '<tr><td style="padding: 20px; text-align: center; ' +
      'color: #999;">No users found.</td></tr>';

  HTML := HTML + '</table>';
  Renderer.HTML.Text := HTML;
end;

procedure TFormUserList.ShowError(const Msg: string);
begin
  Renderer.HTML.Text :=
    '<div style="padding: 15px; background: #e74c3c; color: white; ' +
    '  border-radius: 4px;">' + Msg + '</div>';
end;

end.
```

What changed:

- HTTPS, not HTTP
- No hardcoded credentials -- token set after login
- BaseUrl set in FormCreate, not in click handler
- TTina4RESTRequest handles the REST call and MemTable population
- Async execution with `ExecuteRESTCallAsync`
- Status code checking
- Loading indicator while data fetches
- Button disabled during load to prevent double-clicks
- Meaningful component and method names
- MemTable Active and RecordCount checked before iteration
- Error messages displayed in the renderer, not as dialogs

---

## 10. Exercise: Code Review

Review the following code and identify five issues. Then fix each one.

```pascal
procedure TForm1.LoadOrders;
var
  R: TJSONObject;
  S: Integer;
begin
  R := Tina4REST1.Get(S, '/orders');
  var Data := R.GetValue<TJSONArray>('orders');
  PopulateMemTableFromJSON(FDMemTable1, 'orders', R.ToString);

  var Total := 0.0;
  FDMemTable1.First;
  while not FDMemTable1.Eof do
  begin
    Total := Total + FDMemTable1.FieldByName('amount').AsFloat;
    FDMemTable1.Next;
  end;

  Tina4HTMLRender1.HTML.Text :=
    '<h1>Orders</h1><p>Total: $' + FloatToStr(Total) + '</p>';
end;
```

### Solution

**Issue 1**: `R` (TJSONObject) is never freed -- memory leak.

**Issue 2**: No `try/except` -- network errors crash the app.

**Issue 3**: No status code check -- processes a 500 error response as valid data.

**Issue 4**: `FloatToStr` uses locale-specific formatting -- on some systems `1234.5` becomes `1234,5`.

**Issue 5**: Synchronous call blocks the UI thread.

Fixed version:

```pascal
procedure TFormOrders.LoadOrders;
begin
  Renderer.HTML.Text := '<p>Loading orders...</p>';

  RESTOrders.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      if RESTOrders.LastStatusCode <> 200 then
      begin
        Renderer.HTML.Text :=
          '<div style="color: red;">Failed to load orders.</div>';
        Exit;
      end;

      var Total := 0.0;
      if MemOrders.Active then
      begin
        MemOrders.First;
        while not MemOrders.Eof do
        begin
          Total := Total + MemOrders.FieldByName('amount').AsFloat;
          MemOrders.Next;
        end;
      end;

      Renderer.HTML.Text :=
        '<h1>Orders</h1><p>Total: $' +
        FormatFloat('#,##0.00', Total) + '</p>';
    end);
  end;
  RESTOrders.ExecuteRESTCallAsync;
end;
```

The TTina4RESTRequest handles JSON parsing and MemTable population. `FormatFloat` gives consistent formatting. The async call keeps the UI responsive. The status code is checked before processing data.

---

## Summary

The patterns in this chapter come down to four principles:

1. **Free what you create.** Every `TJSONObject` in a try/finally. Every dynamic component with an owner or explicit Free.

2. **Never block the main thread.** Use `ExecuteRESTCallAsync` with `TThread.Synchronize` for UI updates.

3. **Check before you use.** Status codes before processing responses. `Assigned()` before accessing objects. `Active` and `RecordCount` before iterating MemTables.

4. **Update surgically.** Use `SetElementText` and `SetElementVisible` instead of rebuilding the entire HTML. Use `Sync` mode instead of `Clear` when polling.

These four principles prevent the five most common bugs in Tina4 Delphi applications: memory leaks, frozen UIs, access violations, missing error messages, and flickering displays. Follow them, and the bugs stop before they start.
