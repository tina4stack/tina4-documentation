# Chapter 10: Real-World Integration

## Making the Components Talk

You have learned each Tina4 Delphi component in isolation. TTina4REST makes HTTP calls. TTina4RESTRequest populates MemTables. TTina4JSONAdapter fans out JSON into multiple tables. TTina4HTMLRender displays HTML. TTina4HTMLPages navigates between views. TTina4Twig renders templates. TTina4WebSocketClient receives real-time data.

Individually, they are useful. Together, they are a full-stack desktop application framework. This chapter shows you the patterns for connecting them -- the repeatable architectures that turn seven components into a cohesive application.

---

## 1. Philosophy: Components as a Pipeline

Think of Tina4 Delphi as a data pipeline:

```
Data Source -> Transform -> Display
```

Every pattern in this chapter follows this flow. The data source is usually a REST API or WebSocket feed. The transform converts JSON into structured Delphi data (MemTables, objects). The display renders that data as grids, HTML, or template-driven UI.

The components snap together at defined connection points:

- **TTina4REST** feeds **TTina4RESTRequest**
- **TTina4RESTRequest** feeds **TFDMemTable**
- **TFDMemTable** feeds **TStringGrid** or **TTina4JSONAdapter**
- **TTina4RESTRequest** feeds **TTina4JSONAdapter** (via MasterSource)
- **TTina4HTMLRender** displays data from any source via Twig variables
- **TTina4HTMLPages** organizes multiple views on a single renderer
- **TTina4WebSocketClient** pushes data into any of the above

---

## 2. Pattern 1: REST to MemTable to Grid

The most common pattern. Fetch data from an API, populate a MemTable, display in a grid.

```
REST API -> TTina4RESTRequest -> TFDMemTable -> TStringGrid
```

### Implementation

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  // Configure the pipeline
  Tina4REST1.BaseUrl := 'https://api.example.com/v1';

  RESTRequestProducts.Tina4REST := Tina4REST1;
  RESTRequestProducts.EndPoint := '/products';
  RESTRequestProducts.RequestType := TTina4RequestType.Get;
  RESTRequestProducts.DataKey := 'records';
  RESTRequestProducts.MemTable := FDMemTableProducts;
  RESTRequestProducts.SyncMode := TTina4RestSyncMode.Clear;

  // One call does everything
  RESTRequestProducts.ExecuteRESTCall;
  // FDMemTableProducts is now populated
  // Bind it to a grid with DataSourceProducts
end;
```

### With Periodic Refresh

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  // ... setup as above ...

  // Refresh every 30 seconds
  Timer1.Interval := 30000;
  Timer1.OnTimer := procedure(Sender: TObject)
  begin
    RESTRequestProducts.SyncMode := TTina4RestSyncMode.Sync;
    RESTRequestProducts.ExecuteRESTCallAsync;
  end;
  Timer1.Enabled := True;
end;
```

Using `Sync` mode on refresh preserves the user's scroll position and selection, since existing records are updated in place rather than cleared and reloaded.

---

## 3. Pattern 2: REST to JSON Adapter to Multiple MemTables

When a single API response contains multiple datasets, use TTina4JSONAdapter to fan them out.

```
REST API -> TTina4RESTRequest -> TTina4JSONAdapter (categories)
                              -> TTina4JSONAdapter (tags)
                              -> TTina4JSONAdapter (stats)
```

### Scenario

Your API returns a dashboard payload:

```json
{
  "categories": [{"id": "1", "name": "Electronics"}, ...],
  "recentOrders": [{"id": "101", "total": "59.99"}, ...],
  "stats": {"totalProducts": 150, "totalOrders": 42, "revenue": 12500}
}
```

### Implementation

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  Tina4REST1.BaseUrl := 'https://api.example.com/v1';

  // Main request fetches the dashboard payload
  RESTRequestDashboard.Tina4REST := Tina4REST1;
  RESTRequestDashboard.EndPoint := '/dashboard';
  RESTRequestDashboard.RequestType := TTina4RequestType.Get;
  RESTRequestDashboard.DataKey := '';  // We handle the keys in adapters
  RESTRequestDashboard.MemTable := FDMemTableRaw;

  // Adapter 1: Categories
  JSONAdapterCategories.MasterSource := RESTRequestDashboard;
  JSONAdapterCategories.DataKey := 'categories';
  JSONAdapterCategories.MemTable := FDMemTableCategories;

  // Adapter 2: Recent Orders
  JSONAdapterOrders.MasterSource := RESTRequestDashboard;
  JSONAdapterOrders.DataKey := 'recentOrders';
  JSONAdapterOrders.MemTable := FDMemTableOrders;

  // When the dashboard request completes, all adapters auto-execute
  RESTRequestDashboard.ExecuteRESTCall;

  // FDMemTableCategories and FDMemTableOrders are now populated
