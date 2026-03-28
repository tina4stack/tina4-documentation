# Chapter 12: Building a Complete Application

## The Admin Dashboard

Picture the screen. A login form rendered in HTML with styled inputs and a submit button. You type credentials, click Login, and the form posts to an API endpoint. The bearer token comes back. The dashboard appears -- stat cards showing user counts and active sessions, a sidebar menu, a user table with search and pagination. A WebSocket connection pushes live notifications. A red badge increments on the bell icon.

This chapter builds that application from scratch using every Tina4 Delphi component: TTina4REST, TTina4RESTRequest, TTina4HTMLRender, TTina4HTMLPages, TTina4Twig, TTina4JSONAdapter, and TTina4WebSocketClient. By the end, you will have a complete, working desktop admin dashboard -- and you will have seen how all the pieces from previous chapters fit together in a real application.

---

## 1. What We Are Building

The admin dashboard has four pages:

1. **Login** -- HTML form, POST to API, store bearer token
2. **Dashboard** -- Stat cards with user count, active sessions, recent activity
3. **Users** -- List, search, create, edit, delete users via REST
4. **Settings** -- Application configuration form

Plus cross-cutting concerns:

- **Authentication** -- Bearer token stored in TTina4REST, checked on every page
- **WebSocket notifications** -- Live updates pushed from the server
- **Error handling** -- Network errors, expired tokens, validation failures

---

## 2. Project Setup

Create a new FMX application in Delphi. Name the project `AdminDashboard`.

### File Structure

```
AdminDashboard/
  AdminDashboard.dpr         -- Project file
  MainUnit.pas               -- Main form with all components
  MainUnit.fmx               -- FMX form definition
  templates/
    login.html               -- Login page template
    dashboard.html           -- Dashboard page template
    users.html               -- Users list template
    user-detail.html         -- User detail/edit template
    settings.html            -- Settings page template
    layout.html              -- Shared layout with sidebar
```

### The Main Form

Drop these components on the form:

| Component | Name | Purpose |
|---|---|---|
| `TTina4REST` | `REST` | Base URL and authentication |
| `TTina4RESTRequest` | `RESTUsers` | Fetch user list |
| `TTina4RESTRequest` | `RESTStats` | Fetch dashboard stats |
| `TFDMemTable` | `MemUsers` | Store user data |
| `TFDMemTable` | `MemStats` | Store stats data |
| `TTina4HTMLRender` | `Renderer` | Display HTML content |
| `TTina4HTMLPages` | `Pages` | Page navigation |
| `TDataSource` | `DSUsers` | Bridge MemTable to data-aware controls |

### Project File

```pascal
// AdminDashboard.dpr
program AdminDashboard;

uses
  FMX.Forms,
  MainUnit in 'MainUnit.pas' {FormMain};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
```

---

## 3. Main Unit -- Declarations

```pascal
unit MainUnit;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  System.Generics.Collections, System.Threading,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Layouts,
  FMX.Dialogs,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  Data.DB,
  Tina4REST, Tina4RESTRequest, Tina4HTMLRender, Tina4HTMLPages,
  Tina4Twig, Tina4JSONAdapter, Tina4Core;

type
  TFormMain = class(TForm)
    REST: TTina4REST;
    RESTUsers: TTina4RESTRequest;
    RESTStats: TTina4RESTRequest;
    MemUsers: TFDMemTable;
    MemStats: TFDMemTable;
    Renderer: TTina4HTMLRender;
    Pages: TTina4HTMLPages;
    DSUsers: TDataSource;
    procedure FormCreate(Sender: TObject);
  private
    FBearerToken: string;
    FCurrentUserId: string;
    FSearchFilter: string;
    FCurrentPage: Integer;
    FPageSize: Integer;
    FNotificationCount: Integer;

    { Authentication }
    procedure DoLogin(const Username, Password: string);
    procedure DoLogout;
    function IsAuthenticated: Boolean;

    { Page setup }
    procedure SetupPages;
    procedure SetupLoginPage;
    procedure SetupDashboardPage;
    procedure SetupUsersPage;
    procedure SetupSettingsPage;

    { REST operations }
    procedure FetchStats;
    procedure FetchUsers;
    procedure CreateUser(const Name, Email, Role: string);
    procedure UpdateUser(const Id, Name, Email, Role: string);
    procedure DeleteUser(const Id: string);

    { Event handlers for HTML }
    procedure HandleLogin(const FormData: string);
    procedure HandleSearch(const Query: string);
    procedure HandlePageChange(const Page: string);
    procedure HandleEditUser(const UserId: string);
    procedure HandleDeleteUser(const UserId: string);
    procedure HandleSaveUser(const FormData: string);
    procedure HandleSaveSettings(const FormData: string);

    { UI helpers }
    procedure ShowNotification(const Msg: string; IsError: Boolean = False);
    procedure RefreshCurrentPage;
    function BuildUserTableHTML: string;
    function BuildStatsHTML: string;
    function ParseFormData(const Raw: string): TStringList;
  public
    { RTTI-callable methods for HTML onclick }
    procedure NavigateTo(const PageName: string);
    procedure OnLoginSubmit(const Username, Password: string);
    procedure OnSearchSubmit(const Query: string);
    procedure OnEditClick(const UserId: string);
    procedure OnDeleteClick(const UserId: string);
    procedure OnPageClick(const Page: string);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}
```

---

## 4. Initialization

