# Chapter 5: Page Navigation

## A Single-Page App Inside Your Desktop App

Your application has a dashboard, a user management page, a settings page, and a reports page. In a traditional Delphi app, you create four forms and show/hide them. With `TTina4HTMLPages`, you create four pages inside one HTML renderer and navigate between them with anchor links -- the same way a single-page web app works.

No form switching. No component visibility toggling. No frame loading. Just set the HTML for each page, link them to a renderer, and navigate with `<a href="#pagename">` or programmatic calls.

---

## 1. TTina4HTMLPages Basics

`TTina4HTMLPages` manages a collection of pages and renders them through a `TTina4HTMLRender`. Each page has a name, HTML content (or Twig template content), and an optional "is default" flag.

### Setup

Drop two components on your form:

1. **TTina4HTMLRender** (name: `HTMLRender1`) -- set `Align` to `Client`
2. **TTina4HTMLPages** (name: `HTMLPages1`)

Link them:

```pascal
HTMLPages1.Renderer := HTMLRender1;
```

That is the entire setup. The pages component controls what the renderer displays.

---

## 2. Creating Pages at Design Time

Double-click `HTMLPages1` in the form designer to open the collection editor. Click "Add" to create pages:

**Page 1:**
- `PageName`: `home`
- `IsDefault`: `True`
- `HTMLContent`: `<h1>Home</h1><p>Welcome to the app.</p><a href="#settings">Go to Settings</a>`

**Page 2:**
- `PageName`: `settings`
- `IsDefault`: `False`
- `HTMLContent`: `<h1>Settings</h1><p>Configure your preferences.</p><a href="#home">Back to Home</a>`

Run the app. The home page appears (it has `IsDefault = True`). Click "Go to Settings". The settings page appears. Click "Back to Home". You are back. No code written.

---

## 3. Creating Pages at Runtime

For dynamic apps where pages are built from data or configuration:

```pascal
procedure TForm1.FormCreate(Sender: TObject);
var
  Page: TTina4Page;
begin
  HTMLPages1.Renderer := HTMLRender1;

  // Home page
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'home';
  Page.IsDefault := True;
  Page.HTMLContent.Text :=
    '<style>' +
    '  .nav { background: #1a1a2e; padding: 12px 20px; }' +
    '  .nav a { color: white; margin-right: 16px; text-decoration: none; }' +
    '  .content { padding: 20px; }' +
    '</style>' +
    '<div class="nav">' +
    '  <a href="#home">Home</a>' +
    '  <a href="#users">Users</a>' +
    '  <a href="#settings">Settings</a>' +
    '</div>' +
    '<div class="content">' +
    '  <h1>Dashboard</h1>' +
    '  <p>Welcome back. Select a section from the navigation above.</p>' +
    '</div>';

  // Users page
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'users';
  Page.HTMLContent.Text :=
    '<div class="nav">' +
    '  <a href="#home">Home</a>' +
    '  <a href="#users">Users</a>' +
    '  <a href="#settings">Settings</a>' +
    '</div>' +
    '<div class="content">' +
    '  <h1>Users</h1>' +
    '  <p>User management goes here.</p>' +
    '</div>';

  // Settings page
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'settings';
  Page.HTMLContent.Text :=
    '<div class="nav">' +
    '  <a href="#home">Home</a>' +
    '  <a href="#users">Users</a>' +
    '  <a href="#settings">Settings</a>' +
    '</div>' +
    '<div class="content">' +
    '  <h1>Settings</h1>' +
    '  <p>Application settings go here.</p>' +
    '</div>';
end;
```

---

## 4. Setting the Default Page

The page with `IsDefault := True` renders automatically when the component initializes. If no page has `IsDefault` set, nothing renders until you navigate programmatically.

```pascal
Page.IsDefault := True;
```

Only one page should have `IsDefault = True`. If multiple pages have it set, the first one in the collection wins.

---

## 5. Navigation via Anchor Links

The most natural way to navigate is with HTML anchor tags. The `href` value maps to a page name:

| `href` value | Maps to PageName |
|---|---|
| `#dashboard` | `dashboard` |
| `/settings` | `settings` |
| `about` | `about` |

The renderer intercepts link clicks and delegates to the pages component. The leading `#` or `/` is stripped to match the `PageName`.

```html
<a href="#home">Home</a>
<a href="#users">Users</a>
<a href="/settings">Settings</a>
```

All three formats work. The `#` prefix is conventional for SPA-style navigation. The `/` prefix works the same way. A bare name also works.

---

## 6. Programmatic Navigation

Navigate from Delphi code without user interaction:

```pascal
HTMLPages1.NavigateTo('settings');
```

This is useful for:
- Redirecting after a successful action (e.g., login redirects to dashboard)
- Responding to button clicks that are not anchor tags
- Implementing back/forward functionality
- Conditional navigation based on business logic

```pascal
procedure TForm1.OnLoginSuccess;
begin
  HTMLPages1.NavigateTo('dashboard');
end;

procedure TForm1.OnLogout;
begin
  HTMLPages1.NavigateTo('login');
end;
```

### Reading the Active Page

```pascal
var CurrentPage := HTMLPages1.ActivePage;
if CurrentPage = 'settings' then
  ShowMessage('You are on the settings page');
```

---

## 7. Page Properties