end;
```

The key insight: set `MasterSource` on each adapter to the same `TTina4RESTRequest`. When that request completes, all adapters fire automatically.

---

## 4. Pattern 3: HTML Render + Twig + REST Data

Rich UI rendering by combining API data with Twig templates.

```
REST API -> TJSONObject -> SetTwigVariable -> TTina4HTMLRender.Twig
```

### Implementation

```pascal
procedure TForm1.ShowProductCard(const AProductID: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := Tina4REST1.Get(StatusCode, '/products/' + AProductID);
  try
    if (StatusCode <> 200) or not Assigned(Response) then Exit;

    // Pass each field as a Twig variable
    HTMLRender1.SetTwigVariable('name', Response.GetValue<String>('name', ''));
    HTMLRender1.SetTwigVariable('price', Response.GetValue<String>('price', '0'));
    HTMLRender1.SetTwigVariable('description', Response.GetValue<String>('description', ''));
    HTMLRender1.SetTwigVariable('imageUrl', Response.GetValue<String>('imageUrl', ''));
    HTMLRender1.SetTwigVariable('stock', Response.GetValue<String>('stock', '0'));
    HTMLRender1.SetTwigVariable('category', Response.GetValue<String>('category', ''));

    // Load the template -- Twig renders, HTMLRender displays
    HTMLRender1.Twig.LoadFromFile('C:\MyApp\templates\product-card.html');
  finally
    Response.Free;
  end;
end;
```

### The Template (product-card.html)

```html
<div style="font-family: Arial, sans-serif; padding: 20px;">
  <div style="display: flex; gap: 20px;">
    {% if imageUrl %}
      <img src="{{ imageUrl }}" style="width: 200px; height: 200px; object-fit: cover; border-radius: 8px;">
    {% endif %}
    <div>
      <h2 style="color: #2c3e50; margin: 0 0 10px;">{{ name }}</h2>
      <p style="color: #1abc9c; font-size: 1.4em; font-weight: bold;">
        {{ price|format_currency('USD') }}
      </p>
      <p style="color: #666;">{{ category|title }}</p>
      <p>
        {% if stock|number_format > 10 %}
          <span style="color: #27ae60;">In Stock ({{ stock }})</span>
        {% elseif stock|number_format > 0 %}
          <span style="color: #f39c12;">Low Stock ({{ stock }} left)</span>
        {% else %}
          <span style="color: #e74c3c;">Out of Stock</span>
        {% endif %}
      </p>
    </div>
  </div>
  <div style="margin-top: 15px; padding: 15px; background: #f9f9f9; border-radius: 4px;">
    <p>{{ description|nl2br }}</p>
  </div>
</div>
```

---

## 5. Pattern 4: Master-Detail Chains

Linked data views where selecting a record in one view loads related data in another.

```
Customers -> Orders -> Order Items
(MemTable1)  (MemTable2)  (MemTable3)
```

### Implementation

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  Tina4REST1.BaseUrl := 'https://api.example.com/v1';

  // Level 1: Customers
  RESTRequestCustomers.Tina4REST := Tina4REST1;
  RESTRequestCustomers.EndPoint := '/customers';
  RESTRequestCustomers.DataKey := 'records';
  RESTRequestCustomers.MemTable := FDMemTableCustomers;

  // Level 2: Orders for selected customer
  RESTRequestOrders.Tina4REST := Tina4REST1;
  RESTRequestOrders.MasterSource := RESTRequestCustomers;
  RESTRequestOrders.EndPoint := '/customers/{id}/orders';
  RESTRequestOrders.DataKey := 'records';
  RESTRequestOrders.MemTable := FDMemTableOrders;

  // Level 3: Items for selected order
  RESTRequestItems.Tina4REST := Tina4REST1;
  RESTRequestItems.MasterSource := RESTRequestOrders;
  RESTRequestItems.EndPoint := '/orders/{id}/items';
  RESTRequestItems.DataKey := 'records';
  RESTRequestItems.MemTable := FDMemTableItems;

  // Load customers -- orders and items auto-load on selection change
  RESTRequestCustomers.ExecuteRESTCall;
end;
```

The `{id}` placeholder in the endpoint is replaced with the `id` field from the master's current MemTable record. When the user selects a different customer, the orders request fires automatically with the new customer ID. When they select a different order, the items request fires with the new order ID.

### Displaying the Chain

```pascal
// Grid1 shows customers (bound to FDMemTableCustomers)
// Grid2 shows orders for selected customer (bound to FDMemTableOrders)
// HTMLRender1 shows order items in a formatted table

procedure TForm1.GridOrdersCellClick(const Column: TColumn; const Row: Integer);
begin
  FDMemTableOrders.First;
  FDMemTableOrders.MoveBy(Row);
  // RESTRequestItems fires automatically via MasterSource
  // Update the HTML display
  RenderOrderItems;
end;

procedure TForm1.RenderOrderItems;
var
  HTML: TStringBuilder;
begin
  HTML := TStringBuilder.Create;
  try
    HTML.AppendLine('<table style="width: 100%; border-collapse: collapse;">');
    HTML.AppendLine('<tr style="background: #2c3e50; color: white;">');
    HTML.AppendLine('<th style="padding: 8px;">Product</th>');
    HTML.AppendLine('<th style="padding: 8px; text-align: right;">Qty</th>');
    HTML.AppendLine('<th style="padding: 8px; text-align: right;">Price</th>');
    HTML.AppendLine('</tr>');

    FDMemTableItems.First;
    while not FDMemTableItems.Eof do
    begin
      HTML.AppendFormat(
        '<tr><td style="padding: 8px;">%s</td>' +
        '<td style="padding: 8px; text-align: right;">%s</td>' +
        '<td style="padding: 8px; text-align: right;">$%s</td></tr>',
        [FDMemTableItems.FieldByName('product_name').AsString,
         FDMemTableItems.FieldByName('quantity').AsString,
         FDMemTableItems.FieldByName('unit_price').AsString]);
      FDMemTableItems.Next;
    end;

    HTML.AppendLine('</table>');
    HTMLRender1.HTML.Text := HTML.ToString;
  finally
    HTML.Free;
  end;
end;
```

---

## 6. Pattern 5: Two-Way Sync

Read data from the API, let the user edit it locally, then push changes back.

```
GET /items -> MemTable (user edits) -> POST/PATCH /items
```

### Implementation

```pascal
procedure TForm1.LoadData;
begin
  RESTRequestItems.EndPoint := '/items';
  RESTRequestItems.RequestType := TTina4RequestType.Get;
  RESTRequestItems.DataKey := 'records';
  RESTRequestItems.MemTable := FDMemTableItems;
  RESTRequestItems.ExecuteRESTCall;
end;

procedure TForm1.SaveChanges;
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  // Iterate changed records and push them back
  FDMemTableItems.First;
  while not FDMemTableItems.Eof do
  begin
    var ItemID := FDMemTableItems.FieldByName('id').AsString;
    var ItemJSON := TJSONObject.Create;
    try
      // Build JSON from current MemTable row
      for var I := 0 to FDMemTableItems.FieldCount - 1 do
      begin
        var Field := FDMemTableItems.Fields[I];
        var FieldName := CamelCase(Field.FieldName);
        ItemJSON.AddPair(FieldName, Field.AsString);
      end;

      if ItemID.IsEmpty then
      begin
        // New record -- POST
        Response := Tina4REST1.Post(StatusCode, '/items', '', ItemJSON.ToString);
        Response.Free;
      end
      else
      begin
        // Existing record -- PATCH
        Response := Tina4REST1.Patch(StatusCode, '/items/' + ItemID, '', ItemJSON.ToString);
        Response.Free;
      end;
    finally
      ItemJSON.Free;
    end;

    FDMemTableItems.Next;
  end;
end;
```

### Using SourceMemTable for Bulk POST

For simpler cases, use the `SourceMemTable` property to POST all rows at once:

```pascal
procedure TForm1.BulkUpload;
begin
  RESTRequestImport.Tina4REST := Tina4REST1;
  RESTRequestImport.RequestType := TTina4RequestType.Post;
  RESTRequestImport.EndPoint := '/items/import';
  RESTRequestImport.SourceMemTable := FDMemTableItems;
  RESTRequestImport.SourceIgnoreFields := 'internal_flag,temp_id';
  RESTRequestImport.SourceIgnoreBlanks := True;
  RESTRequestImport.ExecuteRESTCall;
end;
```

---

## 7. Pattern 6: HTML Pages + REST

Each page in a TTina4HTMLPages collection loads its own data when navigated to.

```
HTMLPages
  Page "dashboard" -> OnAfterNavigate -> fetch /dashboard data
  Page "products"  -> OnAfterNavigate -> fetch /products data
  Page "settings"  -> OnAfterNavigate -> fetch /settings data
```

### Implementation

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  Tina4REST1.BaseUrl := 'https://api.example.com/v1';
  HTMLPages1.Renderer := HTMLRender1;
  HTMLPages1.TwigTemplatePath := ExtractFilePath(ParamStr(0)) + 'templates';

  // Define pages
  var PageDash := HTMLPages1.Pages.Add;
  PageDash.PageName := 'dashboard';
  PageDash.IsDefault := True;
  PageDash.TwigContent.Text := '{% include "pages/dashboard.html" %}';

  var PageProducts := HTMLPages1.Pages.Add;
  PageProducts.PageName := 'products';
  PageProducts.TwigContent.Text := '{% include "pages/products.html" %}';

  var PageSettings := HTMLPages1.Pages.Add;
  PageSettings.PageName := 'settings';
  PageSettings.TwigContent.Text := '{% include "pages/settings.html" %}';

  // Load data when pages change
  HTMLPages1.OnAfterNavigate := HandlePageNavigate;
end;

procedure TForm1.HandlePageNavigate(Sender: TObject);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  var PageName := HTMLPages1.ActivePage;

  if PageName = 'dashboard' then
  begin
    Response := Tina4REST1.Get(StatusCode, '/dashboard/stats');
    try
      if Assigned(Response) then
      begin
        HTMLPages1.SetTwigVariable('totalUsers',
          Response.GetValue<String>('totalUsers', '0'));
        HTMLPages1.SetTwigVariable('totalOrders',
          Response.GetValue<String>('totalOrders', '0'));
        HTMLPages1.SetTwigVariable('revenue',
          Response.GetValue<String>('revenue', '0'));
      end;
    finally
      Response.Free;
    end;
    // Re-render the current page with new data
    HTMLPages1.NavigateTo('dashboard');
  end
  else if PageName = 'products' then
  begin
    Response := Tina4REST1.Get(StatusCode, '/products', 'limit=50');
    try
      if Assigned(Response) then
        HTMLPages1.SetTwigVariable('products', Response.ToString);
    finally
      Response.Free;
    end;
    HTMLPages1.NavigateTo('products');
  end;
end;
```

### Navigation Template

```html
<!-- templates/nav.html -->
<nav style="background: #2c3e50; padding: 10px;">
  <a href="#dashboard" style="color: white; margin-right: 15px;">Dashboard</a>
  <a href="#products" style="color: white; margin-right: 15px;">Products</a>
  <a href="#settings" style="color: white;">Settings</a>
</nav>
```

---

## 8. Pattern 7: WebSocket + HTML Render

Real-time data pushed from a WebSocket updates the HTML display immediately.

```
WebSocket -> OnMessage -> Update Twig variables -> Re-render HTML
```

### Implementation

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  WebSocket1.URL := 'wss://api.example.com/ws/updates';
  WebSocket1.AutoReconnect := True;
  WebSocket1.OnMessage := HandleWSUpdate;
  WebSocket1.Connect;

  // Initial render
  RenderStatusPanel;
end;

procedure TForm1.HandleWSUpdate(Sender: TObject; const AMessage: string);
begin
  TThread.Synchronize(nil, procedure
  var
    JSON: TJSONObject;
  begin
    JSON := StrToJSONObject(AMessage);
    if not Assigned(JSON) then Exit;
    try
      var UpdateType := JSON.GetValue<String>('type', '');

      if UpdateType = 'metric' then
      begin
        var MetricName := JSON.GetValue<String>('name', '');
        var MetricValue := JSON.GetValue<String>('value', '');

        // Update the specific Twig variable
        HTMLRender1.SetTwigVariable(MetricName, MetricValue);

        // Re-render the template with updated data
        HTMLRender1.Twig.LoadFromFile(
          ExtractFilePath(ParamStr(0)) + 'templates\status-panel.html');
      end
      else if UpdateType = 'alert' then
      begin
        var AlertMsg := JSON.GetValue<String>('message', '');
        ShowNotification(AlertMsg);
      end;
    finally
      JSON.Free;
    end;
  end);
end;

procedure TForm1.RenderStatusPanel;
begin
  // Set initial values
  HTMLRender1.SetTwigVariable('cpuUsage', '0');
  HTMLRender1.SetTwigVariable('memoryUsage', '0');
  HTMLRender1.SetTwigVariable('diskUsage', '0');
  HTMLRender1.SetTwigVariable('activeUsers', '0');
  HTMLRender1.SetTwigVariable('requestsPerSec', '0');

  HTMLRender1.Twig.LoadFromFile(
    ExtractFilePath(ParamStr(0)) + 'templates\status-panel.html');
end;
```

### Status Panel Template

```html
<div style="font-family: Arial, sans-serif; padding: 15px;">
  <h2 style="color: #2c3e50;">System Status</h2>

  <div style="display: flex; gap: 15px; flex-wrap: wrap;">
    {% macro metric(label, value, unit, color) %}
      <div style="flex: 1; min-width: 150px; background: white; padding: 15px;
                  border-radius: 8px; border-left: 4px solid {{ color }};">
        <p style="color: #999; margin: 0; font-size: 0.85em;">{{ label }}</p>
        <p style="color: {{ color }}; font-size: 1.8em; font-weight: bold; margin: 5px 0;">
          {{ value }}{{ unit }}
        </p>
      </div>
    {% endmacro %}

    {{ metric('CPU Usage', cpuUsage, '%', '#3498db') }}
    {{ metric('Memory', memoryUsage, '%', '#2ecc71') }}
    {{ metric('Disk', diskUsage, '%', '#e67e22') }}
    {{ metric('Active Users', activeUsers, '', '#9b59b6') }}
    {{ metric('Requests/s', requestsPerSec, '', '#1abc9c') }}
  </div>
</div>
```

---

## 9. Complete Example: Product Management Dashboard

This brings every pattern together into a single application.

### Architecture

```
Left Sidebar:   HTMLPages navigation (categories from API)
Main Area:      StringGrid (products filtered by category)
Detail Panel:   HTMLRender + Twig (product card with image)
Edit Form:      HTMLRender (HTML form -> POST/PATCH)
Live Updates:   WebSocket (product changes from other users)
```

### Form Components

| Component | Name | Purpose |
|---|---|---|
| TTina4REST | REST1 | Base configuration |
| TTina4RESTRequest | RESTCategories | Fetch categories |
| TTina4RESTRequest | RESTProducts | Fetch products by category |
| TTina4WebSocketClient | WebSocket1 | Live product updates |
| TTina4HTMLPages | HTMLPagesNav | Sidebar navigation |
| TTina4HTMLRender | HTMLRenderNav | Sidebar renderer |
| TTina4HTMLRender | HTMLRenderDetail | Product detail / edit form |
| TFDMemTable | MemTableCategories | Categories data |
| TFDMemTable | MemTableProducts | Products data |
| TStringGrid | GridProducts | Product list |

### Implementation

```pascal
unit DashboardForm;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Layouts, FMX.Grid, FMX.Grid.Style, FMX.ScrollBox,
  FMX.Dialogs,
  FireDAC.Comp.Client,
  Data.DB,
  Tina4REST, Tina4RESTRequest, Tina4HTMLRender, Tina4HTMLPages,
  Tina4WebSocket, Tina4Core;

type
  TFormDashboard = class(TForm)
    LayoutMain: TLayout;
    LayoutSidebar: TLayout;
    LayoutCenter: TLayout;
    LayoutDetail: TLayout;
    SplitterLeft: TSplitter;
    SplitterRight: TSplitter;

    REST1: TTina4REST;
    RESTCategories: TTina4RESTRequest;
    RESTProducts: TTina4RESTRequest;
    WebSocket1: TTina4WebSocketClient;

    HTMLRenderNav: TTina4HTMLRender;
    HTMLPagesNav: TTina4HTMLPages;
    HTMLRenderDetail: TTina4HTMLRender;

    MemTableCategories: TFDMemTable;
    MemTableProducts: TFDMemTable;
    GridProducts: TStringGrid;
    LabelStatus: TLabel;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FCurrentCategory: string;
    FCurrentProductID: string;

    procedure SetupREST;
    procedure SetupNavigation;
    procedure SetupGrid;
    procedure SetupWebSocket;

    procedure LoadCategories;
    procedure LoadProducts(const ACategoryID: string);
    procedure ShowProductDetail(const AProductID: string);
    procedure ShowEditForm(const AProductID: string);

    procedure OnWSMessage(Sender: TObject; const AMessage: string);
    procedure OnWSOpen(Sender: TObject);
    procedure GridCellClick(const Column: TColumn; const Row: Integer);
    procedure HandleFormSubmit(Sender: TObject;
      const FormName: string; FormData: TStrings);

    procedure SetStatus(const AMessage: string);
    procedure PopulateGrid;
  public
    procedure SelectCategory(const ACategoryID: string);
    procedure EditProduct(const AProductID: string);
    procedure DeleteProduct(const AProductID: string);
  end;

var
  FormDashboard: TFormDashboard;

implementation

{$R *.fmx}

procedure TFormDashboard.FormCreate(Sender: TObject);
begin
  SetupREST;
  SetupNavigation;
  SetupGrid;
  SetupWebSocket;

  LoadCategories;
  SetStatus('Ready');
end;

procedure TFormDashboard.FormDestroy(Sender: TObject);
begin
  WebSocket1.AutoReconnect := False;
  if WebSocket1.Connected then
    WebSocket1.Disconnect;
end;

// ---- REST Setup ----

procedure TFormDashboard.SetupREST;
begin
  REST1.BaseUrl := 'https://api.example.com/v1';
  // REST1.SetBearer('your-token');

  RESTCategories.Tina4REST := REST1;
  RESTCategories.EndPoint := '/categories';
  RESTCategories.RequestType := TTina4RequestType.Get;
  RESTCategories.DataKey := 'records';
  RESTCategories.MemTable := MemTableCategories;

  RESTProducts.Tina4REST := REST1;
  RESTProducts.RequestType := TTina4RequestType.Get;
  RESTProducts.DataKey := 'records';
  RESTProducts.MemTable := MemTableProducts;
end;

// ---- Sidebar Navigation ----

procedure TFormDashboard.SetupNavigation;
begin
  HTMLPagesNav.Renderer := HTMLRenderNav;
  HTMLPagesNav.TwigTemplatePath := ExtractFilePath(ParamStr(0)) + 'templates';
  HTMLRenderNav.RegisterObject('App', Self);
end;

procedure TFormDashboard.LoadCategories;
begin
  SetStatus('Loading categories...');

  RESTCategories.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    var
      HTML: TStringBuilder;
    begin
      // Build the sidebar navigation from category data
      HTML := TStringBuilder.Create;
      try
        HTML.AppendLine('<div style="font-family: Arial, sans-serif; padding: 10px;">');
        HTML.AppendLine('<h3 style="color: #2c3e50; padding: 0 10px;">Categories</h3>');

        MemTableCategories.First;
        while not MemTableCategories.Eof do
        begin
          var CatID := MemTableCategories.FieldByName('id').AsString;
          var CatName := MemTableCategories.FieldByName('name').AsString;
          var IsActive := (CatID = FCurrentCategory);

          HTML.AppendFormat(
            '<div onclick="App:SelectCategory(''%s'')" ' +
            '     style="padding: 10px 15px; cursor: pointer; border-radius: 4px; ' +
            '     margin: 2px 5px; background: %s; color: %s;">' +
            '  %s' +
            '</div>',
            [CatID,
             IfThen(IsActive, '#1abc9c', 'transparent'),
             IfThen(IsActive, 'white', '#333'),
             CatName]);

          MemTableCategories.Next;
        end;

        HTML.AppendLine('</div>');
        HTMLRenderNav.HTML.Text := HTML.ToString;
      finally
        HTML.Free;
      end;

      // Auto-select first category
      if (FCurrentCategory.IsEmpty) and (MemTableCategories.RecordCount > 0) then
      begin
        MemTableCategories.First;
        SelectCategory(MemTableCategories.FieldByName('id').AsString);
      end;

      SetStatus(Format('Loaded %d categories', [MemTableCategories.RecordCount]));
    end);
  end;

  RESTCategories.ExecuteRESTCallAsync;
end;

procedure TFormDashboard.SelectCategory(const ACategoryID: string);
begin
  FCurrentCategory := ACategoryID;
  LoadProducts(ACategoryID);
  // Refresh sidebar to show active state
  LoadCategories;
end;

// ---- Product Grid ----

procedure TFormDashboard.SetupGrid;
begin
  GridProducts.ColumnCount := 4;
  GridProducts.Columns[0].Header := 'Product';
  GridProducts.Columns[0].Width := 180;
  GridProducts.Columns[1].Header := 'Price';
  GridProducts.Columns[1].Width := 80;
  GridProducts.Columns[2].Header := 'Stock';
  GridProducts.Columns[2].Width := 60;
  GridProducts.Columns[3].Header := 'Status';
  GridProducts.Columns[3].Width := 80;
  GridProducts.OnCellClick := GridCellClick;
end;

procedure TFormDashboard.LoadProducts(const ACategoryID: string);
begin
  SetStatus('Loading products...');

  RESTProducts.EndPoint := '/categories/' + ACategoryID + '/products';

  RESTProducts.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      PopulateGrid;
      SetStatus(Format('Loaded %d products', [MemTableProducts.RecordCount]));
    end);
  end;

  RESTProducts.ExecuteRESTCallAsync;
end;

procedure TFormDashboard.PopulateGrid;
begin
  GridProducts.RowCount := MemTableProducts.RecordCount;
  MemTableProducts.First;
  var Row := 0;

  while not MemTableProducts.Eof do
  begin
    GridProducts.Cells[0, Row] := MemTableProducts.FieldByName('name').AsString;
    GridProducts.Cells[1, Row] := '$' + MemTableProducts.FieldByName('price').AsString;

    var Stock := MemTableProducts.FieldByName('stock').AsInteger;
    GridProducts.Cells[2, Row] := Stock.ToString;

    if Stock > 10 then
      GridProducts.Cells[3, Row] := 'In Stock'
    else if Stock > 0 then
      GridProducts.Cells[3, Row] := 'Low'
    else
      GridProducts.Cells[3, Row] := 'Out';

    MemTableProducts.Next;
    Inc(Row);
  end;
end;

procedure TFormDashboard.GridCellClick(const Column: TColumn; const Row: Integer);
begin
  MemTableProducts.First;
  MemTableProducts.MoveBy(Row);
  var ProductID := MemTableProducts.FieldByName('id').AsString;
  ShowProductDetail(ProductID);
end;

// ---- Product Detail ----

procedure TFormDashboard.ShowProductDetail(const AProductID: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  FCurrentProductID := AProductID;
  SetStatus('Loading product...');

  Response := REST1.Get(StatusCode, '/products/' + AProductID);
  try
    if (StatusCode <> 200) or not Assigned(Response) then
    begin
      SetStatus('Error loading product');
      Exit;
    end;

    HTMLRenderDetail.SetTwigVariable('id', Response.GetValue<String>('id', ''));
    HTMLRenderDetail.SetTwigVariable('name', Response.GetValue<String>('name', ''));
    HTMLRenderDetail.SetTwigVariable('price', Response.GetValue<String>('price', '0'));
    HTMLRenderDetail.SetTwigVariable('description', Response.GetValue<String>('description', ''));
    HTMLRenderDetail.SetTwigVariable('imageUrl', Response.GetValue<String>('imageUrl', ''));
    HTMLRenderDetail.SetTwigVariable('stock', Response.GetValue<String>('stock', '0'));
    HTMLRenderDetail.SetTwigVariable('category', Response.GetValue<String>('category', ''));
    HTMLRenderDetail.SetTwigVariable('sku', Response.GetValue<String>('sku', ''));

    HTMLRenderDetail.Twig.LoadFromFile(
      ExtractFilePath(ParamStr(0)) + 'templates\product-detail.html');

    SetStatus('Viewing: ' + Response.GetValue<String>('name', ''));
  finally
    Response.Free;
  end;
end;

// ---- Edit Form ----

procedure TFormDashboard.EditProduct(const AProductID: string);
begin
  ShowEditForm(AProductID);
end;

procedure TFormDashboard.ShowEditForm(const AProductID: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := REST1.Get(StatusCode, '/products/' + AProductID);
  try
    if (StatusCode = 200) and Assigned(Response) then
    begin
      HTMLRenderDetail.SetTwigVariable('id', Response.GetValue<String>('id', ''));
      HTMLRenderDetail.SetTwigVariable('name', Response.GetValue<String>('name', ''));
      HTMLRenderDetail.SetTwigVariable('price', Response.GetValue<String>('price', ''));
      HTMLRenderDetail.SetTwigVariable('description', Response.GetValue<String>('description', ''));
      HTMLRenderDetail.SetTwigVariable('stock', Response.GetValue<String>('stock', ''));
      HTMLRenderDetail.SetTwigVariable('sku', Response.GetValue<String>('sku', ''));

      HTMLRenderDetail.Twig.LoadFromFile(
        ExtractFilePath(ParamStr(0)) + 'templates\product-form.html');

      SetStatus('Editing: ' + Response.GetValue<String>('name', ''));
    end;
  finally
    Response.Free;
  end;
end;

procedure TFormDashboard.HandleFormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
var
  StatusCode: Integer;
  Response: TJSONObject;
  Body: TJSONObject;
begin
  if FormName <> 'productForm' then Exit;

  var ProductID := FormData.Values['id'];
  Body := TJSONObject.Create;
  try
    Body.AddPair('name', FormData.Values['name'].Trim);
    Body.AddPair('price', TJSONNumber.Create(StrToFloatDef(FormData.Values['price'], 0)));
    Body.AddPair('description', FormData.Values['description'].Trim);
    Body.AddPair('stock', TJSONNumber.Create(StrToIntDef(FormData.Values['stock'], 0)));
    Body.AddPair('sku', FormData.Values['sku'].Trim);

    if ProductID.IsEmpty then
      Response := REST1.Post(StatusCode, '/products', '', Body.ToString)
    else
      Response := REST1.Patch(StatusCode, '/products/' + ProductID, '', Body.ToString);
  finally
    Body.Free;
  end;

  try
    if StatusCode in [200, 201] then
    begin
      SetStatus('Product saved');
      LoadProducts(FCurrentCategory);
      if Assigned(Response) then
        ShowProductDetail(Response.GetValue<String>('id', ProductID));
    end
    else
    begin
      SetStatus('Save failed');
      ShowMessage('Could not save product');
    end;
  finally
    Response.Free;
  end;
end;

procedure TFormDashboard.DeleteProduct(const AProductID: string);
begin
  MessageDlg('Delete this product?', TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0,
    procedure(const AResult: TModalResult)
    var
      StatusCode: Integer;
      Response: TJSONObject;
    begin
      if AResult <> mrYes then Exit;

      Response := REST1.Delete(StatusCode, '/products/' + AProductID);
      try
        if StatusCode in [200, 204] then
        begin
          SetStatus('Product deleted');
          LoadProducts(FCurrentCategory);
          HTMLRenderDetail.HTML.Text :=
            '<p style="padding: 40px; text-align: center; color: #999;">Select a product</p>';
        end;
      finally
        Response.Free;
      end;
    end);
end;

// ---- WebSocket Live Updates ----

procedure TFormDashboard.SetupWebSocket;
begin
  WebSocket1.URL := 'wss://api.example.com/ws/products';
  WebSocket1.AutoReconnect := True;
  WebSocket1.ReconnectInterval := 5000;
  WebSocket1.PingInterval := 30000;
  WebSocket1.OnOpen := OnWSOpen;
  WebSocket1.OnMessage := OnWSMessage;
  WebSocket1.Connect;
end;

procedure TFormDashboard.OnWSOpen(Sender: TObject);
begin
  TThread.Synchronize(nil, procedure
  begin
    // Subscribe to product updates
    var Sub := TJSONObject.Create;
    try
      Sub.AddPair('type', 'subscribe');
      Sub.AddPair('channel', 'products');
      WebSocket1.Send(Sub.ToString);
    finally
      Sub.Free;
    end;
  end);
end;

procedure TFormDashboard.OnWSMessage(Sender: TObject; const AMessage: string);
begin
  TThread.Synchronize(nil, procedure
  var
    JSON: TJSONObject;
  begin
    JSON := StrToJSONObject(AMessage);
    if not Assigned(JSON) then Exit;
    try
      var MsgType := JSON.GetValue<String>('type', '');

      if MsgType = 'product_updated' then
      begin
        var ProductID := JSON.GetValue<String>('productId', '');
        var CategoryID := JSON.GetValue<String>('categoryId', '');

        // Refresh the grid if we are viewing the affected category
        if CategoryID = FCurrentCategory then
        begin
          LoadProducts(FCurrentCategory);
          SetStatus('Product updated by another user');
        end;

        // Refresh detail if viewing the affected product
        if ProductID = FCurrentProductID then
          ShowProductDetail(ProductID);
      end
      else if MsgType = 'product_deleted' then
      begin
        var CategoryID := JSON.GetValue<String>('categoryId', '');
        if CategoryID = FCurrentCategory then
        begin
          LoadProducts(FCurrentCategory);
          SetStatus('Product deleted by another user');
        end;
      end;
    finally
      JSON.Free;
    end;
  end);
end;

// ---- Utilities ----

procedure TFormDashboard.SetStatus(const AMessage: string);
begin
  LabelStatus.Text := FormatDateTime('hh:nn:ss', Now) + '  ' + AMessage;
end;

end.
```

### Template Files

**templates/product-detail.html:**

```html
<div style="font-family: Arial, sans-serif; padding: 20px;">
  <div style="display: flex; justify-content: space-between; align-items: center;">
    <h2 style="color: #2c3e50; margin: 0;">{{ name }}</h2>
    <div>
      <button onclick="App:EditProduct('{{ id }}')"
              style="background: #3498db; color: white; border: none; padding: 8px 16px;
                     border-radius: 4px; margin-right: 5px; cursor: pointer;">Edit</button>
      <button onclick="App:DeleteProduct('{{ id }}')"
              style="background: #e74c3c; color: white; border: none; padding: 8px 16px;
                     border-radius: 4px; cursor: pointer;">Delete</button>
    </div>
  </div>

  <div style="display: flex; gap: 20px; margin-top: 20px;">
    {% if imageUrl %}
      <img src="{{ imageUrl }}" style="width: 250px; height: 250px; object-fit: cover; border-radius: 8px;">
    {% else %}
      <div style="width: 250px; height: 250px; background: #ecf0f1; border-radius: 8px;
                  display: flex; align-items: center; justify-content: center; color: #bdc3c7;">
        No Image
      </div>
    {% endif %}

    <div style="flex: 1;">
      <p style="font-size: 1.4em; color: #1abc9c; font-weight: bold;">
        {{ price|format_currency('USD') }}
      </p>
      <table style="width: 100%;">
        <tr>
          <td style="padding: 6px 0; color: #999; width: 80px;">SKU</td>
          <td style="padding: 6px 0;">{{ sku|upper }}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #999;">Category</td>
          <td style="padding: 6px 0;">{{ category|title }}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #999;">Stock</td>
          <td style="padding: 6px 0;">
            {% if stock > 10 %}
              <span style="color: #27ae60;">In Stock ({{ stock }})</span>
            {% elseif stock > 0 %}
              <span style="color: #f39c12;">Low Stock ({{ stock }})</span>
            {% else %}
              <span style="color: #e74c3c;">Out of Stock</span>
            {% endif %}
          </td>
        </tr>
      </table>
    </div>
  </div>

  {% if description %}
    <div style="margin-top: 20px; padding: 15px; background: #f9f9f9; border-radius: 4px;">
      <h3 style="margin: 0 0 10px; color: #2c3e50;">Description</h3>
      <p>{{ description|nl2br }}</p>
    </div>
  {% endif %}
</div>
```

**templates/product-form.html:**

```html
<div style="font-family: Arial, sans-serif; padding: 20px;">
  <h2 style="color: #2c3e50;">{% if id %}Edit Product{% else %}New Product{% endif %}</h2>

  <form name="productForm">
    {% if id %}<input type="hidden" name="id" value="{{ id }}">{% endif %}

    <div style="margin-bottom: 12px;">
      <label style="display: block; color: #666; margin-bottom: 4px;">Name *</label>
      <input type="text" name="name" value="{{ name|default('') }}"
             style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
    </div>

    <div style="display: flex; gap: 15px; margin-bottom: 12px;">
      <div style="flex: 1;">
        <label style="display: block; color: #666; margin-bottom: 4px;">Price *</label>
        <input type="text" name="price" value="{{ price|default('') }}"
               style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
      </div>
      <div style="flex: 1;">
        <label style="display: block; color: #666; margin-bottom: 4px;">Stock</label>
        <input type="text" name="stock" value="{{ stock|default('0') }}"
               style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
      </div>
      <div style="flex: 1;">
        <label style="display: block; color: #666; margin-bottom: 4px;">SKU</label>
        <input type="text" name="sku" value="{{ sku|default('') }}"
               style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
      </div>
    </div>

    <div style="margin-bottom: 15px;">
      <label style="display: block; color: #666; margin-bottom: 4px;">Description</label>
      <textarea name="description" rows="5"
                style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">{{ description|default('') }}</textarea>
    </div>

    <div style="display: flex; gap: 10px;">
      <button type="submit"
              style="background: #1abc9c; color: white; border: none; padding: 10px 24px;
                     border-radius: 4px; cursor: pointer;">Save</button>
      <button type="button" onclick="App:ShowProductDetail('{{ id }}')"
              style="background: #95a5a6; color: white; border: none; padding: 10px 24px;
                     border-radius: 4px; cursor: pointer;">Cancel</button>
    </div>
  </form>
</div>
```

---

## 10. Integration with Tina4 Backend

The Delphi components are framework-agnostic -- they work with any REST API. But they are designed to pair naturally with Tina4 backends.

### Tina4 Python Backend

```python
from tina4_python import get, post, patch, delete

@get("/api/products")
async def get_products(request, response):
    products = DBI.fetch("SELECT * FROM products")
    return response(products)

@post("/api/products")
async def create_product(request, response):
    product = request.body
    DBI.insert("products", product)
    return response(product, 201)
```

### Tina4 PHP Backend

```php
\Tina4\Get::add("/api/products", function(\Tina4\Response $response) {
    return $response((new Product())->select("*")->asArray());
});

\Tina4\Post::add("/api/products", function(\Tina4\Response $response, \Tina4\Request $request) {
    $product = new Product($request->data);
    $product->save();
    return $response($product, 201);
});
```

### Tina4 Node.js Backend

```javascript
Router.get("/api/products", async (req, res) => {
    const products = await DBI.fetch("SELECT * FROM products");
    res.json(products);
});

Router.post("/api/products", async (req, res) => {
    const product = await DBI.insert("products", req.body);
    res.status(201).json(product);
});
```

The `GetJSONFromDB` output format matches what Delphi's `TTina4RESTRequest` expects. The `DataKey` of `"records"` works with the default array key. Field names are automatically converted between `snake_case` (database) and `camelCase` (JSON) on both sides.

---

## Exercise: Monitoring Dashboard

**Build a monitoring dashboard** that combines all three data sources:

1. **REST polling** -- Fetch server metrics every 30 seconds from `/api/metrics`
2. **WebSocket alerts** -- Receive real-time alerts from `wss://api.example.com/ws/alerts`
3. **HTML-rendered status panels** -- Display metrics as colored cards, alerts as a scrollable list

### Requirements

- Four metric cards: CPU, Memory, Disk, Network (updated via REST polling)
- Alert list: show the last 20 alerts with timestamp, severity, and message
- Color coding: green (< 60%), yellow (60-80%), red (> 80%) for metric values
- Sound or visual flash when a critical alert arrives
- A "Clear Alerts" button

### Solution Outline

```pascal
procedure TFormMonitor.FormCreate(Sender: TObject);
begin
  // REST polling for metrics
  REST1.BaseUrl := 'https://api.example.com/v1';
  TimerMetrics.Interval := 30000;
  TimerMetrics.OnTimer := FetchMetrics;
  TimerMetrics.Enabled := True;

  // WebSocket for alerts
  WebSocket1.URL := 'wss://api.example.com/ws/alerts';
  WebSocket1.AutoReconnect := True;
  WebSocket1.OnMessage := HandleAlert;
  WebSocket1.Connect;

  // Initial fetch
  FetchMetrics(nil);
end;

procedure TFormMonitor.FetchMetrics(Sender: TObject);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := REST1.Get(StatusCode, '/api/metrics');
  try
    if (StatusCode = 200) and Assigned(Response) then
    begin
      HTMLRenderMetrics.SetTwigVariable('cpu',
        Response.GetValue<String>('cpu', '0'));
      HTMLRenderMetrics.SetTwigVariable('memory',
        Response.GetValue<String>('memory', '0'));
      HTMLRenderMetrics.SetTwigVariable('disk',
        Response.GetValue<String>('disk', '0'));
      HTMLRenderMetrics.SetTwigVariable('network',
        Response.GetValue<String>('network', '0'));

      HTMLRenderMetrics.Twig.LoadFromFile(
        ExtractFilePath(ParamStr(0)) + 'templates\metrics.html');
    end;
  finally
    Response.Free;
  end;
end;

procedure TFormMonitor.HandleAlert(Sender: TObject; const AMessage: string);
begin
  TThread.Synchronize(nil, procedure
  var
    JSON: TJSONObject;
  begin
    JSON := StrToJSONObject(AMessage);
    if not Assigned(JSON) then Exit;
    try
      var Severity := JSON.GetValue<String>('severity', 'info');
      var Message := JSON.GetValue<String>('message', '');
      var Timestamp := JSON.GetValue<String>('timestamp', GetJSONDate(Now));

      // Add to alert list (keep last 20)
      FAlerts.Insert(0, Format('%s|%s|%s', [Timestamp, Severity, Message]));
      while FAlerts.Count > 20 do
        FAlerts.Delete(FAlerts.Count - 1);

      RefreshAlertDisplay;

      // Visual flash for critical alerts
      if Severity = 'critical' then
      begin
        HTMLRenderAlerts.SetElementStyle('alertPanel', 'background-color', '#e74c3c');
        // Reset after 500ms
        TThread.CreateAnonymousThread(procedure
        begin
          Sleep(500);
          TThread.Synchronize(nil, procedure
          begin
            HTMLRenderAlerts.SetElementStyle('alertPanel', 'background-color', 'white');
          end);
        end).Start;
      end;
    finally
      JSON.Free;
    end;
  end);
end;
```

The metrics template uses the same macro pattern from Pattern 7:

```html
{% macro metricCard(label, value, unit) %}
  {% set color = '#27ae60' %}
  {% if value > 80 %}{% set color = '#e74c3c' %}
  {% elseif value > 60 %}{% set color = '#f39c12' %}{% endif %}

  <div style="flex: 1; background: white; padding: 15px; border-radius: 8px;
              border-top: 4px solid {{ color }}; text-align: center;">
    <p style="color: #999; margin: 0;">{{ label }}</p>
    <p style="color: {{ color }}; font-size: 2em; font-weight: bold; margin: 5px 0;">
      {{ value }}{{ unit }}
    </p>
  </div>
{% endmacro %}

<div style="display: flex; gap: 15px; padding: 15px;">
  {{ metricCard('CPU', cpu, '%') }}
  {{ metricCard('Memory', memory, '%') }}
  {{ metricCard('Disk', disk, '%') }}
  {{ metricCard('Network', network, ' Mbps') }}
</div>
```

This exercise combines everything: REST for periodic data, WebSocket for real-time events, Twig for templated rendering, and HTML Render for interactive display. It is the distillation of every pattern in this chapter into a single, practical application.
