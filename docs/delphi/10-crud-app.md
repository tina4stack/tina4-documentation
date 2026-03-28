# Chapter 9: Building a CRUD Application

## A Contact Manager From Scratch

No theory in this chapter. No isolated snippets. We are building a complete, working contact management application that uses every Tina4 Delphi component you have learned so far.

By the end, you will have:

- A SQLite database storing contacts
- A REST API backend (described, so you know what to build with Tina4 Python/PHP/Node.js/Ruby)
- A contact list displayed in a StringGrid
- A detail view rendered with HTML and Twig templates
- Create, update, and delete operations via HTML forms
- Search and filtering
- Loading states and error handling

Every line of code in this chapter is part of the final application. Read it top to bottom and you will have a working app.

---

## 1. What We Are Building

A contact management application with these features:

| Feature | Components Used |
|---|---|
| List all contacts | TTina4RESTRequest, FDMemTable, StringGrid |
| View contact detail | TTina4HTMLRender, TTina4Twig |
| Create new contact | TTina4HTMLRender (form), OnFormSubmit, TTina4REST.Post |
| Edit existing contact | TTina4HTMLRender (form), OnFormSubmit, TTina4REST.Patch |
| Delete contact | TTina4REST.Delete with confirmation |
| Search/filter | MemTable filtering or REST query params |
| Status messages | TTina4HTMLRender for toast-style feedback |

---

## 2. The REST API

Before building the Delphi client, here is the API it consumes. Build this with Tina4 Python, PHP, Node.js, or Ruby -- any backend that returns this JSON shape works.

### Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/contacts` | List all contacts |
| GET | `/api/contacts?search=query` | Search contacts |
| GET | `/api/contacts/{id}` | Get single contact |
| POST | `/api/contacts` | Create contact |
| PATCH | `/api/contacts/{id}` | Update contact |
| DELETE | `/api/contacts/{id}` | Delete contact |

### Response Format

**List response:**
```json
{
  "records": [
    {
      "id": "1",
      "firstName": "Andre",
      "lastName": "Van Zuydam",
      "email": "andre@example.com",
      "phone": "+27 21 555 0100",
      "company": "Tina4 Stack",
      "notes": "Framework creator",
      "createdAt": "2026-01-15T10:30:00.000Z"
    }
  ],
  "total": 42
}
```

**Single record response:**
```json
{
  "id": "1",
  "firstName": "Andre",
  "lastName": "Van Zuydam",
  "email": "andre@example.com",
  "phone": "+27 21 555 0100",
  "company": "Tina4 Stack",
  "notes": "Framework creator",
  "createdAt": "2026-01-15T10:30:00.000Z"
}
```

**Error response:**
```json
{
  "error": "Contact not found",
  "statusCode": 404
}
```

---

## 3. Project Setup

### New FMX Project

Create a new **Multi-Device Application** in Delphi. Save the project as `ContactManager.dpr` with the main form unit as `MainForm.pas`.

### Form Components

Drop these components on the form:

**Data components (non-visual):**

| Component | Name | Purpose |
|---|---|---|
| TTina4REST | Tina4REST1 | Base REST configuration |
| TTina4RESTRequest | RESTRequestList | Fetch contact list |
| TTina4RESTRequest | RESTRequestDetail | Fetch single contact |
| TFDMemTable | MemTableContacts | Contact list data |
| TDataSource | DataSourceContacts | Binds MemTable to grid |

**Visual components:**

| Component | Name | Purpose |
|---|---|---|
| TLayout | LayoutMain | Main container |
| TLayout | LayoutLeft | Left panel (list) |
| TLayout | LayoutRight | Right panel (detail/form) |
| TSplitter | Splitter1 | Resizable divider |
| TStringGrid | GridContacts | Contact list |
| TEdit | EditSearch | Search input |
| TButton | ButtonSearch | Search button |
| TButton | ButtonNew | New contact button |
| TButton | ButtonRefresh | Refresh list button |
| TTina4HTMLRender | HTMLRenderDetail | Contact detail / form display |
| TLabel | LabelStatus | Status bar |

### Layout Structure

```
Form
  LayoutMain (Align=Client)
    LayoutLeft (Align=Left, Width=400)
      EditSearch (Align=Top)
      ButtonSearch (Align=Top)
      ButtonNew (Align=Top)
      ButtonRefresh (Align=Top)
      GridContacts (Align=Client)
    Splitter1 (Align=Left)
    LayoutRight (Align=Client)
      HTMLRenderDetail (Align=Client)
    LabelStatus (Align=Bottom)
```

---

## 4. REST Configuration