Each `TTina4Page` in the collection has these properties:

| Property | Type | Description |
|---|---|---|
| `PageName` | `string` | Unique name used as navigation target |
| `TwigContent` | `TStringList` | Twig template source (rendered via TTina4Twig) |
| `HTMLContent` | `TStringList` | Raw HTML (used when TwigContent is empty) |
| `IsDefault` | `Boolean` | If `True`, this page is shown on startup |

**Priority rule**: If `TwigContent` is not empty, it is rendered through the Twig engine and the result replaces `HTMLContent`. If `TwigContent` is empty, `HTMLContent` is used directly.

---

## 8. Component Properties

`TTina4HTMLPages` itself has these properties:

| Property | Type | Description |
|---|---|---|
| `Pages` | `TTina4PageCollection` | Collection of pages (design-time editable) |
| `Renderer` | `TTina4HTMLRender` | The HTML renderer that displays the active page |
| `ActivePage` | `string` | Name of the currently displayed page (read/write) |
| `TwigTemplatePath` | `string` | Base path for Twig `{% include %}` / `{% extends %}` |

---

## 9. Events

### OnBeforeNavigate

Fires before navigation occurs. Set `Allow := False` to cancel the navigation:

```pascal
procedure TForm1.HTMLPages1BeforeNavigate(Sender: TObject;
  const FromPage, ToPage: string; var Allow: Boolean);
begin
  // Prevent navigation to admin page if not authenticated
  if (ToPage = 'admin') and (not FIsAuthenticated) then
  begin
    Allow := False;
    ShowMessage('You must log in to access the admin page.');
    HTMLPages1.NavigateTo('login');
  end;
end;
```

### OnAfterNavigate

Fires after the new page has been rendered. Use it for post-navigation setup like loading data:

```pascal
procedure TForm1.HTMLPages1AfterNavigate(Sender: TObject);
begin
  if HTMLPages1.ActivePage = 'users' then
    LoadUserData;
  if HTMLPages1.ActivePage = 'dashboard' then
    RefreshStats;
end;
```

---

## 10. Using Twig Templates in Pages

Pages can use Twig templates for dynamic content. Set variables with `SetTwigVariable` and use Twig syntax in `TwigContent`:

```pascal
HTMLPages1.SetTwigVariable('userName', 'Alice');
HTMLPages1.SetTwigVariable('userRole', 'Admin');
HTMLPages1.SetTwigVariable('notificationCount', '3');

var Page := HTMLPages1.Pages.Add;
Page.PageName := 'dashboard';
Page.TwigContent.Text :=
  '<div class="header">' +
  '  <h1>Welcome, {{ userName }}</h1>' +
  '  <span>Role: {{ userRole }}</span>' +
  '  {% if notificationCount > 0 %}' +
  '    <span class="badge">{{ notificationCount }} new</span>' +
  '  {% endif %}' +
  '</div>';
```

### File-Based Templates

For complex pages, use files with `{% include %}` and `{% extends %}`:

```pascal
HTMLPages1.TwigTemplatePath := 'C:\MyApp\templates';

var Page := HTMLPages1.Pages.Add;
Page.PageName := 'report';
Page.TwigContent.LoadFromFile('C:\MyApp\templates\report.html');
```

**report.html:**
```
{% extends 'layout.html' %}

{% block title %}Monthly Report{% endblock %}

{% block content %}
  <h1>Report for {{ month }}</h1>
  <table>
    {% for row in data %}
    <tr>
      <td>{{ row.name }}</td>
      <td>{{ row.value }}</td>
    </tr>
    {% endfor %}
  </table>
{% endblock %}
```

**layout.html:**
```
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; }
    .nav { background: #333; padding: 12px; }
    .nav a { color: white; margin-right: 16px; }
  </style>
</head>
<body>
  <div class="nav">
    <a href="#home">Home</a>
    <a href="#report">Report</a>
    <a href="#settings">Settings</a>
  </div>
  <div style="padding: 20px;">
    <title>{% block title %}{% endblock %}</title>
    {% block content %}{% endblock %}
  </div>
</body>
</html>
```

---

## 11. Complete Example: Multi-Page Admin App

A full admin application with a sidebar menu, dashboard page, users page with a data table, and settings page with a form.