```pascal
procedure TFormMain.FormCreate(Sender: TObject);
begin
  FCurrentPage := 1;
  FPageSize := 10;
  FNotificationCount := 0;
  FSearchFilter := '';

  { REST configuration }
  REST.BaseUrl := 'https://api.example.com/v1';

  { Users request }
  RESTUsers.Tina4REST := REST;
  RESTUsers.EndPoint := '/users';
  RESTUsers.RequestType := TTina4RequestType.Get;
  RESTUsers.DataKey := 'records';
  RESTUsers.MemTable := MemUsers;
  RESTUsers.SyncMode := TTina4RestSyncMode.Clear;

  { Stats request }
  RESTStats.Tina4REST := REST;
  RESTStats.EndPoint := '/stats';
  RESTStats.RequestType := TTina4RequestType.Get;
  RESTStats.DataKey := 'stats';
  RESTStats.MemTable := MemStats;

  { HTML renderer }
  Renderer.CacheEnabled := True;
  Renderer.CacheDir := TPath.Combine(TPath.GetDocumentsPath, 'AdminCache');
  Renderer.RegisterObject('App', Self);

  { Pages }
  Pages.Renderer := Renderer;
  Pages.TwigTemplatePath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'templates');

  SetupPages;

  { Page navigation guard }
  Pages.OnBeforeNavigate := procedure(Sender: TObject;
    const FromPage, ToPage: string; var Allow: Boolean)
  begin
    if (ToPage <> 'login') and (not IsAuthenticated) then
    begin
      Allow := False;
      Pages.NavigateTo('login');
    end;
  end;
end;
```

---

## 5. Authentication

```pascal
function TFormMain.IsAuthenticated: Boolean;
begin
  Result := not FBearerToken.IsEmpty;
end;

procedure TFormMain.DoLogin(const Username, Password: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
  Body: string;
begin
  Body := Format('{"username": "%s", "password": "%s"}',
    [Username, Password]);

  Response := REST.Post(StatusCode, '/auth/login', '', Body);
  try
    if StatusCode = 200 then
    begin
      FBearerToken := Response.GetValue<string>('token');
      REST.SetBearer(FBearerToken);

      { Navigate to dashboard }
      Pages.NavigateTo('dashboard');
      FetchStats;
      FetchUsers;
    end
    else
    begin
      var Msg := 'Login failed.';
      if Assigned(Response) then
        Msg := Response.GetValue<string>('message', 'Invalid credentials.');
      ShowNotification(Msg, True);
    end;
  finally
    Response.Free;
  end;
end;

procedure TFormMain.DoLogout;
begin
  FBearerToken := '';
  REST.SetBearer('');
  Pages.NavigateTo('login');
end;

{ RTTI-callable from HTML onclick }
procedure TFormMain.OnLoginSubmit(const Username, Password: string);
begin
  DoLogin(Username, Password);
end;
```

---

## 6. Page Definitions

```pascal
procedure TFormMain.SetupPages;
begin
  SetupLoginPage;
  SetupDashboardPage;
  SetupUsersPage;
  SetupSettingsPage;
end;

procedure TFormMain.SetupLoginPage;
var
  Page: TTina4Page;
begin
  Page := Pages.Pages.Add;
  Page.PageName := 'login';
  Page.IsDefault := True;
  Page.HTMLContent.Text :=
    '<div style="max-width: 400px; margin: 80px auto; ' +
    '  font-family: Arial, sans-serif;">' +
    '  <h1 style="text-align: center; color: #2c3e50;">Admin Dashboard</h1>' +
    '  <div style="background: white; padding: 30px; border-radius: 8px; ' +
    '    box-shadow: 0 2px 10px rgba(0,0,0,0.1);">' +
    '    <div style="margin-bottom: 15px;">' +
    '      <label style="display: block; margin-bottom: 5px; ' +
    '        color: #555; font-size: 14px;">Username</label>' +
    '      <input type="text" id="loginUser" ' +
    '        style="width: 100%; padding: 10px; border: 1px solid #ddd; ' +
    '        border-radius: 4px; font-size: 14px;" ' +
    '        placeholder="Enter username">' +
    '    </div>' +
    '    <div style="margin-bottom: 20px;">' +
    '      <label style="display: block; margin-bottom: 5px; ' +
    '        color: #555; font-size: 14px;">Password</label>' +
    '      <input type="password" id="loginPass" ' +
    '        style="width: 100%; padding: 10px; border: 1px solid #ddd; ' +
    '        border-radius: 4px; font-size: 14px;" ' +
    '        placeholder="Enter password">' +
    '    </div>' +
    '    <button onclick="App:OnLoginSubmit(' +
    '      document.getElementById(''loginUser'').value, ' +
    '      document.getElementById(''loginPass'').value)" ' +
    '      style="width: 100%; padding: 12px; background: #3498db; ' +
    '      color: white; border: none; border-radius: 4px; ' +
    '      font-size: 16px; cursor: pointer;">Login</button>' +
    '    <div id="loginError" style="display: none; margin-top: 15px; ' +
    '      padding: 10px; background: #e74c3c; color: white; ' +
    '      border-radius: 4px;"></div>' +
    '  </div>' +
    '</div>';
end;
```

The login page uses HTML inputs rendered by TTina4HTMLRender. The button's `onclick` calls `App:OnLoginSubmit(...)` which resolves via RTTI to the `TFormMain.OnLoginSubmit` method. The parameters are extracted from the input fields using `document.getElementById`.