```pascal
procedure TFormMain.FormCreate(Sender: TObject);
begin
  // Configure REST client
  Tina4REST1.BaseUrl := 'https://api.example.com/v1';
  // Tina4REST1.SetBearer('your-token-here');  // If auth required

  // Configure list request
  RESTRequestList.Tina4REST := Tina4REST1;
  RESTRequestList.EndPoint := '/api/contacts';
  RESTRequestList.RequestType := TTina4RequestType.Get;
  RESTRequestList.DataKey := 'records';
  RESTRequestList.MemTable := MemTableContacts;
  RESTRequestList.SyncMode := TTina4RestSyncMode.Clear;

  // Configure detail request
  RESTRequestDetail.Tina4REST := Tina4REST1;
  RESTRequestDetail.RequestType := TTina4RequestType.Get;
  RESTRequestDetail.DataKey := '';

  // Configure grid columns
  SetupGrid;

  // Configure HTML renderer
  HTMLRenderDetail.TwigTemplatePath := ExtractFilePath(ParamStr(0)) + 'templates';
  HTMLRenderDetail.OnFormSubmit := HandleFormSubmit;
  HTMLRenderDetail.OnElementClick := HandleElementClick;
  HTMLRenderDetail.RegisterObject('App', Self);

  // Load contacts
  RefreshContacts;
end;
```

---

## 5. Grid Setup

```pascal
procedure TFormMain.SetupGrid;
begin
  GridContacts.ColumnCount := 4;

  GridContacts.Columns[0].Header := 'Name';
  GridContacts.Columns[0].Width := 150;

  GridContacts.Columns[1].Header := 'Email';
  GridContacts.Columns[1].Width := 150;

  GridContacts.Columns[2].Header := 'Phone';
  GridContacts.Columns[2].Width := 100;

  GridContacts.Columns[3].Header := 'Company';
  GridContacts.Columns[3].Width := 100;

  GridContacts.OnCellClick := GridCellClick;
end;
```

---

## 6. List Contacts

### Fetching and Displaying

```pascal
procedure TFormMain.RefreshContacts;
begin
  SetStatus('Loading contacts...');

  RESTRequestList.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      PopulateGrid;
      SetStatus(Format('Loaded %d contacts', [MemTableContacts.RecordCount]));
    end);
  end;

  RESTRequestList.ExecuteRESTCallAsync;
end;

procedure TFormMain.PopulateGrid;
begin
  GridContacts.RowCount := MemTableContacts.RecordCount;

  MemTableContacts.First;
  var Row := 0;

  while not MemTableContacts.Eof do
  begin
    var FirstName := MemTableContacts.FieldByName('first_name').AsString;
    var LastName := MemTableContacts.FieldByName('last_name').AsString;

    GridContacts.Cells[0, Row] := FirstName + ' ' + LastName;
    GridContacts.Cells[1, Row] := MemTableContacts.FieldByName('email').AsString;
    GridContacts.Cells[2, Row] := MemTableContacts.FieldByName('phone').AsString;
    GridContacts.Cells[3, Row] := MemTableContacts.FieldByName('company').AsString;

    MemTableContacts.Next;
    Inc(Row);
  end;
end;

procedure TFormMain.ButtonRefreshClick(Sender: TObject);
begin
  RefreshContacts;
end;
```

---

## 7. View Contact Detail

When the user clicks a row in the grid, show the contact detail in the HTML renderer.

### Grid Click Handler

```pascal
procedure TFormMain.GridCellClick(const Column: TColumn; const Row: Integer);
begin
  // Navigate to the selected record in MemTable
  MemTableContacts.First;
  MemTableContacts.MoveBy(Row);

  var ContactID := MemTableContacts.FieldByName('id').AsString;
  ShowContactDetail(ContactID);
end;
```

### Contact Detail Template (templates/contact-detail.html)

```html
<div style="font-family: Arial, sans-serif; padding: 20px;">
  <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
    <h2 style="color: #2c3e50; margin: 0;">{{ firstName }} {{ lastName }}</h2>
    <div>
      <button onclick="App:EditContact('{{ id }}')"
              style="background: #3498db; color: white; border: none; padding: 8px 16px; border-radius: 4px; margin-right: 5px; cursor: pointer;">
        Edit
      </button>
      <button onclick="App:DeleteContact('{{ id }}')"
              style="background: #e74c3c; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer;">
        Delete
      </button>
    </div>
  </div>

  <div style="background: #f9f9f9; border-radius: 8px; padding: 20px;">
    <table style="width: 100%;">
      <tr>
        <td style="padding: 8px; color: #666; width: 120px;"><strong>Email</strong></td>
        <td style="padding: 8px;">
          {% if email %}
            <a href="mailto:{{ email }}">{{ email }}</a>
          {% else %}
            <span style="color: #ccc;">Not set</span>
          {% endif %}
        </td>
      </tr>
      <tr>
        <td style="padding: 8px; color: #666;"><strong>Phone</strong></td>
        <td style="padding: 8px;">{{ phone|default('Not set') }}</td>
      </tr>
      <tr>
        <td style="padding: 8px; color: #666;"><strong>Company</strong></td>
        <td style="padding: 8px;">{{ company|default('Not set') }}</td>
      </tr>
      <tr>
        <td style="padding: 8px; color: #666;"><strong>Notes</strong></td>
        <td style="padding: 8px;">{{ notes|default('No notes')|nl2br }}</td>
      </tr>
      <tr>
        <td style="padding: 8px; color: #666;"><strong>Created</strong></td>
        <td style="padding: 8px;">{{ createdAt|date('F j, Y') }}</td>
      </tr>
    </table>
  </div>
</div>
```

### Show Detail