```pascal
unit AdminApp;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls,
  Tina4HTMLRender, Tina4HTMLPages, Tina4REST;

type
  TfrmAdmin = class(TForm)
    HTMLRender1: TTina4HTMLRender;
    HTMLPages1: TTina4HTMLPages;
    restAPI: TTina4REST;
    procedure FormCreate(Sender: TObject);
    procedure HTMLPages1AfterNavigate(Sender: TObject);
    procedure HTMLRender1FormSubmit(Sender: TObject;
      const FormName: string; FormData: TStrings);
  private
    function BuildLayout(const ActivePage, Content: string): string;
    function GetSidebar(const ActivePage: string): string;
    function GetStyles: string;
    procedure SetupPages;
  published
    procedure NavTo(PageName: String);
    procedure EditUser(UserId: String);
    procedure SaveSettings(Action: String);
  end;

var
  frmAdmin: TfrmAdmin;

implementation

{$R *.fmx}

procedure TfrmAdmin.FormCreate(Sender: TObject);
begin
  restAPI.BaseUrl := 'https://api.example.com/v1';
  HTMLPages1.Renderer := HTMLRender1;
  HTMLRender1.RegisterObject('Admin', Self);
  SetupPages;
end;

function TfrmAdmin.GetStyles: string;
begin
  Result :=
    '<style>' +
    '  * { box-sizing: border-box; margin: 0; padding: 0; }' +
    '  body { font-family: Arial, sans-serif; display: inline-block; width: 100%; }' +
    '  .sidebar { display: inline-block; width: 200px; background: #1a1a2e;' +
    '    min-height: 600px; padding: 20px 0; vertical-align: top; }' +
    '  .sidebar h3 { color: #7c8db5; padding: 0 20px 16px; font-size: 12px;' +
    '    text-transform: uppercase; letter-spacing: 1px; }' +
    '  .sidebar a { display: block; color: #a0aec0; padding: 10px 20px;' +
    '    text-decoration: none; font-size: 14px; }' +
    '  .sidebar a:hover, .sidebar a.active { background: #16213e; color: white; }' +
    '  .main { display: inline-block; width: calc(100% - 220px); padding: 24px;' +
    '    vertical-align: top; }' +
    '  .page-title { font-size: 24px; color: #1a1a2e; margin-bottom: 20px; }' +
    '  .card { background: white; border: 1px solid #e2e8f0; border-radius: 8px;' +
    '    padding: 20px; margin-bottom: 16px; }' +
    '  .stat-row { display: inline-block; width: 100%; margin-bottom: 20px; }' +
    '  .stat { display: inline-block; width: 30%; margin-right: 3%;' +
    '    background: #f8fafc; border-radius: 8px; padding: 16px; text-align: center; }' +
    '  .stat .number { font-size: 32px; font-weight: bold; color: #2563eb; }' +
    '  .stat .label { font-size: 12px; color: #888; margin-top: 4px; }' +
    '  table { width: 100%; border-collapse: collapse; }' +
    '  th { text-align: left; padding: 10px; border-bottom: 2px solid #e2e8f0;' +
    '    font-size: 12px; color: #888; text-transform: uppercase; }' +
    '  td { padding: 10px; border-bottom: 1px solid #f0f0f0; }' +
    '  .btn { padding: 6px 14px; border: none; border-radius: 4px; font-size: 13px; }' +
    '  .btn-primary { background: #2563eb; color: white; }' +
    '  .btn-sm { padding: 4px 10px; font-size: 12px; }' +
    '  .form-group { margin-bottom: 16px; }' +
    '  .form-group label { display: block; margin-bottom: 4px; font-weight: bold;' +
    '    font-size: 14px; color: #555; }' +
    '  .form-group input, .form-group select { width: 100%; padding: 8px;' +
    '    border: 1px solid #ddd; border-radius: 4px; }' +
    '</style>';
end;

function TfrmAdmin.GetSidebar(const ActivePage: string): string;

  function ActiveClass(const Page: string): string;
  begin
    if Page = ActivePage then
      Result := ' class="active"'
    else
      Result := '';
  end;

begin
  Result :=
    '<div class="sidebar">' +
    '  <h3>Navigation</h3>' +
    '  <a href="#dashboard"' + ActiveClass('dashboard') + '>Dashboard</a>' +
    '  <a href="#users"' + ActiveClass('users') + '>Users</a>' +
    '  <a href="#settings"' + ActiveClass('settings') + '>Settings</a>' +
    '</div>';
end;

function TfrmAdmin.BuildLayout(const ActivePage, Content: string): string;
begin
  Result := GetStyles +
    '<div>' +
    GetSidebar(ActivePage) +
    '<div class="main">' + Content + '</div>' +
    '</div>';
end;

procedure TfrmAdmin.SetupPages;
var
  Page: TTina4Page;
begin
  // Dashboard
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'dashboard';
  Page.IsDefault := True;
  Page.HTMLContent.Text := BuildLayout('dashboard',
    '<h1 class="page-title">Dashboard</h1>' +
    '<div class="stat-row">' +
    '  <div class="stat">' +
    '    <div class="number" id="userCount">248</div>' +
    '    <div class="label">Total Users</div>' +
    '  </div>' +
    '  <div class="stat">' +
    '    <div class="number" id="activeCount">189</div>' +
    '    <div class="label">Active</div>' +
    '  </div>' +
    '  <div class="stat">' +
    '    <div class="number" id="newCount">12</div>' +
    '    <div class="label">New Today</div>' +
    '  </div>' +
    '</div>' +
    '<div class="card">' +
    '  <h3>Recent Activity</h3>' +
    '  <table>' +
    '    <tr><td>Alice logged in</td><td style="color:#888;">2 min ago</td></tr>' +
    '    <tr><td>Bob updated profile</td><td style="color:#888;">15 min ago</td></tr>' +
    '    <tr><td>Carol created a report</td><td style="color:#888;">1 hour ago</td></tr>' +
    '  </table>' +
    '</div>');

  // Users
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'users';
  Page.HTMLContent.Text := BuildLayout('users',
    '<h1 class="page-title">User Management</h1>' +
    '<div class="card">' +
    '  <table>' +
    '    <thead>' +
    '      <tr><th>Name</th><th>Email</th><th>Role</th><th>Status</th><th>Actions</th></tr>' +
    '    </thead>' +
    '    <tbody>' +
    '      <tr>' +
    '        <td>Alice Smith</td><td>alice@example.com</td><td>Admin</td>' +
    '        <td style="color:green;">Active</td>' +
    '        <td><button class="btn btn-sm btn-primary" ' +
    '          onclick="Admin:EditUser(''1'')">Edit</button></td>' +
    '      </tr>' +
    '      <tr>' +
    '        <td>Bob Johnson</td><td>bob@example.com</td><td>Editor</td>' +
    '        <td style="color:green;">Active</td>' +
    '        <td><button class="btn btn-sm btn-primary" ' +
    '          onclick="Admin:EditUser(''2'')">Edit</button></td>' +
    '      </tr>' +
    '      <tr>' +
    '        <td>Carol Williams</td><td>carol@example.com</td><td>Viewer</td>' +
    '        <td style="color:red;">Inactive</td>' +
    '        <td><button class="btn btn-sm btn-primary" ' +
    '          onclick="Admin:EditUser(''3'')">Edit</button></td>' +
    '      </tr>' +
    '    </tbody>' +
    '  </table>' +
    '</div>');

  // Settings
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'settings';
  Page.HTMLContent.Text := BuildLayout('settings',
    '<h1 class="page-title">Settings</h1>' +
    '<div class="card">' +
    '  <form name="settingsForm">' +
    '    <div class="form-group">' +
    '      <label>Application Name</label>' +
    '      <input type="text" name="appName" id="appName" value="My Admin App">' +
    '    </div>' +
    '    <div class="form-group">' +
    '      <label>Default Language</label>' +
    '      <select name="language" id="language">' +
    '        <option value="en">English</option>' +
    '        <option value="fr">French</option>' +
    '        <option value="de">German</option>' +
    '      </select>' +
    '    </div>' +
    '    <div class="form-group">' +
    '      <label>Items Per Page</label>' +
    '      <input type="text" name="pageSize" id="pageSize" value="25">' +
    '    </div>' +
    '    <button type="submit" class="btn btn-primary">Save Settings</button>' +
    '  </form>' +
    '</div>');
end;

procedure TfrmAdmin.HTMLPages1AfterNavigate(Sender: TObject);
begin
  // Load data when navigating to specific pages
  if HTMLPages1.ActivePage = 'dashboard' then
  begin
    // Could refresh stats from API here
  end;
end;

procedure TfrmAdmin.HTMLRender1FormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
begin
  if FormName = 'settingsForm' then
  begin
    ShowMessage(Format('Settings saved: App=%s, Lang=%s, PageSize=%s',
      [FormData.Values['appName'],
       FormData.Values['language'],
       FormData.Values['pageSize']]));
  end;
end;

procedure TfrmAdmin.NavTo(PageName: String);
begin
  HTMLPages1.NavigateTo(PageName);
end;

procedure TfrmAdmin.EditUser(UserId: String);
begin
  ShowMessage('Edit user: ' + UserId);
  // In a real app: navigate to an edit page with the user's data pre-filled
end;

procedure TfrmAdmin.SaveSettings(Action: String);
begin
  ShowMessage('Settings action: ' + Action);
end;

end.
```