---

## 7. Dashboard Page with Stats

```pascal
procedure TFormMain.SetupDashboardPage;
var
  Page: TTina4Page;
begin
  Page := Pages.Pages.Add;
  Page.PageName := 'dashboard';
  { Content is set dynamically after stats load }
  Page.HTMLContent.Text :=
    '<div style="padding: 20px; font-family: Arial;">' +
    '  <p>Loading dashboard...</p>' +
    '</div>';
end;

function TFormMain.BuildStatsHTML: string;
var
  UserCount, ActiveSessions, Revenue, OrderCount: string;
begin
  UserCount := '0';
  ActiveSessions := '0';
  Revenue := '$0';
  OrderCount := '0';

  if MemStats.Active and (MemStats.RecordCount > 0) then
  begin
    MemStats.First;
    UserCount := MemStats.FieldByName('user_count').AsString;
    ActiveSessions := MemStats.FieldByName('active_sessions').AsString;
    Revenue := '$' + MemStats.FieldByName('revenue').AsString;
    OrderCount := MemStats.FieldByName('order_count').AsString;
  end;

  Result :=
    '<div style="font-family: Arial; padding: 20px;">' +

    { Navigation bar }
    '  <div style="display: flex; justify-content: space-between; ' +
    '    align-items: center; margin-bottom: 30px; padding-bottom: 15px; ' +
    '    border-bottom: 2px solid #ecf0f1;">' +
    '    <h1 style="margin: 0; color: #2c3e50;">Dashboard</h1>' +
    '    <div>' +
    '      <span onclick="App:NavigateTo(''dashboard'')" ' +
    '        style="margin-right: 15px; color: #3498db; ' +
    '        cursor: pointer; font-weight: bold;">Dashboard</span>' +
    '      <span onclick="App:NavigateTo(''users'')" ' +
    '        style="margin-right: 15px; color: #7f8c8d; cursor: pointer;">Users</span>' +
    '      <span onclick="App:NavigateTo(''settings'')" ' +
    '        style="margin-right: 15px; color: #7f8c8d; cursor: pointer;">Settings</span>' +
    '      <span onclick="App:DoLogout" ' +
    '        style="color: #e74c3c; cursor: pointer;">Logout</span>' +
    '    </div>' +
    '  </div>' +

    { Stat cards row }
    '  <div style="display: flex; gap: 20px; margin-bottom: 30px;">' +

    '    <div style="flex: 1; background: #3498db; color: white; ' +
    '      padding: 20px; border-radius: 8px;">' +
    '      <p style="font-size: 14px; margin: 0; opacity: 0.8;">Total Users</p>' +
    '      <p style="font-size: 36px; margin: 5px 0 0 0; font-weight: bold;">' +
    UserCount + '</p>' +
    '    </div>' +

    '    <div style="flex: 1; background: #2ecc71; color: white; ' +
    '      padding: 20px; border-radius: 8px;">' +
    '      <p style="font-size: 14px; margin: 0; opacity: 0.8;">Active Sessions</p>' +
    '      <p style="font-size: 36px; margin: 5px 0 0 0; font-weight: bold;">' +
    ActiveSessions + '</p>' +
    '    </div>' +

    '    <div style="flex: 1; background: #9b59b6; color: white; ' +
    '      padding: 20px; border-radius: 8px;">' +
    '      <p style="font-size: 14px; margin: 0; opacity: 0.8;">Revenue</p>' +
    '      <p style="font-size: 36px; margin: 5px 0 0 0; font-weight: bold;">' +
    Revenue + '</p>' +
    '    </div>' +

    '    <div style="flex: 1; background: #e67e22; color: white; ' +
    '      padding: 20px; border-radius: 8px;">' +
    '      <p style="font-size: 14px; margin: 0; opacity: 0.8;">Orders</p>' +
    '      <p style="font-size: 36px; margin: 5px 0 0 0; font-weight: bold;">' +
    OrderCount + '</p>' +
    '    </div>' +

    '  </div>' +

    { Notification area }
    '  <div id="notificationArea" style="display: none; ' +
    '    padding: 10px; border-radius: 4px; margin-bottom: 20px;"></div>' +

    '</div>';
end;

procedure TFormMain.FetchStats;
begin
  RESTStats.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      var Page := Pages.Pages.FindPage('dashboard');
      if Assigned(Page) then
      begin
        Page.HTMLContent.Text := BuildStatsHTML;
        if Pages.ActivePage = 'dashboard' then
          Pages.NavigateTo('dashboard');
      end;
    end);
  end;
  RESTStats.ExecuteRESTCallAsync;
end;
```

The dashboard fetches stats asynchronously. When the REST call completes, it rebuilds the HTML and refreshes the page. The stat cards use colored backgrounds with large numbers -- a common dashboard pattern.

---

## 8. Users Page -- CRUD Operations