```pascal
procedure TFormMain.ShowContactDetail(const AContactID: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  SetStatus('Loading contact...');

  Response := Tina4REST1.Get(StatusCode, '/api/contacts/' + AContactID);
  try
    if StatusCode <> 200 then
    begin
      SetStatus('Error loading contact: HTTP ' + StatusCode.ToString);
      Exit;
    end;

    if not Assigned(Response) then
    begin
      SetStatus('Invalid response');
      Exit;
    end;

    // Set Twig variables from the JSON response
    HTMLRenderDetail.SetTwigVariable('id', Response.GetValue<String>('id', ''));
    HTMLRenderDetail.SetTwigVariable('firstName', Response.GetValue<String>('firstName', ''));
    HTMLRenderDetail.SetTwigVariable('lastName', Response.GetValue<String>('lastName', ''));
    HTMLRenderDetail.SetTwigVariable('email', Response.GetValue<String>('email', ''));
    HTMLRenderDetail.SetTwigVariable('phone', Response.GetValue<String>('phone', ''));
    HTMLRenderDetail.SetTwigVariable('company', Response.GetValue<String>('company', ''));
    HTMLRenderDetail.SetTwigVariable('notes', Response.GetValue<String>('notes', ''));
    HTMLRenderDetail.SetTwigVariable('createdAt', Response.GetValue<String>('createdAt', ''));

    // Render the template
    HTMLRenderDetail.Twig.LoadFromFile(
      ExtractFilePath(ParamStr(0)) + 'templates\contact-detail.html');

    SetStatus('Viewing: ' + Response.GetValue<String>('firstName', '') + ' ' +
      Response.GetValue<String>('lastName', ''));
  finally
    Response.Free;
  end;
end;
```

---

## 8. Create Contact

### Contact Form Template (templates/contact-form.html)

```html
<div style="font-family: Arial, sans-serif; padding: 20px;">
  <h2 style="color: #2c3e50;">
    {% if id %}Edit Contact{% else %}New Contact{% endif %}
  </h2>

  <form name="contactForm">
    {% if id %}
      <input type="hidden" name="id" value="{{ id }}">
    {% endif %}

    <div style="margin-bottom: 15px;">
      <label style="display: block; color: #666; margin-bottom: 4px;">First Name *</label>
      <input type="text" name="firstName" value="{{ firstName|default('') }}"
             class="form-control" placeholder="Enter first name"
             style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
    </div>

    <div style="margin-bottom: 15px;">
      <label style="display: block; color: #666; margin-bottom: 4px;">Last Name *</label>
      <input type="text" name="lastName" value="{{ lastName|default('') }}"
             class="form-control" placeholder="Enter last name"
             style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
    </div>

    <div style="margin-bottom: 15px;">
      <label style="display: block; color: #666; margin-bottom: 4px;">Email</label>
      <input type="email" name="email" value="{{ email|default('') }}"
             class="form-control" placeholder="name@example.com"
             style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
    </div>

    <div style="margin-bottom: 15px;">
      <label style="display: block; color: #666; margin-bottom: 4px;">Phone</label>
      <input type="text" name="phone" value="{{ phone|default('') }}"
             class="form-control" placeholder="+27 21 555 0100"
             style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
    </div>

    <div style="margin-bottom: 15px;">
      <label style="display: block; color: #666; margin-bottom: 4px;">Company</label>
      <input type="text" name="company" value="{{ company|default('') }}"
             class="form-control" placeholder="Company name"
             style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
    </div>

    <div style="margin-bottom: 20px;">
      <label style="display: block; color: #666; margin-bottom: 4px;">Notes</label>
      <textarea name="notes" rows="4" class="form-control"
                placeholder="Additional notes..."
                style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">{{ notes|default('') }}</textarea>
    </div>

    <div style="display: flex; gap: 10px;">
      <button type="submit" class="btn btn-primary"
              style="background: #1abc9c; color: white; border: none; padding: 10px 24px; border-radius: 4px; cursor: pointer;">
        {% if id %}Save Changes{% else %}Create Contact{% endif %}
      </button>
      <button type="button" onclick="App:CancelForm()"
              style="background: #95a5a6; color: white; border: none; padding: 10px 24px; border-radius: 4px; cursor: pointer;">
        Cancel
      </button>
    </div>
  </form>
</div>
```

### Show Create Form

```pascal
procedure TFormMain.ButtonNewClick(Sender: TObject);
begin
  ShowContactForm('', '', '', '', '', '', '');
end;

procedure TFormMain.ShowContactForm(const AID, AFirstName, ALastName,
  AEmail, APhone, ACompany, ANotes: string);
begin
  HTMLRenderDetail.SetTwigVariable('id', AID);
  HTMLRenderDetail.SetTwigVariable('firstName', AFirstName);
  HTMLRenderDetail.SetTwigVariable('lastName', ALastName);
  HTMLRenderDetail.SetTwigVariable('email', AEmail);
  HTMLRenderDetail.SetTwigVariable('phone', APhone);
  HTMLRenderDetail.SetTwigVariable('company', ACompany);
  HTMLRenderDetail.SetTwigVariable('notes', ANotes);

  HTMLRenderDetail.Twig.LoadFromFile(
    ExtractFilePath(ParamStr(0)) + 'templates\contact-form.html');

  if AID.IsEmpty then
    SetStatus('Creating new contact...')
  else
    SetStatus('Editing contact...');
end;
```