---

## 12. Complete Example: Navigation Guards

A login-protected app where users must authenticate before accessing protected pages.

```pascal
unit GuardedApp;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms,
  Tina4HTMLRender, Tina4HTMLPages, Tina4REST;

type
  TfrmGuarded = class(TForm)
    HTMLRender1: TTina4HTMLRender;
    HTMLPages1: TTina4HTMLPages;
    restAPI: TTina4REST;
    procedure FormCreate(Sender: TObject);
    procedure HTMLPages1BeforeNavigate(Sender: TObject;
      const FromPage, ToPage: string; var Allow: Boolean);
    procedure HTMLRender1FormSubmit(Sender: TObject;
      const FormName: string; FormData: TStrings);
  private
    FIsLoggedIn: Boolean;
    FUserName: string;
    procedure SetupPages;
  published
    procedure Logout(Action: String);
  end;

var
  frmGuarded: TfrmGuarded;

implementation

{$R *.fmx}

procedure TfrmGuarded.FormCreate(Sender: TObject);
begin
  FIsLoggedIn := False;
  FUserName := '';
  restAPI.BaseUrl := 'https://api.example.com';
  HTMLPages1.Renderer := HTMLRender1;
  HTMLRender1.RegisterObject('App', Self);
  SetupPages;
end;

procedure TfrmGuarded.SetupPages;
var
  Page: TTina4Page;
begin
  // Login page (the default -- shown first)
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'login';
  Page.IsDefault := True;
  Page.HTMLContent.Text :=
    '<style>' +
    '  .login-box { max-width: 360px; margin: 80px auto; padding: 32px;' +
    '    background: white; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.15); }' +
    '  .login-box h2 { text-align: center; margin-bottom: 24px; color: #333; }' +
    '  .field { margin-bottom: 16px; }' +
    '  .field label { display: block; margin-bottom: 4px; font-size: 14px; color: #555; }' +
    '  .field input { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; }' +
    '  .btn { width: 100%; padding: 12px; background: #2563eb; color: white;' +
    '    border: none; border-radius: 4px; font-size: 16px; }' +
    '  .error { color: #dc2626; font-size: 13px; text-align: center;' +
    '    margin-bottom: 12px; display: none; }' +
    '</style>' +
    '<div class="login-box">' +
    '  <h2>Login Required</h2>' +
    '  <div class="error" id="loginError">Invalid credentials</div>' +
    '  <form name="loginForm">' +
    '    <div class="field">' +
    '      <label>Username</label>' +
    '      <input type="text" name="username" id="username" placeholder="Enter username">' +
    '    </div>' +
    '    <div class="field">' +
    '      <label>Password</label>' +
    '      <input type="password" name="password" id="password" placeholder="Enter password">' +
    '    </div>' +
    '    <button type="submit" class="btn">Sign In</button>' +
    '  </form>' +
    '</div>';

  // Protected: Dashboard
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'dashboard';
  Page.HTMLContent.Text :=
    '<style>' +
    '  .topbar { background: #1a1a2e; color: white; padding: 12px 20px;' +
    '    display: inline-block; width: 100%; }' +
    '  .topbar span { float: left; }' +
    '  .topbar .user { float: right; }' +
    '  .topbar a { color: #93c5fd; margin-left: 16px; }' +
    '  .content { padding: 24px; }' +
    '</style>' +
    '<div class="topbar">' +
    '  <span><b>Admin Panel</b></span>' +
    '  <span class="user">' +
    '    <a href="#profile">Profile</a>' +
    '    <a href="#settings">Settings</a>' +
    '    <span onclick="App:Logout(''now'')" style="color: #fca5a5; cursor: pointer;' +
    '      margin-left: 16px;">Logout</span>' +
    '  </span>' +
    '</div>' +
    '<div class="content">' +
    '  <h1>Dashboard</h1>' +
    '  <p>You are logged in. This is the protected dashboard.</p>' +
    '  <p><a href="#profile">View Profile</a> | <a href="#settings">Settings</a></p>' +
    '</div>';

  // Protected: Profile
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'profile';
  Page.HTMLContent.Text :=
    '<div class="topbar">' +
    '  <span><b>Admin Panel</b></span>' +
    '  <span class="user">' +
    '    <a href="#dashboard">Dashboard</a>' +
    '    <span onclick="App:Logout(''now'')" style="color: #fca5a5; cursor: pointer;' +
    '      margin-left: 16px;">Logout</span>' +
    '  </span>' +
    '</div>' +
    '<div class="content">' +
    '  <h1>Profile</h1>' +
    '  <p>User profile page. Only accessible when logged in.</p>' +
    '  <p><a href="#dashboard">Back to Dashboard</a></p>' +
    '</div>';

  // Protected: Settings
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'settings';
  Page.HTMLContent.Text :=
    '<div class="topbar">' +
    '  <span><b>Admin Panel</b></span>' +
    '  <span class="user">' +
    '    <a href="#dashboard">Dashboard</a>' +
    '    <span onclick="App:Logout(''now'')" style="color: #fca5a5; cursor: pointer;' +
    '      margin-left: 16px;">Logout</span>' +
    '  </span>' +
    '</div>' +
    '<div class="content">' +
    '  <h1>Settings</h1>' +
    '  <p>App settings. Only accessible when logged in.</p>' +
    '  <p><a href="#dashboard">Back to Dashboard</a></p>' +
    '</div>';
end;

procedure TfrmGuarded.HTMLPages1BeforeNavigate(Sender: TObject;
  const FromPage, ToPage: string; var Allow: Boolean);
begin
  // The login page is always accessible
  if ToPage = 'login' then
  begin
    Allow := True;
    Exit;
  end;

  // All other pages require authentication
  if not FIsLoggedIn then
  begin
    Allow := False;
    HTMLPages1.NavigateTo('login');
  end;
end;

procedure TfrmGuarded.HTMLRender1FormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
var
  Username, Password: string;
begin
  if FormName <> 'loginForm' then Exit;

  Username := FormData.Values['username'];
  Password := FormData.Values['password'];

  // Simple validation (in production, call your auth API)
  if (Username = 'admin') and (Password = 'password') then
  begin
    FIsLoggedIn := True;
    FUserName := Username;
    HTMLPages1.NavigateTo('dashboard');
  end
  else
  begin
    HTMLRender1.SetElementVisible('loginError', True);
  end;
end;

procedure TfrmGuarded.Logout(Action: String);
begin
  FIsLoggedIn := False;
  FUserName := '';
  HTMLPages1.NavigateTo('login');
end;

end.
```

