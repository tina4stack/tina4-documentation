# REST Client

::: tip
TTina4REST provides the base configuration (URL, auth, headers) while TTina4RESTRequest executes calls and populates MemTables automatically.
:::

## TTina4REST -- Base Configuration {#rest-config}

Drop a `TTina4REST` on your form and configure the connection. Other components reference this for their HTTP calls.

```pascal
// Design-time: set BaseUrl, Username, Password in Object Inspector
// Runtime:
Tina4REST1.BaseUrl := 'https://api.example.com/v1';
Tina4REST1.Username := 'admin';
Tina4REST1.Password := 'secret';
Tina4REST1.SetBearer('eyJhbGciOiJIUzI1NiJ9...');
```

## Direct REST Calls {#direct-calls}

All methods return a `TJSONObject` that the caller must free.

```pascal
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := Tina4REST1.Get(StatusCode, '/users', 'page=1&limit=10');
  try
    Memo1.Lines.Text := Response.ToString;
  finally
    Response.Free;
  end;
end;
```

### Methods {#methods}

| Method | Description |
|---|---|
| `Get(StatusCode, EndPoint, QueryParams)` | HTTP GET, returns `TJSONObject` |
| `Post(StatusCode, EndPoint, QueryParams, Body)` | HTTP POST |
| `Patch(StatusCode, EndPoint, QueryParams, Body)` | HTTP PATCH |
| `Put(StatusCode, EndPoint, QueryParams, Body)` | HTTP PUT |
| `Delete(StatusCode, EndPoint, QueryParams)` | HTTP DELETE |
| `SetBearer(Token)` | Adds an `Authorization: Bearer` header |

## TTina4RESTRequest -- Declarative REST Calls {#rest-request}

Links to a `TTina4REST` component and executes REST calls with automatic MemTable population.

### Basic GET with MemTable {#basic-get}

```pascal
// Design-time:
//   Tina4REST     -> Tina4REST1
//   EndPoint      -> /users
//   RequestType   -> Get
//   DataKey       -> records
//   MemTable      -> FDMemTable1
//   SyncMode      -> Clear

// Runtime:
Tina4RESTRequest1.ExecuteRESTCall;
// FDMemTable1 is now populated with the "records" array from the response
```

### POST with Request Body {#post}

```pascal
Tina4RESTRequest1.RequestType := TTina4RequestType.Post;
Tina4RESTRequest1.EndPoint := '/users';
Tina4RESTRequest1.RequestBody.Text := '{"name": "Andre", "email": "andre@test.com"}';
Tina4RESTRequest1.ExecuteRESTCall;
```

### Master/Detail with Parameter Injection {#master-detail}

When a `MasterSource` is set, field values from the master's MemTable are injected into the endpoint, request body, and query params using `{fieldName}` placeholders.

```pascal
// Master request fetches customers
Tina4RESTRequest1.EndPoint := '/customers';
Tina4RESTRequest1.DataKey := 'records';
Tina4RESTRequest1.MemTable := FDMemTableCustomers;

// Detail request fetches orders for the current customer
Tina4RESTRequest2.MasterSource := Tina4RESTRequest1;
Tina4RESTRequest2.EndPoint := '/customers/{id}/orders';
Tina4RESTRequest2.DataKey := 'records';
Tina4RESTRequest2.MemTable := FDMemTableOrders;
```

### POST from MemTable Data {#source-memtable}

Links a `TFDMemTable` as the request body source. Rows are serialized to JSON automatically.

```pascal
Tina4RESTRequest1.RequestType := TTina4RequestType.Post;
Tina4RESTRequest1.EndPoint := '/import';
Tina4RESTRequest1.SourceMemTable := FDMemTableData;
Tina4RESTRequest1.SourceIgnoreFields := 'internal_id,temp_flag';
Tina4RESTRequest1.SourceIgnoreBlanks := True;
Tina4RESTRequest1.ExecuteRESTCall;
```

### Async Execution {#async}

```pascal
Tina4RESTRequest1.OnExecuteDone := procedure(Sender: TObject)
begin
  TThread.Synchronize(nil, procedure
  begin
    ShowMessage('Request complete');
  end);
end;
Tina4RESTRequest1.ExecuteRESTCallAsync;
```

### Events {#events}

| Event | Description |
|---|---|
| `OnExecuteDone` | Fired after the REST call completes and the MemTable is populated |
| `OnAddRecord` | Fired for each record added to the MemTable, allowing custom processing |