### Handle Form Submission

```pascal
procedure TFormMain.HandleFormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
var
  StatusCode: Integer;
  Response: TJSONObject;
  ContactID: string;
  Body: TJSONObject;
begin
  if FormName <> 'contactForm' then Exit;

  // Validate required fields
  var FirstName := FormData.Values['firstName'].Trim;
  var LastName := FormData.Values['lastName'].Trim;

  if FirstName.IsEmpty or LastName.IsEmpty then
  begin
    ShowMessage('First name and last name are required');
    Exit;
  end;

  ContactID := FormData.Values['id'];

  // Build the request body
  Body := TJSONObject.Create;
  try
    Body.AddPair('firstName', FirstName);
    Body.AddPair('lastName', LastName);
    Body.AddPair('email', FormData.Values['email'].Trim);
    Body.AddPair('phone', FormData.Values['phone'].Trim);
    Body.AddPair('company', FormData.Values['company'].Trim);
    Body.AddPair('notes', FormData.Values['notes'].Trim);

    if ContactID.IsEmpty then
    begin
      // CREATE
      SetStatus('Creating contact...');
      Response := Tina4REST1.Post(StatusCode, '/api/contacts', '', Body.ToString);
    end
    else
    begin
      // UPDATE
      SetStatus('Updating contact...');
      Response := Tina4REST1.Patch(StatusCode, '/api/contacts/' + ContactID, '', Body.ToString);
    end;
  finally
    Body.Free;
  end;

  try
    if StatusCode in [200, 201] then
    begin
      if ContactID.IsEmpty then
        SetStatus('Contact created successfully')
      else
        SetStatus('Contact updated successfully');

      // Refresh the list and show the detail
      RefreshContacts;

      if Assigned(Response) then
      begin
        var NewID := Response.GetValue<String>('id', ContactID);
        ShowContactDetail(NewID);
      end;
    end
    else
    begin
      var ErrorMsg := 'Unknown error';
      if Assigned(Response) then
        ErrorMsg := Response.GetValue<String>('error', ErrorMsg);
      SetStatus('Error: ' + ErrorMsg);
      ShowMessage('Failed to save contact: ' + ErrorMsg);
    end;
  finally
    Response.Free;
  end;
end;
```

---

## 9. Update Contact

### Edit Button Handler

The Edit button in the detail template uses RTTI to call `EditContact`:

```pascal
procedure TFormMain.EditContact(const AID: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  // Fetch the current contact data
  Response := Tina4REST1.Get(StatusCode, '/api/contacts/' + AID);
  try
    if (StatusCode = 200) and Assigned(Response) then
    begin
      ShowContactForm(
        Response.GetValue<String>('id', ''),
        Response.GetValue<String>('firstName', ''),
        Response.GetValue<String>('lastName', ''),
        Response.GetValue<String>('email', ''),
        Response.GetValue<String>('phone', ''),
        Response.GetValue<String>('company', ''),
        Response.GetValue<String>('notes', ''));
    end
    else
      ShowMessage('Could not load contact for editing');
  finally
    Response.Free;
  end;
end;
```

The `HandleFormSubmit` method already handles both create and update -- it checks whether `id` is present in the form data.

---

## 10. Delete Contact

### Delete with Confirmation

```pascal
procedure TFormMain.DeleteContact(const AID: string);
begin
  // Confirm before deleting
  MessageDlg('Are you sure you want to delete this contact?',
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0,
    procedure(const AResult: TModalResult)
    var
      StatusCode: Integer;
      Response: TJSONObject;
    begin
      if AResult <> mrYes then Exit;

      SetStatus('Deleting contact...');

      Response := Tina4REST1.Delete(StatusCode, '/api/contacts/' + AID);
      try
        if StatusCode in [200, 204] then
        begin
          SetStatus('Contact deleted');
          RefreshContacts;
          ShowEmptyState;
        end
        else
        begin
          var ErrorMsg := 'Delete failed';
          if Assigned(Response) then
            ErrorMsg := Response.GetValue<String>('error', ErrorMsg);
          SetStatus('Error: ' + ErrorMsg);
          ShowMessage(ErrorMsg);
        end;
      finally
        Response.Free;
      end;
    end);
end;

procedure TFormMain.ShowEmptyState;
begin
  HTMLRenderDetail.HTML.Text :=
    '<div style="font-family: Arial, sans-serif; padding: 40px; text-align: center; color: #999;">' +
    '  <h2>No Contact Selected</h2>' +
    '  <p>Select a contact from the list or create a new one.</p>' +
    '</div>';
end;
```

---

## 11. Search and Filter

### Option 1: Filter MemTable Locally

For small datasets, filter the existing MemTable without making another API call:

```pascal
procedure TFormMain.ButtonSearchClick(Sender: TObject);
var
  SearchTerm: string;
begin
  SearchTerm := EditSearch.Text.Trim.ToLower;

  if SearchTerm.IsEmpty then
  begin
    MemTableContacts.Filtered := False;
    PopulateGrid;
    SetStatus(Format('Showing all %d contacts', [MemTableContacts.RecordCount]));
    Exit;
  end;

  MemTableContacts.OnFilterRecord := procedure(DataSet: TDataSet;
    var Accept: Boolean)
  begin
    var FirstName := DataSet.FieldByName('first_name').AsString.ToLower;
    var LastName := DataSet.FieldByName('last_name').AsString.ToLower;
    var Email := DataSet.FieldByName('email').AsString.ToLower;
    var Company := DataSet.FieldByName('company').AsString.ToLower;

    Accept := FirstName.Contains(SearchTerm) or
              LastName.Contains(SearchTerm) or
              Email.Contains(SearchTerm) or
              Company.Contains(SearchTerm);
  end;

  MemTableContacts.Filtered := True;
  PopulateGrid;
  SetStatus(Format('Found %d matching contacts', [MemTableContacts.RecordCount]));
end;
```

### Option 2: Search via API

For large datasets, send the search term to the API:

```pascal
procedure TFormMain.SearchViaAPI(const ASearchTerm: string);
begin
  if ASearchTerm.Trim.IsEmpty then
    RESTRequestList.EndPoint := '/api/contacts'
  else
    RESTRequestList.EndPoint := '/api/contacts?search=' + ASearchTerm.Trim;

  RESTRequestList.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      PopulateGrid;
      SetStatus(Format('Found %d contacts for "%s"',
        [MemTableContacts.RecordCount, ASearchTerm]));
    end);
  end;

  RESTRequestList.ExecuteRESTCallAsync;
end;
```

### Clear Search

```pascal
procedure TFormMain.EditSearchKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
    ButtonSearchClick(Sender)
  else if Key = vkEscape then
  begin
    EditSearch.Text := '';
    MemTableContacts.Filtered := False;
    PopulateGrid;
  end;
end;
```

---

## 12. Polish: Status, Loading, and Error Handling

### Status Bar

```pascal
procedure TFormMain.SetStatus(const AMessage: string);
begin
  LabelStatus.Text := FormatDateTime('hh:nn:ss', Now) + '  ' + AMessage;
end;
```

### Cancel Form Navigation

```pascal
procedure TFormMain.CancelForm;
begin
  // If a contact was selected before, show its detail again
  if not MemTableContacts.IsEmpty then
  begin
    var ContactID := MemTableContacts.FieldByName('id').AsString;
    ShowContactDetail(ContactID);
  end
  else
    ShowEmptyState;
end;
```

### Error Handling Wrapper

```pascal
procedure TFormMain.SafeAPICall(AProc: TProc);
begin
  try
    AProc();
  except
    on E: Exception do
    begin
      SetStatus('Error: ' + E.Message);
      ShowMessage('An error occurred: ' + E.Message);
    end;
  end;
end;

// Usage:
procedure TFormMain.ButtonRefreshClick(Sender: TObject);
begin
  SafeAPICall(procedure
  begin
    RefreshContacts;
  end);
end;
```

---

## 13. Full Source Code

Here is the complete main form unit:

```pascal
unit MainForm;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Layouts, FMX.Grid, FMX.Grid.Style, FMX.ScrollBox,
  FMX.Dialogs,
  FireDAC.Comp.Client, FireDAC.Stan.Intf,
  Data.DB,
  Tina4REST, Tina4RESTRequest, Tina4HTMLRender, Tina4Core;

type
  TFormMain = class(TForm)
    LayoutMain: TLayout;
    LayoutLeft: TLayout;
    LayoutRight: TLayout;
    Splitter1: TSplitter;
    GridContacts: TStringGrid;
    EditSearch: TEdit;
    ButtonSearch: TButton;
    ButtonNew: TButton;
    ButtonRefresh: TButton;
    HTMLRenderDetail: TTina4HTMLRender;
    LabelStatus: TLabel;
    Tina4REST1: TTina4REST;
    RESTRequestList: TTina4RESTRequest;
    RESTRequestDetail: TTina4RESTRequest;
    MemTableContacts: TFDMemTable;
    DataSourceContacts: TDataSource;

    procedure FormCreate(Sender: TObject);
    procedure ButtonRefreshClick(Sender: TObject);
    procedure ButtonNewClick(Sender: TObject);
    procedure ButtonSearchClick(Sender: TObject);
    procedure EditSearchKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
  private
    procedure SetupGrid;
    procedure RefreshContacts;
    procedure PopulateGrid;
    procedure SetStatus(const AMessage: string);
    procedure ShowEmptyState;
    procedure ShowContactDetail(const AContactID: string);
    procedure ShowContactForm(const AID, AFirstName, ALastName,
      AEmail, APhone, ACompany, ANotes: string);
    procedure HandleFormSubmit(Sender: TObject;
      const FormName: string; FormData: TStrings);
    procedure HandleElementClick(Sender: TObject;
      const ObjectName, MethodName: string; Params: TStrings);
    procedure GridCellClick(const Column: TColumn; const Row: Integer);
  public
    procedure EditContact(const AID: string);
    procedure DeleteContact(const AID: string);
    procedure CancelForm;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  // REST configuration
  Tina4REST1.BaseUrl := 'https://api.example.com/v1';

  RESTRequestList.Tina4REST := Tina4REST1;
  RESTRequestList.EndPoint := '/api/contacts';
  RESTRequestList.RequestType := TTina4RequestType.Get;
  RESTRequestList.DataKey := 'records';
  RESTRequestList.MemTable := MemTableContacts;
  RESTRequestList.SyncMode := TTina4RestSyncMode.Clear;

  RESTRequestDetail.Tina4REST := Tina4REST1;
  RESTRequestDetail.RequestType := TTina4RequestType.Get;

  // Grid
  SetupGrid;

  // HTML Renderer
  HTMLRenderDetail.TwigTemplatePath := ExtractFilePath(ParamStr(0)) + 'templates';
  HTMLRenderDetail.OnFormSubmit := HandleFormSubmit;
  HTMLRenderDetail.RegisterObject('App', Self);

  // Initial state
  ShowEmptyState;
  RefreshContacts;
end;

procedure TFormMain.SetupGrid;
begin
  GridContacts.ColumnCount := 4;
  GridContacts.Columns[0].Header := 'Name';
  GridContacts.Columns[0].Width := 150;
  GridContacts.Columns[1].Header := 'Email';
  GridContacts.Columns[1].Width := 130;
  GridContacts.Columns[2].Header := 'Phone';
  GridContacts.Columns[2].Width := 100;
  GridContacts.Columns[3].Header := 'Company';
  GridContacts.Columns[3].Width := 100;
  GridContacts.OnCellClick := GridCellClick;
end;

procedure TFormMain.RefreshContacts;
begin
  SetStatus('Loading contacts...');

  RESTRequestList.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      PopulateGrid;
      SetStatus(Format('Loaded %d contacts', [MemTableContacts.RecordCount]));
    end);
  end;

  RESTRequestList.ExecuteRESTCallAsync;
end;

procedure TFormMain.PopulateGrid;
begin
  GridContacts.RowCount := MemTableContacts.RecordCount;
  MemTableContacts.First;
  var Row := 0;

  while not MemTableContacts.Eof do
  begin
    GridContacts.Cells[0, Row] :=
      MemTableContacts.FieldByName('first_name').AsString + ' ' +
      MemTableContacts.FieldByName('last_name').AsString;
    GridContacts.Cells[1, Row] := MemTableContacts.FieldByName('email').AsString;
    GridContacts.Cells[2, Row] := MemTableContacts.FieldByName('phone').AsString;
    GridContacts.Cells[3, Row] := MemTableContacts.FieldByName('company').AsString;

    MemTableContacts.Next;
    Inc(Row);
  end;
end;

procedure TFormMain.GridCellClick(const Column: TColumn; const Row: Integer);
begin
  MemTableContacts.First;
  MemTableContacts.MoveBy(Row);
  var ContactID := MemTableContacts.FieldByName('id').AsString;
  ShowContactDetail(ContactID);
end;

procedure TFormMain.ShowContactDetail(const AContactID: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  SetStatus('Loading contact...');
  Response := Tina4REST1.Get(StatusCode, '/api/contacts/' + AContactID);
  try
    if (StatusCode = 200) and Assigned(Response) then
    begin
      HTMLRenderDetail.SetTwigVariable('id', Response.GetValue<String>('id', ''));
      HTMLRenderDetail.SetTwigVariable('firstName', Response.GetValue<String>('firstName', ''));
      HTMLRenderDetail.SetTwigVariable('lastName', Response.GetValue<String>('lastName', ''));
      HTMLRenderDetail.SetTwigVariable('email', Response.GetValue<String>('email', ''));
      HTMLRenderDetail.SetTwigVariable('phone', Response.GetValue<String>('phone', ''));
      HTMLRenderDetail.SetTwigVariable('company', Response.GetValue<String>('company', ''));
      HTMLRenderDetail.SetTwigVariable('notes', Response.GetValue<String>('notes', ''));
      HTMLRenderDetail.SetTwigVariable('createdAt', Response.GetValue<String>('createdAt', ''));

      HTMLRenderDetail.Twig.LoadFromFile(
        ExtractFilePath(ParamStr(0)) + 'templates\contact-detail.html');

      SetStatus('Viewing: ' + Response.GetValue<String>('firstName', '') + ' ' +
        Response.GetValue<String>('lastName', ''));
    end
    else
      SetStatus('Error loading contact');
  finally
    Response.Free;
  end;
end;

procedure TFormMain.ShowContactForm(const AID, AFirstName, ALastName,
  AEmail, APhone, ACompany, ANotes: string);
begin
  HTMLRenderDetail.SetTwigVariable('id', AID);
  HTMLRenderDetail.SetTwigVariable('firstName', AFirstName);
  HTMLRenderDetail.SetTwigVariable('lastName', ALastName);
  HTMLRenderDetail.SetTwigVariable('email', AEmail);
  HTMLRenderDetail.SetTwigVariable('phone', APhone);
  HTMLRenderDetail.SetTwigVariable('company', ACompany);
  HTMLRenderDetail.SetTwigVariable('notes', ANotes);

  HTMLRenderDetail.Twig.LoadFromFile(
    ExtractFilePath(ParamStr(0)) + 'templates\contact-form.html');

  if AID.IsEmpty then
    SetStatus('Creating new contact...')
  else
    SetStatus('Editing contact...');
end;

procedure TFormMain.ButtonNewClick(Sender: TObject);
begin
  ShowContactForm('', '', '', '', '', '', '');
end;

procedure TFormMain.HandleFormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
var
  StatusCode: Integer;
  Response: TJSONObject;
  ContactID: string;
  Body: TJSONObject;
begin
  if FormName <> 'contactForm' then Exit;

  var FirstName := FormData.Values['firstName'].Trim;
  var LastName := FormData.Values['lastName'].Trim;

  if FirstName.IsEmpty or LastName.IsEmpty then
  begin
    ShowMessage('First name and last name are required');
    Exit;
  end;

  ContactID := FormData.Values['id'];
  Body := TJSONObject.Create;
  try
    Body.AddPair('firstName', FirstName);
    Body.AddPair('lastName', LastName);
    Body.AddPair('email', FormData.Values['email'].Trim);
    Body.AddPair('phone', FormData.Values['phone'].Trim);
    Body.AddPair('company', FormData.Values['company'].Trim);
    Body.AddPair('notes', FormData.Values['notes'].Trim);

    if ContactID.IsEmpty then
    begin
      SetStatus('Creating contact...');
      Response := Tina4REST1.Post(StatusCode, '/api/contacts', '', Body.ToString);
    end
    else
    begin
      SetStatus('Saving changes...');
      Response := Tina4REST1.Patch(StatusCode, '/api/contacts/' + ContactID, '', Body.ToString);
    end;
  finally
    Body.Free;
  end;

  try
    if StatusCode in [200, 201] then
    begin
      SetStatus(IfThen(ContactID.IsEmpty, 'Contact created', 'Contact updated'));
      RefreshContacts;
      if Assigned(Response) then
        ShowContactDetail(Response.GetValue<String>('id', ContactID));
    end
    else
    begin
      var ErrorMsg := 'Save failed';
      if Assigned(Response) then
        ErrorMsg := Response.GetValue<String>('error', ErrorMsg);
      SetStatus('Error: ' + ErrorMsg);
      ShowMessage(ErrorMsg);
    end;
  finally
    Response.Free;
  end;
end;

procedure TFormMain.HandleElementClick(Sender: TObject;
  const ObjectName, MethodName: string; Params: TStrings);
begin
  // RTTI-based onclick routing is handled automatically
  // This handler is available for custom processing if needed
end;

procedure TFormMain.EditContact(const AID: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := Tina4REST1.Get(StatusCode, '/api/contacts/' + AID);
  try
    if (StatusCode = 200) and Assigned(Response) then
      ShowContactForm(
        Response.GetValue<String>('id', ''),
        Response.GetValue<String>('firstName', ''),
        Response.GetValue<String>('lastName', ''),
        Response.GetValue<String>('email', ''),
        Response.GetValue<String>('phone', ''),
        Response.GetValue<String>('company', ''),
        Response.GetValue<String>('notes', ''))
    else
      ShowMessage('Could not load contact');
  finally
    Response.Free;
  end;
end;

procedure TFormMain.DeleteContact(const AID: string);
begin
  MessageDlg('Delete this contact?', TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0,
    procedure(const AResult: TModalResult)
    var
      StatusCode: Integer;
      Response: TJSONObject;
    begin
      if AResult <> mrYes then Exit;

      SetStatus('Deleting...');
      Response := Tina4REST1.Delete(StatusCode, '/api/contacts/' + AID);
      try
        if StatusCode in [200, 204] then
        begin
          SetStatus('Contact deleted');
          RefreshContacts;
          ShowEmptyState;
        end
        else
          SetStatus('Delete failed');
      finally
        Response.Free;
      end;
    end);
end;

procedure TFormMain.CancelForm;
begin
  if not MemTableContacts.IsEmpty then
    ShowContactDetail(MemTableContacts.FieldByName('id').AsString)
  else
    ShowEmptyState;
end;

procedure TFormMain.ButtonSearchClick(Sender: TObject);
var
  SearchTerm: string;
begin
  SearchTerm := EditSearch.Text.Trim.ToLower;

  if SearchTerm.IsEmpty then
  begin
    MemTableContacts.Filtered := False;
    PopulateGrid;
    SetStatus(Format('Showing all %d contacts', [MemTableContacts.RecordCount]));
    Exit;
  end;

  MemTableContacts.OnFilterRecord := procedure(DataSet: TDataSet; var Accept: Boolean)
  begin
    Accept :=
      DataSet.FieldByName('first_name').AsString.ToLower.Contains(SearchTerm) or
      DataSet.FieldByName('last_name').AsString.ToLower.Contains(SearchTerm) or
      DataSet.FieldByName('email').AsString.ToLower.Contains(SearchTerm) or
      DataSet.FieldByName('company').AsString.ToLower.Contains(SearchTerm);
  end;

  MemTableContacts.Filtered := True;
  PopulateGrid;
  SetStatus(Format('Found %d contacts for "%s"', [MemTableContacts.RecordCount, SearchTerm]));
end;

procedure TFormMain.EditSearchKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
    ButtonSearchClick(Sender)
  else if Key = vkEscape then
  begin
    EditSearch.Text := '';
    MemTableContacts.Filtered := False;
    PopulateGrid;
  end;
end;

procedure TFormMain.ShowEmptyState;
begin
  HTMLRenderDetail.HTML.Text :=
    '<div style="font-family: Arial, sans-serif; padding: 40px; text-align: center; color: #999;">' +
    '  <h2>No Contact Selected</h2>' +
    '  <p>Select a contact from the list, or click "New" to create one.</p>' +
    '</div>';
end;

procedure TFormMain.SetStatus(const AMessage: string);
begin
  LabelStatus.Text := FormatDateTime('hh:nn:ss', Now) + '  ' + AMessage;
end;

end.
```