---

## 13. Exercise: Wizard / Step-by-Step Form

Build a wizard with 4 pages (steps), Next/Back navigation, and validation before advancing.

### Requirements

1. Step 1: Personal Info (name, email) -- both required
2. Step 2: Address (street, city, zip) -- all required
3. Step 3: Preferences (language dropdown, newsletter checkbox)
4. Step 4: Confirmation (summary of all entered data, submit button)
5. "Next" button validates current step before advancing
6. "Back" button always works (no validation needed)
7. Step indicator showing current position (e.g., "Step 2 of 4")

### Solution

```pascal
unit WizardForm;

interface

uses
  System.SysUtils, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms,
  Tina4HTMLRender, Tina4HTMLPages;

type
  TfrmWizard = class(TForm)
    HTMLRender1: TTina4HTMLRender;
    HTMLPages1: TTina4HTMLPages;
    procedure FormCreate(Sender: TObject);
    procedure HTMLPages1BeforeNavigate(Sender: TObject;
      const FromPage, ToPage: string; var Allow: Boolean);
    procedure HTMLRender1FormSubmit(Sender: TObject;
      const FormName: string; FormData: TStrings);
  private
    FData: TStringList;
    procedure SetupPages;
    function GetStyles: string;
    function StepHeader(Current: Integer): string;
    function ValidateStep(const StepName: string): Boolean;
  published
    procedure GoNext(FromStep: String);
    procedure GoBack(FromStep: String);
  end;

var
  frmWizard: TfrmWizard;

implementation

{$R *.fmx}

procedure TfrmWizard.FormCreate(Sender: TObject);
begin
  FData := TStringList.Create;
  HTMLPages1.Renderer := HTMLRender1;
  HTMLRender1.RegisterObject('Wizard', Self);
  SetupPages;
end;

function TfrmWizard.GetStyles: string;
begin
  Result :=
    '<style>' +
    '  body { font-family: Arial, sans-serif; background: #f5f5f5; }' +
    '  .wizard { max-width: 500px; margin: 30px auto; background: white;' +
    '    border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); overflow: hidden; }' +
    '  .steps { display: inline-block; width: 100%; background: #f8f9fa;' +
    '    padding: 16px 20px; border-bottom: 1px solid #e0e0e0; }' +
    '  .step-dot { display: inline-block; width: 30px; height: 30px; border-radius: 50%;' +
    '    background: #ddd; color: #888; text-align: center; line-height: 30px;' +
    '    font-size: 14px; margin-right: 8px; }' +
    '  .step-dot.active { background: #2563eb; color: white; }' +
    '  .step-dot.done { background: #16a34a; color: white; }' +
    '  .step-label { font-size: 13px; color: #888; margin-left: 4px; margin-right: 20px; }' +
    '  .body { padding: 24px; }' +
    '  .field { margin-bottom: 16px; }' +
    '  .field label { display: block; margin-bottom: 4px; font-weight: bold; font-size: 14px; }' +
    '  .field input, .field select { width: 100%; padding: 8px; border: 1px solid #ccc;' +
    '    border-radius: 4px; }' +
    '  .error-text { color: #dc2626; font-size: 12px; display: none; margin-top: 4px; }' +
    '  .buttons { padding: 16px 24px; border-top: 1px solid #e0e0e0;' +
    '    display: inline-block; width: 100%; }' +
    '  .btn { padding: 8px 20px; border: none; border-radius: 4px; font-size: 14px; }' +
    '  .btn-next { background: #2563eb; color: white; float: right; }' +
    '  .btn-back { background: #e2e8f0; color: #333; float: left; }' +
    '  .btn-submit { background: #16a34a; color: white; float: right; }' +
    '  .summary-row { padding: 8px 0; border-bottom: 1px solid #f0f0f0; }' +
    '  .summary-label { font-weight: bold; color: #555; display: inline-block; width: 120px; }' +
    '</style>';
end;

function TfrmWizard.StepHeader(Current: Integer): string;
var
  Labels: array[1..4] of string;
  I: Integer;
  CSSClass: string;
begin
  Labels[1] := 'Personal';
  Labels[2] := 'Address';
  Labels[3] := 'Preferences';
  Labels[4] := 'Confirm';

  Result := '<div class="steps">';
  for I := 1 to 4 do
  begin
    if I < Current then
      CSSClass := 'step-dot done'
    else if I = Current then
      CSSClass := 'step-dot active'
    else
      CSSClass := 'step-dot';

    Result := Result +
      Format('<span class="%s">%d</span><span class="step-label">%s</span>',
        [CSSClass, I, Labels[I]]);
  end;
  Result := Result + '</div>';
end;

procedure TfrmWizard.SetupPages;
var
  Page: TTina4Page;
begin
  // Step 1: Personal Info
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'step1';
  Page.IsDefault := True;
  Page.HTMLContent.Text := GetStyles +
    '<div class="wizard">' +
    StepHeader(1) +
    '<div class="body">' +
    '  <h2>Personal Information</h2>' +
    '  <div class="field">' +
    '    <label>Full Name</label>' +
    '    <input type="text" name="name" id="name" placeholder="Your name">' +
    '    <div class="error-text" id="nameError">Name is required</div>' +
    '  </div>' +
    '  <div class="field">' +
    '    <label>Email</label>' +
    '    <input type="email" name="email" id="email" placeholder="you@example.com">' +
    '    <div class="error-text" id="emailError">Valid email is required</div>' +
    '  </div>' +
    '</div>' +
    '<div class="buttons">' +
    '  <button class="btn btn-next" onclick="Wizard:GoNext(''step1'')">Next</button>' +
    '</div>' +
    '</div>';

  // Step 2: Address
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'step2';
  Page.HTMLContent.Text := GetStyles +
    '<div class="wizard">' +
    StepHeader(2) +
    '<div class="body">' +
    '  <h2>Address</h2>' +
    '  <div class="field">' +
    '    <label>Street</label>' +
    '    <input type="text" name="street" id="street">' +
    '    <div class="error-text" id="streetError">Street is required</div>' +
    '  </div>' +
    '  <div class="field">' +
    '    <label>City</label>' +
    '    <input type="text" name="city" id="city">' +
    '    <div class="error-text" id="cityError">City is required</div>' +
    '  </div>' +
    '  <div class="field">' +
    '    <label>Zip Code</label>' +
    '    <input type="text" name="zip" id="zip">' +
    '    <div class="error-text" id="zipError">Zip code is required</div>' +
    '  </div>' +
    '</div>' +
    '<div class="buttons">' +
    '  <button class="btn btn-back" onclick="Wizard:GoBack(''step2'')">Back</button>' +
    '  <button class="btn btn-next" onclick="Wizard:GoNext(''step2'')">Next</button>' +
    '</div>' +
    '</div>';

  // Step 3: Preferences
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'step3';
  Page.HTMLContent.Text := GetStyles +
    '<div class="wizard">' +
    StepHeader(3) +
    '<div class="body">' +
    '  <h2>Preferences</h2>' +
    '  <div class="field">' +
    '    <label>Preferred Language</label>' +
    '    <select name="language" id="language">' +
    '      <option value="en">English</option>' +
    '      <option value="fr">French</option>' +
    '      <option value="de">German</option>' +
    '      <option value="es">Spanish</option>' +
    '    </select>' +
    '  </div>' +
    '  <div class="field">' +
    '    <input type="checkbox" name="newsletter" id="newsletter">' +
    '    <label style="display: inline; font-weight: normal;">Subscribe to newsletter</label>' +
    '  </div>' +
    '</div>' +
    '<div class="buttons">' +
    '  <button class="btn btn-back" onclick="Wizard:GoBack(''step3'')">Back</button>' +
    '  <button class="btn btn-next" onclick="Wizard:GoNext(''step3'')">Next</button>' +
    '</div>' +
    '</div>';

  // Step 4: Confirmation
  Page := HTMLPages1.Pages.Add;
  Page.PageName := 'step4';
  Page.HTMLContent.Text := GetStyles +
    '<div class="wizard">' +
    StepHeader(4) +
    '<div class="body">' +
    '  <h2>Confirm Your Details</h2>' +
    '  <div id="summaryContent">' +
    '    <div class="summary-row"><span class="summary-label">Name:</span> <span id="sumName">-</span></div>' +
    '    <div class="summary-row"><span class="summary-label">Email:</span> <span id="sumEmail">-</span></div>' +
    '    <div class="summary-row"><span class="summary-label">Street:</span> <span id="sumStreet">-</span></div>' +
    '    <div class="summary-row"><span class="summary-label">City:</span> <span id="sumCity">-</span></div>' +
    '    <div class="summary-row"><span class="summary-label">Zip:</span> <span id="sumZip">-</span></div>' +
    '    <div class="summary-row"><span class="summary-label">Language:</span> <span id="sumLang">-</span></div>' +
    '    <div class="summary-row"><span class="summary-label">Newsletter:</span> <span id="sumNews">-</span></div>' +
    '  </div>' +
    '</div>' +
    '<div class="buttons">' +
    '  <button class="btn btn-back" onclick="Wizard:GoBack(''step4'')">Back</button>' +
    '  <form name="wizardSubmit" style="display:inline; float:right;">' +
    '    <button type="submit" class="btn btn-submit">Submit</button>' +
    '  </form>' +
    '</div>' +
    '</div>';
end;

function TfrmWizard.ValidateStep(const StepName: string): Boolean;
begin
  Result := True;

  if StepName = 'step1' then
  begin
    var Name := HTMLRender1.GetElementValue('name');
    var Email := HTMLRender1.GetElementValue('email');

    if Name.Trim = '' then
    begin
      HTMLRender1.SetElementVisible('nameError', True);
      Result := False;
    end
    else
      HTMLRender1.SetElementVisible('nameError', False);

    if (Email.Trim = '') or (not Email.Contains('@')) then
    begin
      HTMLRender1.SetElementVisible('emailError', True);
      Result := False;
    end
    else
      HTMLRender1.SetElementVisible('emailError', False);

    if Result then
    begin
      FData.Values['name'] := Name;
      FData.Values['email'] := Email;
    end;
  end

  else if StepName = 'step2' then
  begin
    var Street := HTMLRender1.GetElementValue('street');
    var City := HTMLRender1.GetElementValue('city');
    var Zip := HTMLRender1.GetElementValue('zip');

    if Street.Trim = '' then
    begin
      HTMLRender1.SetElementVisible('streetError', True);
      Result := False;
    end
    else
      HTMLRender1.SetElementVisible('streetError', False);

    if City.Trim = '' then
    begin
      HTMLRender1.SetElementVisible('cityError', True);
      Result := False;
    end
    else
      HTMLRender1.SetElementVisible('cityError', False);

    if Zip.Trim = '' then
    begin
      HTMLRender1.SetElementVisible('zipError', True);
      Result := False;
    end
    else
      HTMLRender1.SetElementVisible('zipError', False);

    if Result then
    begin
      FData.Values['street'] := Street;
      FData.Values['city'] := City;
      FData.Values['zip'] := Zip;
    end;
  end

  else if StepName = 'step3' then
  begin
    FData.Values['language'] := HTMLRender1.GetElementValue('language');
    FData.Values['newsletter'] := HTMLRender1.GetElementValue('newsletter');
  end;
end;

procedure TfrmWizard.GoNext(FromStep: String);
begin
  if not ValidateStep(FromStep) then Exit;

  if FromStep = 'step1' then
    HTMLPages1.NavigateTo('step2')
  else if FromStep = 'step2' then
    HTMLPages1.NavigateTo('step3')
  else if FromStep = 'step3' then
  begin
    HTMLPages1.NavigateTo('step4');
    // Populate summary after navigation renders
    HTMLRender1.SetElementText('sumName', FData.Values['name']);
    HTMLRender1.SetElementText('sumEmail', FData.Values['email']);
    HTMLRender1.SetElementText('sumStreet', FData.Values['street']);
    HTMLRender1.SetElementText('sumCity', FData.Values['city']);
    HTMLRender1.SetElementText('sumZip', FData.Values['zip']);
    HTMLRender1.SetElementText('sumLang', FData.Values['language']);
    HTMLRender1.SetElementText('sumNews', FData.Values['newsletter']);
  end;
end;

procedure TfrmWizard.GoBack(FromStep: String);
begin
  if FromStep = 'step2' then
    HTMLPages1.NavigateTo('step1')
  else if FromStep = 'step3' then
    HTMLPages1.NavigateTo('step2')
  else if FromStep = 'step4' then
    HTMLPages1.NavigateTo('step3');
end;

procedure TfrmWizard.HTMLPages1BeforeNavigate(Sender: TObject;
  const FromPage, ToPage: string; var Allow: Boolean);
begin
  // Allow all navigation (validation is handled in GoNext)
  Allow := True;
end;

procedure TfrmWizard.HTMLRender1FormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
begin
  if FormName = 'wizardSubmit' then
  begin
    ShowMessage(Format(
      'Registration complete!' + sLineBreak +
      'Name: %s' + sLineBreak +
      'Email: %s' + sLineBreak +
      'City: %s',
      [FData.Values['name'], FData.Values['email'], FData.Values['city']]));
  end;
end;

end.
```