```pascal
procedure TFormMain.SetupUsersPage;
var
  Page: TTina4Page;
begin
  Page := Pages.Pages.Add;
  Page.PageName := 'users';
  Page.HTMLContent.Text :=
    '<div style="padding: 20px; font-family: Arial;">' +
    '  <p>Loading users...</p>' +
    '</div>';
end;

function TFormMain.BuildUserTableHTML: string;
var
  Rows: string;
  RowClass: string;
  I: Integer;
begin
  Rows := '';
  if MemUsers.Active then
  begin
    MemUsers.First;
    I := 0;
    while not MemUsers.Eof do
    begin
      if I mod 2 = 0 then
        RowClass := 'background: #f9f9f9;'
      else
        RowClass := 'background: white;';

      Rows := Rows +
        '<tr style="' + RowClass + '">' +
        '  <td style="padding: 10px; border-bottom: 1px solid #eee;">' +
             MemUsers.FieldByName('id').AsString + '</td>' +
        '  <td style="padding: 10px; border-bottom: 1px solid #eee;">' +
             MemUsers.FieldByName('name').AsString + '</td>' +
        '  <td style="padding: 10px; border-bottom: 1px solid #eee;">' +
             MemUsers.FieldByName('email').AsString + '</td>' +
        '  <td style="padding: 10px; border-bottom: 1px solid #eee;">' +
             MemUsers.FieldByName('role').AsString + '</td>' +
        '  <td style="padding: 10px; border-bottom: 1px solid #eee;">' +
        '    <span onclick="App:OnEditClick(''' +
               MemUsers.FieldByName('id').AsString + ''')" ' +
        '      style="color: #3498db; cursor: pointer; margin-right: 10px;">Edit</span>' +
        '    <span onclick="App:OnDeleteClick(''' +
               MemUsers.FieldByName('id').AsString + ''')" ' +
        '      style="color: #e74c3c; cursor: pointer;">Delete</span>' +
        '  </td>' +
        '</tr>';

      MemUsers.Next;
      Inc(I);
    end;
  end;

  if Rows.IsEmpty then
    Rows := '<tr><td colspan="5" style="padding: 20px; text-align: center; ' +
      'color: #999;">No users found.</td></tr>';

  Result :=
    '<div style="font-family: Arial; padding: 20px;">' +

    { Navigation }
    '  <div style="display: flex; justify-content: space-between; ' +
    '    align-items: center; margin-bottom: 30px; padding-bottom: 15px; ' +
    '    border-bottom: 2px solid #ecf0f1;">' +
    '    <h1 style="margin: 0; color: #2c3e50;">Users</h1>' +
    '    <div>' +
    '      <span onclick="App:NavigateTo(''dashboard'')" ' +
    '        style="margin-right: 15px; color: #7f8c8d; cursor: pointer;">Dashboard</span>' +
    '      <span onclick="App:NavigateTo(''users'')" ' +
    '        style="margin-right: 15px; color: #3498db; ' +
    '        cursor: pointer; font-weight: bold;">Users</span>' +
    '      <span onclick="App:NavigateTo(''settings'')" ' +
    '        style="margin-right: 15px; color: #7f8c8d; cursor: pointer;">Settings</span>' +
    '      <span onclick="App:DoLogout" ' +
    '        style="color: #e74c3c; cursor: pointer;">Logout</span>' +
    '    </div>' +
    '  </div>' +

    { Search bar }
    '  <div style="display: flex; gap: 10px; margin-bottom: 20px;">' +
    '    <input type="text" id="searchInput" placeholder="Search users..." ' +
    '      style="flex: 1; padding: 10px; border: 1px solid #ddd; ' +
    '      border-radius: 4px; font-size: 14px;" ' +
    '      value="' + FSearchFilter + '">' +
    '    <button onclick="App:OnSearchSubmit(' +
    '      document.getElementById(''searchInput'').value)" ' +
    '      style="padding: 10px 20px; background: #3498db; color: white; ' +
    '      border: none; border-radius: 4px; cursor: pointer;">Search</button>' +
    '    <button onclick="App:NavigateTo(''user-create'')" ' +
    '      style="padding: 10px 20px; background: #2ecc71; color: white; ' +
    '      border: none; border-radius: 4px; cursor: pointer;">+ New User</button>' +
    '  </div>' +

    { User table }
    '  <table style="width: 100%; border-collapse: collapse;">' +
    '    <thead>' +
    '      <tr style="background: #2c3e50; color: white;">' +
    '        <th style="padding: 12px; text-align: left;">ID</th>' +
    '        <th style="padding: 12px; text-align: left;">Name</th>' +
    '        <th style="padding: 12px; text-align: left;">Email</th>' +
    '        <th style="padding: 12px; text-align: left;">Role</th>' +
    '        <th style="padding: 12px; text-align: left;">Actions</th>' +
    '      </tr>' +
    '    </thead>' +
    '    <tbody>' + Rows + '</tbody>' +
    '  </table>' +

    { Pagination }
    '  <div style="margin-top: 20px; text-align: center;">' +
    '    <span onclick="App:OnPageClick(''' + (FCurrentPage - 1).ToString + ''')" ' +
    '      style="padding: 8px 16px; margin: 0 5px; background: #ecf0f1; ' +
    '      border-radius: 4px; cursor: pointer;">Previous</span>' +
    '    <span style="padding: 8px 16px; margin: 0 5px; background: #3498db; ' +
    '      color: white; border-radius: 4px;">Page ' + FCurrentPage.ToString + '</span>' +
    '    <span onclick="App:OnPageClick(''' + (FCurrentPage + 1).ToString + ''')" ' +
    '      style="padding: 8px 16px; margin: 0 5px; background: #ecf0f1; ' +
    '      border-radius: 4px; cursor: pointer;">Next</span>' +
    '  </div>' +

    '</div>';
end;

procedure TFormMain.FetchUsers;
var
  QueryParams: string;
begin
  QueryParams := Format('page=%d&limit=%d', [FCurrentPage, FPageSize]);
  if not FSearchFilter.IsEmpty then
    QueryParams := QueryParams + '&search=' + FSearchFilter;

  RESTUsers.EndPoint := '/users';
  RESTUsers.QueryParams := QueryParams;
  RESTUsers.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      var Page := Pages.Pages.FindPage('users');
      if Assigned(Page) then
      begin
        Page.HTMLContent.Text := BuildUserTableHTML;
        if Pages.ActivePage = 'users' then
          Pages.NavigateTo('users');
      end;
    end);
  end;
  RESTUsers.ExecuteRESTCallAsync;
end;
```