---

## 14. Template Files

Create a `templates` folder next to your executable. Place `contact-detail.html` and `contact-form.html` there (shown in sections 7 and 8 above).

```
ContactManager.exe
templates/
  contact-detail.html
  contact-form.html
```

---

## Exercise: Extend the Contact Manager

Add these features to the contact manager:

1. **Categories/Tags** -- Add a `category` field to contacts (e.g., "Work", "Personal", "Client"). Add a dropdown filter above the grid to filter by category. Add a category select to the form.

2. **Export to CSV** -- Add an "Export" button that saves the current contact list (filtered or unfiltered) to a CSV file using `TSaveDialog`.

### Solution: CSV Export

```pascal
procedure TFormMain.ButtonExportClick(Sender: TObject);
var
  SaveDialog: TSaveDialog;
  CSV: TStringList;
begin
  SaveDialog := TSaveDialog.Create(Self);
  CSV := TStringList.Create;
  try
    SaveDialog.Filter := 'CSV files|*.csv';
    SaveDialog.DefaultExt := 'csv';
    SaveDialog.FileName := 'contacts_' + FormatDateTime('yyyymmdd', Now) + '.csv';

    if not SaveDialog.Execute then Exit;

    // Header row
    CSV.Add('"First Name","Last Name","Email","Phone","Company","Notes"');

    // Data rows
    MemTableContacts.First;
    while not MemTableContacts.Eof do
    begin
      CSV.Add(Format('"%s","%s","%s","%s","%s","%s"', [
        MemTableContacts.FieldByName('first_name').AsString.Replace('"', '""'),
        MemTableContacts.FieldByName('last_name').AsString.Replace('"', '""'),
        MemTableContacts.FieldByName('email').AsString.Replace('"', '""'),
        MemTableContacts.FieldByName('phone').AsString.Replace('"', '""'),
        MemTableContacts.FieldByName('company').AsString.Replace('"', '""'),
        MemTableContacts.FieldByName('notes').AsString.Replace('"', '""')
      ]));

      MemTableContacts.Next;
    end;

    CSV.SaveToFile(SaveDialog.FileName, TEncoding.UTF8);
    SetStatus(Format('Exported %d contacts to %s',
      [MemTableContacts.RecordCount, ExtractFileName(SaveDialog.FileName)]));
  finally
    CSV.Free;
    SaveDialog.Free;
  end;
end;
```