---

## 14. Common Gotchas

### Page Name Case Sensitivity

**Symptom**: Navigation does not work. The renderer stays on the current page.

**Fix**: Page names are case-sensitive. `#Dashboard` does not match a page named `dashboard`:

```pascal
// Page defined as:
Page.PageName := 'dashboard';

// This works:
<a href="#dashboard">Dashboard</a>

// This does NOT work:
<a href="#Dashboard">Dashboard</a>
```

### Circular Navigation in OnBeforeNavigate

**Symptom**: Application freezes or stack overflow.

**Fix**: If your `OnBeforeNavigate` handler calls `NavigateTo`, it triggers another `OnBeforeNavigate` event. Always allow navigation to the redirect target:

```pascal
procedure TForm1.BeforeNavigate(Sender: TObject;
  const FromPage, ToPage: string; var Allow: Boolean);
begin
  // ALWAYS allow navigation to the login page
  if ToPage = 'login' then
  begin
    Allow := True;
    Exit;
  end;

  if not FIsLoggedIn then
  begin
    Allow := False;
    HTMLPages1.NavigateTo('login');  // This triggers BeforeNavigate again
    // Without the 'login' check above, you get infinite recursion
  end;
end;
```

### TwigContent vs HTMLContent Priority

**Symptom**: HTML changes to `HTMLContent` have no effect.