### Creating a User

```pascal
procedure TFormMain.CreateUser(const Name, Email, Role: string);
var
  StatusCode: Integer;
  Body: string;
  Response: TJSONObject;
begin
  Body := Format('{"name": "%s", "email": "%s", "role": "%s"}',
    [Name, Email, Role]);

  Response := REST.Post(StatusCode, '/users', '', Body);
  try
    if StatusCode in [200, 201] then
    begin
      ShowNotification('User created successfully.');
      FetchUsers;
      Pages.NavigateTo('users');
    end
    else
      ShowNotification('Failed to create user.', True);
  finally
    Response.Free;
  end;
end;
```

### Updating a User

```pascal
procedure TFormMain.UpdateUser(const Id, Name, Email, Role: string);
var
  StatusCode: Integer;
  Body: string;
  Response: TJSONObject;
begin
  Body := Format('{"name": "%s", "email": "%s", "role": "%s"}',
    [Name, Email, Role]);

  Response := REST.Patch(StatusCode, '/users/' + Id, '', Body);
  try
    if StatusCode = 200 then
    begin
      ShowNotification('User updated successfully.');
      FetchUsers;
      Pages.NavigateTo('users');
    end
    else
      ShowNotification('Failed to update user.', True);
  finally
    Response.Free;
  end;
end;
```

### Deleting a User

```pascal
procedure TFormMain.DeleteUser(const Id: string);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := REST.Delete(StatusCode, '/users/' + Id, '');
  try
    if StatusCode in [200, 204] then
    begin
      ShowNotification('User deleted.');
      FetchUsers;
    end
    else
      ShowNotification('Failed to delete user.', True);
  finally
    Response.Free;
  end;
end;
```

---

## 9. Settings Page

```pascal
procedure TFormMain.SetupSettingsPage;
var
  Page: TTina4Page;
begin
  Page := Pages.Pages.Add;
  Page.PageName := 'settings';
  Page.HTMLContent.Text :=
    '<div style="font-family: Arial; padding: 20px;">' +

    { Navigation }
    '  <div style="display: flex; justify-content: space-between; ' +
    '    align-items: center; margin-bottom: 30px; padding-bottom: 15px; ' +
    '    border-bottom: 2px solid #ecf0f1;">' +
    '    <h1 style="margin: 0; color: #2c3e50;">Settings</h1>' +
    '    <div>' +
    '      <span onclick="App:NavigateTo(''dashboard'')" ' +
    '        style="margin-right: 15px; color: #7f8c8d; cursor: pointer;">Dashboard</span>' +
    '      <span onclick="App:NavigateTo(''users'')" ' +
    '        style="margin-right: 15px; color: #7f8c8d; cursor: pointer;">Users</span>' +
    '      <span onclick="App:NavigateTo(''settings'')" ' +
    '        style="margin-right: 15px; color: #3498db; ' +
    '        cursor: pointer; font-weight: bold;">Settings</span>' +
    '      <span onclick="App:DoLogout" ' +
    '        style="color: #e74c3c; cursor: pointer;">Logout</span>' +
    '    </div>' +
    '  </div>' +

    { Settings form }
    '  <div style="max-width: 600px;">' +
    '    <div style="margin-bottom: 15px;">' +
    '      <label style="display: block; margin-bottom: 5px; color: #555;">App Name</label>' +
    '      <input type="text" id="settAppName" value="Admin Dashboard" ' +
    '        style="width: 100%; padding: 10px; border: 1px solid #ddd; ' +
    '        border-radius: 4px;">' +
    '    </div>' +
    '    <div style="margin-bottom: 15px;">' +
    '      <label style="display: block; margin-bottom: 5px; color: #555;">API URL</label>' +
    '      <input type="text" id="settApiUrl" value="https://api.example.com/v1" ' +
    '        style="width: 100%; padding: 10px; border: 1px solid #ddd; ' +
    '        border-radius: 4px;">' +
    '    </div>' +
    '    <div style="margin-bottom: 15px;">' +
    '      <label style="display: block; margin-bottom: 5px; color: #555;">' +
    '        Items Per Page</label>' +
    '      <select id="settPageSize" style="width: 100%; padding: 10px; ' +
    '        border: 1px solid #ddd; border-radius: 4px;">' +
    '        <option value="10">10</option>' +
    '        <option value="25">25</option>' +
    '        <option value="50">50</option>' +
    '      </select>' +
    '    </div>' +
    '    <div style="margin-bottom: 20px;">' +
    '      <label style="display: block; margin-bottom: 5px; color: #555;">' +
    '        Enable Notifications</label>' +
    '      <input type="checkbox" id="settNotify" checked ' +
    '        style="margin-right: 8px;">' +
    '      <span style="color: #555;">Receive real-time notifications</span>' +
    '    </div>' +
    '    <button onclick="App:HandleSaveSettings(' +
    '      document.getElementById(''settApiUrl'').value)" ' +
    '      style="padding: 12px 30px; background: #3498db; color: white; ' +
    '      border: none; border-radius: 4px; font-size: 16px; ' +
    '      cursor: pointer;">Save Settings</button>' +
    '  </div>' +
    '</div>';
end;

procedure TFormMain.HandleSaveSettings(const FormData: string);
begin
  REST.BaseUrl := FormData;  // The API URL passed from the form
  ShowNotification('Settings saved.');
end;
```