### Solution: Category Filter

Add a `TComboBox` named `ComboCategory` above the grid:

```pascal
procedure TFormMain.FormCreate(Sender: TObject);
begin
  // ... existing setup ...

  ComboCategory.Items.Add('All Categories');
  ComboCategory.Items.Add('Work');
  ComboCategory.Items.Add('Personal');
  ComboCategory.Items.Add('Client');
  ComboCategory.Items.Add('Vendor');
  ComboCategory.ItemIndex := 0;
  ComboCategory.OnChange := ComboCategoryChange;
end;

procedure TFormMain.ComboCategoryChange(Sender: TObject);
begin
  if ComboCategory.ItemIndex = 0 then
  begin
    MemTableContacts.Filtered := False;
    PopulateGrid;
    SetStatus(Format('Showing all %d contacts', [MemTableContacts.RecordCount]));
  end
  else
  begin
    var Category := ComboCategory.Items[ComboCategory.ItemIndex];

    MemTableContacts.OnFilterRecord := procedure(DataSet: TDataSet; var Accept: Boolean)
    begin
      Accept := DataSet.FieldByName('category').AsString = Category;
    end;

    MemTableContacts.Filtered := True;
    PopulateGrid;
    SetStatus(Format('Showing %d "%s" contacts',
      [MemTableContacts.RecordCount, Category]));
  end;
end;
```

Add the category field to `contact-form.html`:

```html
<div style="margin-bottom: 15px;">
  <label style="display: block; color: #666; margin-bottom: 4px;">Category</label>
  <select name="category" class="form-control"
          style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
    <option value="">-- Select --</option>
    <option value="Work" {% if category == 'Work' %}selected{% endif %}>Work</option>
    <option value="Personal" {% if category == 'Personal' %}selected{% endif %}>Personal</option>
    <option value="Client" {% if category == 'Client' %}selected{% endif %}>Client</option>
    <option value="Vendor" {% if category == 'Vendor' %}selected{% endif %}>Vendor</option>
  </select>
</div>
```