**Fix**: If `TwigContent` is not empty, it takes priority and `HTMLContent` is ignored. Clear `TwigContent` if you want to use raw HTML:

```pascal
// If TwigContent has content, HTMLContent is ignored
Page.TwigContent.Clear;
Page.HTMLContent.Text := '<h1>This will now display</h1>';
```

### Styles Not Persisting Between Pages

**Symptom**: CSS styles defined on one page do not apply on another page.

**Fix**: Each page's HTML is self-contained. Styles defined in one page's `<style>` block do not carry over when you navigate to another page. Include shared styles in every page, or use a helper function:

```pascal
function GetSharedStyles: string;
begin
  Result := '<style>/* shared styles */</style>';
end;

// Use in every page
Page.HTMLContent.Text := GetSharedStyles + '<div>Page content</div>';
```

### Form Data Lost on Navigation

**Symptom**: User fills in a form, navigates away, comes back, and the form is empty.

**Fix**: Page content is re-rendered from `HTMLContent` on every navigation. Form values are not preserved. Save form data to variables before navigating away (as shown in the wizard example), or store values in a `TStringList` and pre-populate fields after navigation.

---

## Summary

| What | How |
|---|---|
| Setup | `HTMLPages1.Renderer := HTMLRender1` |
| Add page (design) | Double-click component, use collection editor |
| Add page (runtime) | `HTMLPages1.Pages.Add` -- set `PageName`, `HTMLContent` |
| Default page | `Page.IsDefault := True` |
| Navigate via link | `<a href="#pagename">` |
| Navigate via code | `HTMLPages1.NavigateTo('pagename')` |
| Read active page | `HTMLPages1.ActivePage` |
| Guard navigation | `OnBeforeNavigate` -- set `Allow := False` to block |
| Post-navigation | `OnAfterNavigate` -- load data, update UI |
| Twig in pages | Set `TwigContent` + `SetTwigVariable` |
| File templates | Set `TwigTemplatePath` for `{% include %}`/`{% extends %}` |
| Page priority | `TwigContent` (if set) overrides `HTMLContent` |