---

## 10. RTTI Event Handlers

These methods are called from HTML `onclick` attributes via the RTTI mechanism. They bridge the HTML UI to the Pascal logic.

```pascal
procedure TFormMain.NavigateTo(const PageName: string);
begin
  if not IsAuthenticated and (PageName <> 'login') then
  begin
    Pages.NavigateTo('login');
    Exit;
  end;

  Pages.NavigateTo(PageName);

  { Refresh data when entering certain pages }
  if PageName = 'dashboard' then
    FetchStats
  else if PageName = 'users' then
    FetchUsers;
end;

procedure TFormMain.OnSearchSubmit(const Query: string);
begin
  FSearchFilter := Query;
  FCurrentPage := 1;
  FetchUsers;
end;

procedure TFormMain.OnEditClick(const UserId: string);
var
  Page: TTina4Page;
begin
  FCurrentUserId := UserId;

  { Find the user in MemTable }
  if MemUsers.Locate('id', UserId) then
  begin
    Page := Pages.Pages.FindPage('user-edit');
    if not Assigned(Page) then
    begin
      Page := Pages.Pages.Add;
      Page.PageName := 'user-edit';
    end;

    Page.HTMLContent.Text :=
      '<div style="font-family: Arial; padding: 20px; max-width: 600px;">' +
      '  <h2 style="color: #2c3e50;">Edit User</h2>' +
      '  <div style="margin-bottom: 15px;">' +
      '    <label style="display: block; margin-bottom: 5px;">Name</label>' +
      '    <input type="text" id="editName" ' +
      '      value="' + MemUsers.FieldByName('name').AsString + '" ' +
      '      style="width: 100%; padding: 10px; border: 1px solid #ddd; ' +
      '      border-radius: 4px;">' +
      '  </div>' +
      '  <div style="margin-bottom: 15px;">' +
      '    <label style="display: block; margin-bottom: 5px;">Email</label>' +
      '    <input type="text" id="editEmail" ' +
      '      value="' + MemUsers.FieldByName('email').AsString + '" ' +
      '      style="width: 100%; padding: 10px; border: 1px solid #ddd; ' +
      '      border-radius: 4px;">' +
      '  </div>' +
      '  <div style="margin-bottom: 20px;">' +
      '    <label style="display: block; margin-bottom: 5px;">Role</label>' +
      '    <select id="editRole" style="width: 100%; padding: 10px; ' +
      '      border: 1px solid #ddd; border-radius: 4px;">' +
      '      <option value="user">User</option>' +
      '      <option value="admin">Admin</option>' +
      '      <option value="editor">Editor</option>' +
      '    </select>' +
      '  </div>' +
      '  <button onclick="App:HandleSaveUser(' +
      '    document.getElementById(''editName'').value)" ' +
      '    style="padding: 10px 20px; background: #3498db; color: white; ' +
      '    border: none; border-radius: 4px; cursor: pointer; ' +
      '    margin-right: 10px;">Save</button>' +
      '  <button onclick="App:NavigateTo(''users'')" ' +
      '    style="padding: 10px 20px; background: #95a5a6; color: white; ' +
      '    border: none; border-radius: 4px; cursor: pointer;">Cancel</button>' +
      '</div>';

    Pages.NavigateTo('user-edit');
  end;
end;

procedure TFormMain.OnDeleteClick(const UserId: string);
begin
  { In a real app, show a confirmation dialog first }
  DeleteUser(UserId);
end;

procedure TFormMain.OnPageClick(const Page: string);
var
  NewPage: Integer;
begin
  NewPage := StrToIntDef(Page, 1);
  if NewPage < 1 then NewPage := 1;
  FCurrentPage := NewPage;
  FetchUsers;
end;

procedure TFormMain.HandleSaveUser(const FormData: string);
begin
  { FormData contains the name; in a real app, read all fields }
  var Name := Renderer.GetElementValue('editName');
  var Email := Renderer.GetElementValue('editEmail');
  var Role := Renderer.GetElementValue('editRole');

  if FCurrentUserId.IsEmpty then
    CreateUser(Name, Email, Role)
  else
    UpdateUser(FCurrentUserId, Name, Email, Role);
end;
```

---

## 11. Notifications

```pascal
procedure TFormMain.ShowNotification(const Msg: string; IsError: Boolean);
var
  BgColor: string;
begin
  if IsError then
    BgColor := '#e74c3c'
  else
    BgColor := '#2ecc71';

  { Update the notification area on the current page }
  Renderer.SetElementVisible('notificationArea', True);
  Renderer.SetElementStyle('notificationArea', 'background-color', BgColor);
  Renderer.SetElementStyle('notificationArea', 'color', 'white');
  Renderer.SetElementText('notificationArea', Msg);

  { Auto-hide after 3 seconds }
  TTask.Run(procedure
  begin
    Sleep(3000);
    TThread.Synchronize(nil, procedure
    begin
      Renderer.SetElementVisible('notificationArea', False);
    end);
  end);
end;
```

The notification uses DOM manipulation to show and hide a div. No page rebuild needed. The `SetElementVisible`, `SetElementStyle`, and `SetElementText` methods update the rendered HTML in place. A background task hides it after three seconds.

---

## 12. WebSocket Notifications

Add a WebSocket connection for real-time updates. If your API supports WebSocket, add this to `FormCreate`:

```pascal
procedure TFormMain.SetupWebSocket;
begin
  { WebSocket for real-time notifications }
  { Note: TTina4WebSocketClient is a separate component }
  FWebSocket := TTina4WebSocketClient.Create(Self);
  FWebSocket.URL := 'wss://api.example.com/ws/notifications';

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
          Inc(FNotificationCount);
          var NotifText := JSON.GetValue<string>('message', 'New notification');
          ShowNotification(NotifText);

          { If on dashboard, refresh stats }
          if Pages.ActivePage = 'dashboard' then
            FetchStats;
        end;
      finally
        JSON.Free;
      end;
    end);
  end;

  FWebSocket.OnDisconnect := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      ShowNotification('Connection lost. Reconnecting...', True);
    end);
  end;

  FWebSocket.AutoReconnect := True;
  FWebSocket.ReconnectInterval := 5000;
end;
```

After successful login, connect the WebSocket:

```pascal
procedure TFormMain.DoLogin(const Username, Password: string);
begin
  { ... existing login code ... }

  if StatusCode = 200 then
  begin
    FBearerToken := Response.GetValue<string>('token');
    REST.SetBearer(FBearerToken);

    { Connect WebSocket after auth }
    FWebSocket.Headers.Values['Authorization'] := 'Bearer ' + FBearerToken;
    FWebSocket.Connect;

    Pages.NavigateTo('dashboard');
    FetchStats;
    FetchUsers;
  end;
end;
```

---

## 13. Error Handling

Every REST call in this application handles errors. Here is the complete error handling pattern used throughout:

```pascal
procedure TFormMain.SafeRESTCall(const Method: string; const EndPoint: string;
  const Body: string; OnSuccess: TProc<TJSONObject>);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  try
    case Method.ToUpper.Chars[0] of
      'G': Response := REST.Get(StatusCode, EndPoint, '');
      'P': Response := REST.Post(StatusCode, EndPoint, '', Body);
      'A': Response := REST.Patch(StatusCode, EndPoint, '', Body);
      'D': Response := REST.Delete(StatusCode, EndPoint, '');
    else
      Response := REST.Get(StatusCode, EndPoint, '');
    end;

    try
      case StatusCode of
        200, 201, 204:
          begin
            if Assigned(OnSuccess) then
              OnSuccess(Response);
          end;
        401:
          begin
            ShowNotification('Session expired. Please log in again.', True);
            DoLogout;
          end;
        403:
          ShowNotification('You do not have permission for this action.', True);
        404:
          ShowNotification('The requested resource was not found.', True);
        422:
          begin
            var Msg := 'Validation error.';
            if Assigned(Response) then
              Msg := Response.GetValue<string>('message', Msg);
            ShowNotification(Msg, True);
          end;
      else
        ShowNotification('Server error: ' + StatusCode.ToString, True);
      end;
    finally
      Response.Free;
    end;
  except
    on E: ENetHTTPClientException do
      ShowNotification('Network error: Could not reach server.', True);
    on E: Exception do
      ShowNotification('Unexpected error: ' + E.Message, True);
  end;
end;
```

Usage:

```pascal
procedure TFormMain.FetchStatsWithSafeCall;
begin
  SafeRESTCall('GET', '/stats', '', procedure(Response: TJSONObject)
  begin
    PopulateMemTableFromJSON(MemStats, 'stats', Response.ToString);
    var Page := Pages.Pages.FindPage('dashboard');
    if Assigned(Page) then
      Page.HTMLContent.Text := BuildStatsHTML;
  end);
end;
```

---

## 14. Using Twig Templates Instead of String Concatenation

The inline HTML strings above work but become unwieldy. For production applications, use Twig template files. Here is the dashboard page as a Twig template:

```html
{# templates/dashboard.html #}
{% extends 'layout.html' %}

{% block title %}Dashboard{% endblock %}

{% block content %}
<div style="display: flex; gap: 20px; margin-bottom: 30px;">
  {% for stat in stats %}
  <div style="flex: 1; background: {{ stat.color }}; color: white;
    padding: 20px; border-radius: 8px;">
    <p style="font-size: 14px; margin: 0; opacity: 0.8;">{{ stat.label }}</p>
    <p style="font-size: 36px; margin: 5px 0 0 0; font-weight: bold;">
      {{ stat.value }}
    </p>
  </div>
  {% endfor %}
</div>

<div id="notificationArea" style="display: none;
  padding: 10px; border-radius: 4px; margin-bottom: 20px;">
</div>
{% endblock %}
```

```html
{# templates/layout.html #}
<div style="font-family: Arial; padding: 20px;">
  <div style="display: flex; justify-content: space-between;
    align-items: center; margin-bottom: 30px; padding-bottom: 15px;
    border-bottom: 2px solid #ecf0f1;">
    <h1 style="margin: 0; color: #2c3e50;">{% block title %}{% endblock %}</h1>
    <div>
      <span onclick="App:NavigateTo('dashboard')"
        style="margin-right: 15px; color: #7f8c8d; cursor: pointer;">Dashboard</span>
      <span onclick="App:NavigateTo('users')"
        style="margin-right: 15px; color: #7f8c8d; cursor: pointer;">Users</span>
      <span onclick="App:NavigateTo('settings')"
        style="margin-right: 15px; color: #7f8c8d; cursor: pointer;">Settings</span>
      <span onclick="App:DoLogout"
        style="color: #e74c3c; cursor: pointer;">Logout</span>
    </div>
  </div>
  {% block content %}{% endblock %}
</div>
```

Use Twig pages in your TTina4HTMLPages:

```pascal
procedure TFormMain.SetupDashboardPageWithTwig;
var
  Page: TTina4Page;
begin
  Page := Pages.Pages.Add;
  Page.PageName := 'dashboard';
  Page.TwigContent.LoadFromFile(
    TPath.Combine(Pages.TwigTemplatePath, 'dashboard.html'));
end;

procedure TFormMain.FetchStatsWithTwig;
begin
  RESTStats.OnExecuteDone := procedure(Sender: TObject)
  begin
    TThread.Synchronize(nil, procedure
    begin
      { Set Twig variables from MemTable data }
      Pages.SetTwigVariable('stats',
        '[' +
        '{"label": "Total Users", "value": "' +
          MemStats.FieldByName('user_count').AsString +
          '", "color": "#3498db"},' +
        '{"label": "Active Sessions", "value": "' +
          MemStats.FieldByName('active_sessions').AsString +
          '", "color": "#2ecc71"},' +
        '{"label": "Revenue", "value": "$' +
          MemStats.FieldByName('revenue').AsString +
          '", "color": "#9b59b6"},' +
        '{"label": "Orders", "value": "' +
          MemStats.FieldByName('order_count').AsString +
          '", "color": "#e67e22"}' +
        ']');

      if Pages.ActivePage = 'dashboard' then
        Pages.NavigateTo('dashboard');
    end);
  end;
  RESTStats.ExecuteRESTCallAsync;
end;
```

---

## 15. Project Organization

For a production application, organize your project like this:

```
AdminDashboard/
  AdminDashboard.dpr
  AdminDashboard.dproj
  src/
    MainUnit.pas              -- Main form, page setup, navigation
    MainUnit.fmx              -- FMX form with all components
    DataModule.pas            -- REST components, MemTables
    DataModule.dfm            -- DataModule design file
    Auth.pas                  -- Authentication logic
    UserOperations.pas        -- User CRUD operations
  templates/
    layout.html               -- Shared layout with navigation
    login.html                -- Login page
    dashboard.html            -- Dashboard with stat cards
    users.html                -- User list with table
    user-edit.html            -- User edit form
    settings.html             -- Settings form
  ssl/
    libeay32.dll              -- 32-bit SSL (for IDE)
    ssleay32.dll
    libcrypto-3-x64.dll       -- 64-bit SSL (for compiled app)
    libssl-3-x64.dll
```

Move REST components to a data module so the main form stays focused on UI:

```pascal
// DataModule.pas
unit DataModule;

interface

uses
  System.SysUtils, System.Classes,
  FireDAC.Comp.Client, Data.DB,
  Tina4REST, Tina4RESTRequest;

type
  TDM = class(TDataModule)
    REST: TTina4REST;
    RESTUsers: TTina4RESTRequest;
    RESTStats: TTina4RESTRequest;
    MemUsers: TFDMemTable;
    MemStats: TFDMemTable;
    DSUsers: TDataSource;
    procedure DataModuleCreate(Sender: TObject);
  private
    FToken: string;
  public
    procedure SetToken(const AToken: string);
    property Token: string read FToken;
  end;

var
  DM: TDM;

implementation

{$R *.dfm}

procedure TDM.DataModuleCreate(Sender: TObject);
begin
  REST.BaseUrl := 'https://api.example.com/v1';
  RESTUsers.Tina4REST := REST;
  RESTUsers.EndPoint := '/users';
  RESTUsers.DataKey := 'records';
  RESTUsers.MemTable := MemUsers;
  RESTStats.Tina4REST := REST;
  RESTStats.EndPoint := '/stats';
  RESTStats.DataKey := 'stats';
  RESTStats.MemTable := MemStats;
  DSUsers.DataSet := MemUsers;
end;

procedure TDM.SetToken(const AToken: string);
begin
  FToken := AToken;
  REST.SetBearer(AToken);
end;

end.
```

---

## Summary

This chapter built a complete admin dashboard using:

- **TTina4REST** for API authentication and HTTP calls
- **TTina4RESTRequest** for declarative data fetching into MemTables
- **TTina4HTMLRender** for rendering the entire UI as styled HTML
- **TTina4HTMLPages** for SPA-style page navigation
- **Twig templates** for maintainable, dynamic HTML
- **RTTI onclick** for bridging HTML events to Pascal methods
- **WebSocket** for real-time notifications
- **DOM manipulation** for in-place UI updates without full re-renders

The data flows in one direction: API response goes into a MemTable, MemTable data is rendered into HTML, user actions in HTML call Pascal methods via RTTI, and those methods make API calls that restart the cycle. This unidirectional flow makes the application predictable and debuggable.

Every pattern shown here -- authentication guards, async data loading, error handling, notification toasts -- is reusable in any Tina4 Delphi application. The admin dashboard is not just an example. It is a template for how to build desktop applications that talk to REST APIs.
