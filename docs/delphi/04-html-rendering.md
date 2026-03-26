# Chapter 4: HTML Rendering

## A Web Browser Inside Your Desktop App

Your FMX application needs a dashboard with styled cards, tables, and action buttons. You could build it with native controls -- dozens of `TLabel`, `TRectangle`, `TPanel`, and `TLayout` components, each positioned and styled by hand. Or you could write HTML.

`TTina4HTMLRender` is an FMX control that parses HTML and CSS and renders them directly on a canvas. It is not a web browser. It does not embed Chromium. It does not spawn a separate process. It is a native FMX control that understands HTML structure, CSS styling, form controls, and interactive events. Drop it on your form, set the `HTML.Text` property, and you have a styled, interactive UI in your desktop application.

---

## 1. Basic Usage

Drop a `TTina4HTMLRender` on your form. Set its `Align` to `Client` so it fills the form. Then set the HTML:

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<h1>Hello from Tina4</h1>' +
  '<p>This is <b>bold</b> and <i>italic</i> text rendered on an FMX canvas.</p>' +
  '<hr>' +
  '<p style="color: blue; font-size: 18px;">Styled paragraph with inline CSS.</p>';
```

Run the app. You see a rendered heading, a paragraph with bold and italic, a horizontal rule, and a blue styled paragraph. No web view. No Chromium. Just canvas drawing.

### Updating Content

Change the HTML at any time and the control re-renders:

```pascal
procedure TForm1.btnRefreshClick(Sender: TObject);
begin
  Tina4HTMLRender1.HTML.Text :=
    '<h1>Updated at ' + FormatDateTime('hh:nn:ss', Now) + '</h1>';
end;
```

---

## 2. Supported HTML Elements

The renderer supports a practical subset of HTML -- everything you need for dashboards, forms, reports, and documentation displays.

### Block Elements

`h1` through `h6`, `p`, `div`, `pre`, `blockquote`, `hr`, `fieldset`

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<div style="padding: 10px; border: 1px solid #ccc;">' +
  '  <h2>Section Title</h2>' +
  '  <p>Regular paragraph text.</p>' +
  '  <blockquote>A quoted passage with special styling.</blockquote>' +
  '  <pre>Preformatted code block</pre>' +
  '</div>';
```

### Inline Elements

`span`, `b`/`strong`, `i`/`em`, `a`, `br`, `small`, `label`, `kbd`, `abbr`, `cite`, `q`, `var`, `samp`, `dfn`, `time`

### Lists

`ul`, `ol`, `li` with bullet and number markers. The `list-style-type` CSS property is supported:

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<h3>Features</h3>' +
  '<ul>' +
  '  <li>REST client components</li>' +
  '  <li>JSON data binding</li>' +
  '  <li>HTML rendering with CSS</li>' +
  '</ul>' +
  '<h3>Steps</h3>' +
  '<ol>' +
  '  <li>Install the packages</li>' +
  '  <li>Drop components on form</li>' +
  '  <li>Set properties and run</li>' +
  '</ol>';
```

### Tables

`table`, `tr`, `td`, `th`, `thead`, `tbody`, `tfoot` with collapsed borders:

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<table style="width: 100%; border-collapse: collapse;">' +
  '  <thead>' +
  '    <tr>' +
  '      <th style="border: 1px solid #ddd; padding: 8px; background: #f5f5f5;">Name</th>' +
  '      <th style="border: 1px solid #ddd; padding: 8px; background: #f5f5f5;">Email</th>' +
  '      <th style="border: 1px solid #ddd; padding: 8px; background: #f5f5f5;">Status</th>' +
  '    </tr>' +
  '  </thead>' +
  '  <tbody>' +
  '    <tr>' +
  '      <td style="border: 1px solid #ddd; padding: 8px;">Alice</td>' +
  '      <td style="border: 1px solid #ddd; padding: 8px;">alice@example.com</td>' +
  '      <td style="border: 1px solid #ddd; padding: 8px;">Active</td>' +
  '    </tr>' +
  '    <tr>' +
  '      <td style="border: 1px solid #ddd; padding: 8px;">Bob</td>' +
  '      <td style="border: 1px solid #ddd; padding: 8px;">bob@example.com</td>' +
  '      <td style="border: 1px solid #ddd; padding: 8px;">Inactive</td>' +
  '    </tr>' +
  '  </tbody>' +
  '</table>';
```

### Images

`img` with HTTP download, async loading, and disk-based caching:

```pascal
Tina4HTMLRender1.CacheEnabled := True;
Tina4HTMLRender1.CacheDir := 'C:\MyApp\cache';
Tina4HTMLRender1.HTML.Text :=
  '<img src="https://picsum.photos/300/200" width="300" height="200">' +
  '<p>Image loaded from the web and cached to disk.</p>';
```

---

## 3. CSS Support

The renderer supports a substantial CSS feature set -- enough for professional-looking UIs without reaching for native FMX styling.

### External Stylesheets

```html
<link rel="stylesheet" href="https://example.com/styles.css">
```

Stylesheets are downloaded via HTTP and cached. This means you can use external CSS frameworks or shared stylesheets.

### Style Blocks

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<style>' +
  '  .card { border: 1px solid #e0e0e0; border-radius: 8px; padding: 16px; margin: 8px; }' +
  '  .card h3 { margin: 0 0 8px 0; color: #333; }' +
  '  .card p { color: #666; font-size: 14px; }' +
  '  .status-active { color: green; font-weight: bold; }' +
  '  .status-inactive { color: red; }' +
  '</style>' +
  '<div class="card">' +
  '  <h3>User Dashboard</h3>' +
  '  <p>Status: <span class="status-active">Active</span></p>' +
  '</div>';
```

### Inline Styles

```html
<div style="background-color: #f9f9f9; padding: 20px; border-radius: 4px;">
  <p style="font-size: 16px; color: #333;">Inline styled content.</p>
</div>
```

### Selector Support

- **Tag selectors**: `h1`, `p`, `div`
- **Class selectors**: `.card`, `.btn`
- **ID selectors**: `#header`, `#main`
- **Combined selectors**: `div.card`, `p.highlight`
- **Specificity-based cascade**: more specific selectors override less specific ones

### Custom Properties (CSS Variables)

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<style>' +
  '  :root { --primary: #2563eb; --text: #333; --bg: #f8f9fa; }' +
  '  .header { color: var(--primary); background: var(--bg); padding: 16px; }' +
  '  .body { color: var(--text); padding: 16px; }' +
  '</style>' +
  '<div class="header"><h2>Dashboard</h2></div>' +
  '<div class="body"><p>Content styled with CSS variables.</p></div>';
```

### Supported CSS Properties

| Category | Properties |
|---|---|
| Box model | `margin`, `padding`, `border`, `border-radius`, `width`, `height`, `min-width`, `max-width`, `min-height`, `max-height`, `box-sizing`, `box-shadow` |
| Display | `block`, `inline`, `inline-block`, `none`, `table`, `table-row`, `table-cell`, `list-item` |
| Text | `color`, `font-size`, `font-family`, `font-weight`, `font-style`, `text-align`, `line-height`, `text-decoration`, `text-transform`, `letter-spacing`, `text-indent`, `text-overflow`, `white-space` |
| Background | `background-color`, `opacity` |
| Visibility | `visibility`, `overflow`, `display: none` |
| Bootstrap 5 | `.btn` variants, `.form-control`, `.form-check`, `.text-muted` -- fallback styles are built in |

---

## 4. Form Controls

HTML form elements create native FMX controls overlaid on the rendered content. These are real editable controls -- text inputs, checkboxes, radio buttons, dropdowns, and buttons.

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<style>' +
  '  .form-group { margin-bottom: 12px; }' +
  '  label { display: block; margin-bottom: 4px; font-weight: bold; }' +
  '  input, select, textarea { width: 300px; padding: 6px; border: 1px solid #ccc; }' +
  '  .btn { padding: 8px 16px; background: #2563eb; color: white; border: none; cursor: pointer; }' +
  '</style>' +
  '<form name="userForm">' +
  '  <div class="form-group">' +
  '    <label>Name</label>' +
  '    <input type="text" name="username" id="username" placeholder="Enter your name">' +
  '  </div>' +
  '  <div class="form-group">' +
  '    <label>Email</label>' +
  '    <input type="email" name="email" id="email" placeholder="you@example.com">' +
  '  </div>' +
  '  <div class="form-group">' +
  '    <label>Password</label>' +
  '    <input type="password" name="password" id="password">' +
  '  </div>' +
  '  <div class="form-group">' +
  '    <label>Role</label>' +
  '    <select name="role" id="role">' +
  '      <option value="user">User</option>' +
  '      <option value="admin">Admin</option>' +
  '      <option value="editor">Editor</option>' +
  '    </select>' +
  '  </div>' +
  '  <div class="form-group">' +
  '    <label>Bio</label>' +
  '    <textarea name="bio" id="bio" rows="4"></textarea>' +
  '  </div>' +
  '  <div class="form-group">' +
  '    <input type="checkbox" name="terms" id="terms">' +
  '    <label style="display: inline;">I agree to the terms</label>' +
  '  </div>' +
  '  <button type="submit" class="btn">Submit</button>' +
  '</form>';
```

Supported input types: `text`, `password`, `email`, `radio`, `checkbox`, `submit`, `button`, `reset`, `file`. Plus `textarea`, `select`/`option`, and `button`.

---

## 5. Events

The renderer fires events for form interactions, element clicks, and link clicks.

### OnFormSubmit

Fires when a submit button is clicked. Collects all form data as name=value pairs:

```pascal
procedure TForm1.HTMLRender1FormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
var
  Username, Email, Role: string;
begin
  Username := FormData.Values['username'];
  Email := FormData.Values['email'];
  Role := FormData.Values['role'];

  ShowMessage(Format('Form "%s" submitted. User: %s, Email: %s, Role: %s',
    [FormName, Username, Email, Role]));
end;
```

### OnFormControlChange

Fires when any form control's value changes:

```pascal
procedure TForm1.HTMLRender1FormControlChange(Sender: TObject;
  const Name, Value: string);
begin
  // React to real-time changes
  if Name = 'role' then
  begin
    if Value = 'admin' then
      Tina4HTMLRender1.SetElementVisible('adminPanel', True)
    else
      Tina4HTMLRender1.SetElementVisible('adminPanel', False);
  end;
end;
```

### OnFormControlClick

Fires when a form control is clicked (useful for buttons that are not submit buttons):

```pascal
procedure TForm1.HTMLRender1FormControlClick(Sender: TObject;
  const Name, Value: string);
begin
  if Name = 'cancelBtn' then
    ClearForm;
end;
```

### OnLinkClick

Fires when an anchor tag is clicked. Set `Handled := True` to prevent default navigation:

```pascal
procedure TForm1.HTMLRender1LinkClick(Sender: TObject;
  const AURL: string; var Handled: Boolean);
begin
  if AURL.StartsWith('http') then
  begin
    // Open in system browser instead of navigating
    ShellExecute(0, 'open', PChar(AURL), nil, nil, SW_SHOWNORMAL);
    Handled := True;
  end;
end;
```

### Event Reference

| Event | Signature | When |
|---|---|---|
| `OnFormControlChange` | `(Sender; Name, Value: string)` | Form control value changes |
| `OnFormControlClick` | `(Sender; Name, Value: string)` | Form control clicked |
| `OnFormControlEnter` | `(Sender; Name, Value: string)` | Form control gains focus |
| `OnFormControlExit` | `(Sender; Name, Value: string)` | Form control loses focus |
| `OnFormSubmit` | `(Sender; FormName: string; FormData: TStrings)` | Submit button clicked |
| `OnElementClick` | `(Sender; ObjectName, MethodName: string; Params: TStrings)` | onclick RTTI element clicked |
| `OnLinkClick` | `(Sender; URL: string; var Handled: Boolean)` | Anchor href clicked |

---

## 6. onclick and RTTI -- Calling Pascal from HTML

Any HTML element can call a Pascal method directly using the `onclick` attribute with a special syntax: `onclick="ObjectName:MethodName(params)"`. This bridges HTML events to Delphi code without writing event handlers.

### Step 1: Register Your Object

In your form's `OnCreate`, register the Delphi object that will receive calls:

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  Tina4HTMLRender1.RegisterObject('App', Self);
end;
```

### Step 2: Write the Target Method

The method must be `published` or use `{$M+}` RTTI. Parameters are passed as strings:

```pascal
procedure TForm1.ShowAlert(Message: String);
begin
  ShowMessage(Message);
end;

procedure TForm1.HandleAction(Action: String; ItemId: String);
begin
  if Action = 'delete' then
    DeleteItem(ItemId)
  else if Action = 'edit' then
    EditItem(ItemId);
end;
```

### Step 3: Call from HTML

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<button onclick="App:ShowAlert(''Hello from HTML!'')">Say Hello</button>' +
  '<button onclick="App:HandleAction(''edit'', ''42'')">Edit Item 42</button>' +
  '<button onclick="App:HandleAction(''delete'', ''42'')">Delete Item 42</button>';
```

### Dynamic Parameter Expressions

The onclick handler supports dynamic expressions, not just string literals:

| Expression | Resolves To |
|---|---|
| `'literal'` or `"literal"` | String literal |
| `123` | Numeric literal |
| `this.value` | Value of the clicked element |
| `this.id` | ID of the clicked element |
| `document.getElementById('id').value` | Value of element by ID |
| `document.getElementById('id').<attr>` | Any attribute of element by ID |

Example with dynamic values:

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<input type="text" id="nameInput" placeholder="Type your name">' +
  '<button onclick="App:Greet(document.getElementById(''nameInput'').value)">' +
  '  Greet</button>';
```

```pascal
procedure TForm1.Greet(Name: String);
begin
  ShowMessage('Hello, ' + Name + '!');
end;
```

---

## 7. DOM Manipulation

Modify rendered HTML elements from Delphi code at runtime. Update text, change styles, show/hide elements, enable/disable controls -- all without re-rendering the entire HTML.

### Get and Set Values

```pascal
// Set a form input's value
Tina4HTMLRender1.SetElementValue('emailInput', 'user@example.com');

// Read a form input's value
var Email := Tina4HTMLRender1.GetElementValue('emailInput');
```

### Enable/Disable Controls

```pascal
// Disable the submit button until the form is valid
Tina4HTMLRender1.SetElementEnabled('submitBtn', False);

// Enable it when validation passes
Tina4HTMLRender1.SetElementEnabled('submitBtn', True);
```

### Show/Hide Elements

```pascal
// Show an error message
Tina4HTMLRender1.SetElementVisible('errorMsg', True);

// Hide the loading spinner
Tina4HTMLRender1.SetElementVisible('spinner', False);
```

### Change Text Content

```pascal
Tina4HTMLRender1.SetElementText('statusLabel', 'Processing...');
Tina4HTMLRender1.SetElementText('recordCount', IntToStr(Count) + ' records');
```

### Change Styles

```pascal
Tina4HTMLRender1.SetElementStyle('statusLabel', 'color', 'green');
Tina4HTMLRender1.SetElementStyle('alertBox', 'background-color', '#fee2e2');
Tina4HTMLRender1.SetElementStyle('alertBox', 'border', '1px solid #ef4444');
```

### Set Attributes

```pascal
Tina4HTMLRender1.SetElementAttribute('myImage', 'src', 'https://example.com/new-photo.jpg');
Tina4HTMLRender1.SetElementAttribute('myLink', 'href', '/new-page');

// Changing class or style triggers relayout
Tina4HTMLRender1.SetElementAttribute('myDiv', 'class', 'card highlighted');
```

### Force Refresh

```pascal
// After multiple DOM changes, force a full re-layout
Tina4HTMLRender1.RefreshElement('mainContent');
```

### DOM Method Reference

| Method | Description |
|---|---|
| `GetElementById(Id)` | Returns the `THTMLTag` for the element |
| `GetElementValue(Id)` | Gets the live value from a native control or DOM attribute |
| `SetElementValue(Id, Value)` | Sets the value on native controls and DOM |
| `SetElementAttribute(Id, Attr, Value)` | Sets any attribute; triggers relayout for `class`/`style` |
| `SetElementEnabled(Id, Enabled)` | Enables/disables native controls |
| `SetElementVisible(Id, Visible)` | Shows/hides elements via `display:none` |
| `SetElementText(Id, Text)` | Updates inner text content |
| `SetElementStyle(Id, Prop, Value)` | Sets an inline style property |
| `RefreshElement(Id)` | Forces a full re-layout and repaint |

---

## 8. Image Loading and Caching

Images referenced in `<img>` tags are downloaded asynchronously via HTTP. Once downloaded, they are cached to disk so subsequent renders are instant.

```pascal
// Enable caching and set the cache directory
Tina4HTMLRender1.CacheEnabled := True;
Tina4HTMLRender1.CacheDir := 'C:\MyApp\cache';

// Images load in the background and appear when ready
Tina4HTMLRender1.HTML.Text :=
  '<div style="display: inline-block; margin: 8px;">' +
  '  <img src="https://picsum.photos/200/150" width="200" height="150">' +
  '  <p style="text-align: center;">Random photo</p>' +
  '</div>';
```

The first load downloads the image. Subsequent loads read from `C:\MyApp\cache`. Without a cache directory, images are re-downloaded every time.

---

## 9. Complete Example: Login Form with Validation

A login form with username and password fields, client-side validation, error display, and a submit handler that calls a REST API.

```pascal
unit LoginForm;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls,
  Tina4HTMLRender, Tina4REST;

type
  TfrmLogin = class(TForm)
    HTMLRender1: TTina4HTMLRender;
    restAPI: TTina4REST;
    procedure FormCreate(Sender: TObject);
    procedure HTMLRender1FormSubmit(Sender: TObject;
      const FormName: string; FormData: TStrings);
  private
    procedure RenderLoginPage;
    procedure ShowError(const Msg: string);
    procedure ShowSuccess;
  published
    procedure ForgotPassword(Action: String);
  end;

var
  frmLogin: TfrmLogin;

implementation

{$R *.fmx}

procedure TfrmLogin.FormCreate(Sender: TObject);
begin
  restAPI.BaseUrl := 'https://api.example.com';
  HTMLRender1.RegisterObject('Login', Self);
  RenderLoginPage;
end;

procedure TfrmLogin.RenderLoginPage;
begin
  HTMLRender1.HTML.Text :=
    '<style>' +
    '  body { font-family: Arial, sans-serif; background: #f5f5f5; }' +
    '  .login-card { max-width: 400px; margin: 40px auto; padding: 32px;' +
    '    background: white; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }' +
    '  .login-card h2 { margin: 0 0 24px 0; text-align: center; color: #333; }' +
    '  .form-group { margin-bottom: 16px; }' +
    '  .form-group label { display: block; margin-bottom: 4px; font-weight: bold;' +
    '    color: #555; font-size: 14px; }' +
    '  .form-group input { width: 100%; padding: 10px; border: 1px solid #ddd;' +
    '    border-radius: 4px; font-size: 14px; }' +
    '  .btn-login { width: 100%; padding: 12px; background: #2563eb; color: white;' +
    '    border: none; border-radius: 4px; font-size: 16px; font-weight: bold; }' +
    '  .error { background: #fee2e2; color: #dc2626; padding: 10px; border-radius: 4px;' +
    '    margin-bottom: 16px; display: none; }' +
    '  .success { background: #dcfce7; color: #16a34a; padding: 10px; border-radius: 4px;' +
    '    margin-bottom: 16px; display: none; }' +
    '  .forgot { text-align: center; margin-top: 16px; }' +
    '  .forgot a { color: #2563eb; font-size: 14px; }' +
    '</style>' +
    '<div class="login-card">' +
    '  <h2>Sign In</h2>' +
    '  <div class="error" id="errorBox">Error message here</div>' +
    '  <div class="success" id="successBox">Login successful!</div>' +
    '  <form name="loginForm">' +
    '    <div class="form-group">' +
    '      <label>Email</label>' +
    '      <input type="email" name="email" id="email" placeholder="you@example.com">' +
    '    </div>' +
    '    <div class="form-group">' +
    '      <label>Password</label>' +
    '      <input type="password" name="password" id="password" placeholder="Enter password">' +
    '    </div>' +
    '    <button type="submit" class="btn-login" id="btnSubmit">Sign In</button>' +
    '  </form>' +
    '  <div class="forgot">' +
    '    <span onclick="Login:ForgotPassword(''reset'')" ' +
    '      style="color: #2563eb; cursor: pointer;">Forgot your password?</span>' +
    '  </div>' +
    '</div>';
end;

procedure TfrmLogin.HTMLRender1FormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
var
  Email, Password: string;
  StatusCode: Integer;
  Response: TJSONObject;
begin
  if FormName <> 'loginForm' then Exit;

  Email := FormData.Values['email'];
  Password := FormData.Values['password'];

  // Client-side validation
  if Email.Trim = '' then
  begin
    ShowError('Email is required');
    Exit;
  end;
  if Password.Trim = '' then
  begin
    ShowError('Password is required');
    Exit;
  end;
  if not Email.Contains('@') then
  begin
    ShowError('Please enter a valid email address');
    Exit;
  end;

  // Disable the button while processing
  HTMLRender1.SetElementEnabled('btnSubmit', False);
  HTMLRender1.SetElementText('btnSubmit', 'Signing in...');

  // Call the API
  Response := restAPI.Post(StatusCode, '/auth/login', '',
    Format('{"email": "%s", "password": "%s"}', [Email, Password]));
  try
    if StatusCode = 200 then
    begin
      var Token := Response.GetValue<String>('token');
      restAPI.SetBearer(Token);
      ShowSuccess;
    end
    else
    begin
      ShowError('Invalid email or password');
    end;
  finally
    Response.Free;
    HTMLRender1.SetElementEnabled('btnSubmit', True);
    HTMLRender1.SetElementText('btnSubmit', 'Sign In');
  end;
end;

procedure TfrmLogin.ShowError(const Msg: string);
begin
  HTMLRender1.SetElementVisible('successBox', False);
  HTMLRender1.SetElementText('errorBox', Msg);
  HTMLRender1.SetElementVisible('errorBox', True);
end;

procedure TfrmLogin.ShowSuccess;
begin
  HTMLRender1.SetElementVisible('errorBox', False);
  HTMLRender1.SetElementVisible('successBox', True);
end;

procedure TfrmLogin.ForgotPassword(Action: String);
begin
  ShowMessage('Forgot password flow: ' + Action);
end;

end.
```

---

## 10. Complete Example: Interactive Dashboard

A dashboard with stats cards, a data table, and action buttons that call Pascal methods. This demonstrates combining styled HTML, dynamic data, and RTTI-based event handling.

```pascal
unit Dashboard;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls,
  FireDAC.Comp.Client,
  Tina4HTMLRender, Tina4REST, Tina4Core;

type
  TfrmDashboard = class(TForm)
    HTMLRender1: TTina4HTMLRender;
    restAPI: TTina4REST;
    procedure FormCreate(Sender: TObject);
  private
    procedure RenderDashboard;
    function BuildStatsCards: string;
    function BuildUserTable: string;
  published
    procedure ViewUser(UserId: String);
    procedure DeleteUser(UserId: String);
    procedure RefreshData(Action: String);
  end;

var
  frmDashboard: TfrmDashboard;

implementation

{$R *.fmx}

procedure TfrmDashboard.FormCreate(Sender: TObject);
begin
  restAPI.BaseUrl := 'https://api.example.com/v1';
  HTMLRender1.RegisterObject('Dashboard', Self);
  RenderDashboard;
end;

procedure TfrmDashboard.RenderDashboard;
begin
  HTMLRender1.HTML.Text :=
    '<style>' +
    '  * { box-sizing: border-box; }' +
    '  body { font-family: Arial, sans-serif; padding: 20px; background: #f0f2f5; }' +
    '  h1 { color: #1a1a2e; margin-bottom: 24px; }' +
    '  .stats { display: inline-block; width: 100%; margin-bottom: 24px; }' +
    '  .stat-card { display: inline-block; width: 22%; margin-right: 2%;' +
    '    background: white; border-radius: 8px; padding: 20px;' +
    '    box-shadow: 0 1px 3px rgba(0,0,0,0.1); }' +
    '  .stat-card h3 { margin: 0; color: #888; font-size: 12px; text-transform: uppercase; }' +
    '  .stat-card .value { font-size: 28px; font-weight: bold; color: #1a1a2e; margin: 8px 0; }' +
    '  .stat-card .change { font-size: 12px; color: #16a34a; }' +
    '  table { width: 100%; border-collapse: collapse; background: white;' +
    '    border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }' +
    '  th { background: #f8f9fa; padding: 12px; text-align: left;' +
    '    font-size: 12px; color: #888; text-transform: uppercase; border-bottom: 2px solid #e0e0e0; }' +
    '  td { padding: 12px; border-bottom: 1px solid #f0f0f0; color: #333; }' +
    '  .btn-sm { padding: 4px 12px; border: none; border-radius: 4px;' +
    '    font-size: 12px; cursor: pointer; margin-right: 4px; }' +
    '  .btn-view { background: #dbeafe; color: #2563eb; }' +
    '  .btn-delete { background: #fee2e2; color: #dc2626; }' +
    '  .btn-refresh { padding: 8px 16px; background: #2563eb; color: white;' +
    '    border: none; border-radius: 4px; margin-bottom: 16px; }' +
    '  .toolbar { margin-bottom: 16px; }' +
    '</style>' +
    '<h1>Admin Dashboard</h1>' +
    '<div class="toolbar">' +
    '  <button class="btn-refresh" ' +
    '    onclick="Dashboard:RefreshData(''all'')">Refresh Data</button>' +
    '</div>' +
    BuildStatsCards +
    '<h2 style="color: #1a1a2e; margin: 24px 0 16px;">Recent Users</h2>' +
    BuildUserTable;
end;

function TfrmDashboard.BuildStatsCards: string;
begin
  Result :=
    '<div class="stats">' +
    '  <div class="stat-card">' +
    '    <h3>Total Users</h3>' +
    '    <div class="value" id="totalUsers">1,234</div>' +
    '    <div class="change">+12% this month</div>' +
    '  </div>' +
    '  <div class="stat-card">' +
    '    <h3>Active Sessions</h3>' +
    '    <div class="value" id="activeSessions">56</div>' +
    '    <div class="change">+3% this hour</div>' +
    '  </div>' +
    '  <div class="stat-card">' +
    '    <h3>Revenue</h3>' +
    '    <div class="value" id="revenue">$48,290</div>' +
    '    <div class="change">+8% this week</div>' +
    '  </div>' +
    '  <div class="stat-card">' +
    '    <h3>Orders</h3>' +
    '    <div class="value" id="orders">389</div>' +
    '    <div class="change">+5% today</div>' +
    '  </div>' +
    '</div>';
end;

function TfrmDashboard.BuildUserTable: string;
begin
  Result :=
    '<table>' +
    '  <thead>' +
    '    <tr><th>ID</th><th>Name</th><th>Email</th><th>Status</th><th>Actions</th></tr>' +
    '  </thead>' +
    '  <tbody>' +
    '    <tr>' +
    '      <td>1</td><td>Alice Smith</td><td>alice@example.com</td>' +
    '      <td style="color: green;">Active</td>' +
    '      <td>' +
    '        <button class="btn-sm btn-view" onclick="Dashboard:ViewUser(''1'')">View</button>' +
    '        <button class="btn-sm btn-delete" onclick="Dashboard:DeleteUser(''1'')">Delete</button>' +
    '      </td>' +
    '    </tr>' +
    '    <tr>' +
    '      <td>2</td><td>Bob Johnson</td><td>bob@example.com</td>' +
    '      <td style="color: green;">Active</td>' +
    '      <td>' +
    '        <button class="btn-sm btn-view" onclick="Dashboard:ViewUser(''2'')">View</button>' +
    '        <button class="btn-sm btn-delete" onclick="Dashboard:DeleteUser(''2'')">Delete</button>' +
    '      </td>' +
    '    </tr>' +
    '    <tr>' +
    '      <td>3</td><td>Carol Williams</td><td>carol@example.com</td>' +
    '      <td style="color: red;">Inactive</td>' +
    '      <td>' +
    '        <button class="btn-sm btn-view" onclick="Dashboard:ViewUser(''3'')">View</button>' +
    '        <button class="btn-sm btn-delete" onclick="Dashboard:DeleteUser(''3'')">Delete</button>' +
    '      </td>' +
    '    </tr>' +
    '  </tbody>' +
    '</table>';
end;

procedure TfrmDashboard.ViewUser(UserId: String);
begin
  ShowMessage('Viewing user ' + UserId);
  // In a real app: navigate to user detail page or show a modal
end;

procedure TfrmDashboard.DeleteUser(UserId: String);
begin
  ShowMessage('Delete user ' + UserId + '?');
  // In a real app: confirm then call DELETE /users/{id}
end;

procedure TfrmDashboard.RefreshData(Action: String);
begin
  // Refresh stats via DOM manipulation -- no full re-render needed
  HTMLRender1.SetElementText('totalUsers', '1,256');
  HTMLRender1.SetElementText('activeSessions', '61');
  HTMLRender1.SetElementText('revenue', '$49,100');
  HTMLRender1.SetElementText('orders', '402');
  ShowMessage('Dashboard data refreshed');
end;

end.
```

---

## 11. Exercise: Contact Form

Build a contact form with name, email, and message fields. Validate all fields before submission. Submit the data to a REST API.

### Requirements

1. Drop a `TTina4HTMLRender` on a form
2. Create an HTML form with: name (text), email (email), subject (select dropdown), message (textarea)
3. Add validation: all fields required, email must contain `@`, message minimum 10 characters
4. Show validation errors inline (red text below each field)
5. On successful validation, POST the form data to `/contact` as JSON
6. Show a success message after submission

### Solution

```pascal
unit ContactForm;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms,
  Tina4HTMLRender, Tina4REST;

type
  TfrmContact = class(TForm)
    HTMLRender1: TTina4HTMLRender;
    restAPI: TTina4REST;
    procedure FormCreate(Sender: TObject);
    procedure HTMLRender1FormSubmit(Sender: TObject;
      const FormName: string; FormData: TStrings);
  private
    procedure RenderForm;
    function Validate(FormData: TStrings): Boolean;
  end;

var
  frmContact: TfrmContact;

implementation

{$R *.fmx}

procedure TfrmContact.FormCreate(Sender: TObject);
begin
  restAPI.BaseUrl := 'https://api.example.com';
  RenderForm;
end;

procedure TfrmContact.RenderForm;
begin
  HTMLRender1.HTML.Text :=
    '<style>' +
    '  .container { max-width: 500px; margin: 20px auto; padding: 24px;' +
    '    background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }' +
    '  h2 { margin: 0 0 20px 0; color: #333; }' +
    '  .field { margin-bottom: 16px; }' +
    '  .field label { display: block; margin-bottom: 4px; font-weight: bold; font-size: 14px; }' +
    '  .field input, .field select, .field textarea ' +
    '    { width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px; }' +
    '  .field textarea { height: 100px; }' +
    '  .error-text { color: #dc2626; font-size: 12px; display: none; margin-top: 4px; }' +
    '  .btn-submit { padding: 10px 24px; background: #2563eb; color: white;' +
    '    border: none; border-radius: 4px; font-size: 14px; }' +
    '  .success-msg { background: #dcfce7; color: #16a34a; padding: 12px;' +
    '    border-radius: 4px; display: none; margin-bottom: 16px; }' +
    '</style>' +
    '<div class="container">' +
    '  <h2>Contact Us</h2>' +
    '  <div class="success-msg" id="successMsg">Thank you! Your message has been sent.</div>' +
    '  <form name="contactForm">' +
    '    <div class="field">' +
    '      <label>Name</label>' +
    '      <input type="text" name="name" id="name" placeholder="Your full name">' +
    '      <div class="error-text" id="nameError">Name is required</div>' +
    '    </div>' +
    '    <div class="field">' +
    '      <label>Email</label>' +
    '      <input type="email" name="email" id="email" placeholder="you@example.com">' +
    '      <div class="error-text" id="emailError">Valid email is required</div>' +
    '    </div>' +
    '    <div class="field">' +
    '      <label>Subject</label>' +
    '      <select name="subject" id="subject">' +
    '        <option value="">Select a subject</option>' +
    '        <option value="support">Technical Support</option>' +
    '        <option value="sales">Sales Inquiry</option>' +
    '        <option value="feedback">Feedback</option>' +
    '      </select>' +
    '      <div class="error-text" id="subjectError">Please select a subject</div>' +
    '    </div>' +
    '    <div class="field">' +
    '      <label>Message</label>' +
    '      <textarea name="message" id="message" placeholder="Your message (min 10 chars)"></textarea>' +
    '      <div class="error-text" id="messageError">Message must be at least 10 characters</div>' +
    '    </div>' +
    '    <button type="submit" class="btn-submit" id="btnSubmit">Send Message</button>' +
    '  </form>' +
    '</div>';
end;

procedure TfrmContact.HTMLRender1FormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  if FormName <> 'contactForm' then Exit;

  // Hide previous errors
  HTMLRender1.SetElementVisible('nameError', False);
  HTMLRender1.SetElementVisible('emailError', False);
  HTMLRender1.SetElementVisible('subjectError', False);
  HTMLRender1.SetElementVisible('messageError', False);
  HTMLRender1.SetElementVisible('successMsg', False);

  if not Validate(FormData) then Exit;

  // Submit to API
  HTMLRender1.SetElementEnabled('btnSubmit', False);
  HTMLRender1.SetElementText('btnSubmit', 'Sending...');

  Response := restAPI.Post(StatusCode, '/contact', '',
    Format('{"name": "%s", "email": "%s", "subject": "%s", "message": "%s"}',
      [FormData.Values['name'], FormData.Values['email'],
       FormData.Values['subject'], FormData.Values['message']]));
  try
    if StatusCode in [200, 201] then
    begin
      HTMLRender1.SetElementVisible('successMsg', True);
      // Clear the form
      HTMLRender1.SetElementValue('name', '');
      HTMLRender1.SetElementValue('email', '');
      HTMLRender1.SetElementValue('message', '');
    end
    else
      ShowMessage('Submission failed: HTTP ' + StatusCode.ToString);
  finally
    Response.Free;
    HTMLRender1.SetElementEnabled('btnSubmit', True);
    HTMLRender1.SetElementText('btnSubmit', 'Send Message');
  end;
end;

function TfrmContact.Validate(FormData: TStrings): Boolean;
begin
  Result := True;

  if FormData.Values['name'].Trim = '' then
  begin
    HTMLRender1.SetElementVisible('nameError', True);
    Result := False;
  end;

  var Email := FormData.Values['email'].Trim;
  if (Email = '') or (not Email.Contains('@')) then
  begin
    HTMLRender1.SetElementVisible('emailError', True);
    Result := False;
  end;

  if FormData.Values['subject'].Trim = '' then
  begin
    HTMLRender1.SetElementVisible('subjectError', True);
    Result := False;
  end;

  if FormData.Values['message'].Trim.Length < 10 then
  begin
    HTMLRender1.SetElementVisible('messageError', True);
    Result := False;
  end;
end;

end.
```

---

## 12. Common Gotchas

### Forgetting to Set Cache Directory for Images

**Symptom**: Images load the first time, but every subsequent launch re-downloads them. Or images do not appear at all.

**Fix**: Set `CacheEnabled := True` and `CacheDir` to a writable directory before setting the HTML:

```pascal
HTMLRender1.CacheEnabled := True;
HTMLRender1.CacheDir := TPath.Combine(TPath.GetDocumentsPath, 'AppCache');
ForceDirectories(HTMLRender1.CacheDir);
```

### RTTI Method Not Found

**Symptom**: Clicking an `onclick` element does nothing, or raises an access violation.

**Fix**: Ensure the target method is `published` (or the class has `{$M+}` RTTI). Ensure `RegisterObject` was called with the correct object name. Ensure the `onclick` format is exactly `ObjectName:MethodName(params)`:

```pascal
// Registration
HTMLRender1.RegisterObject('MyApp', Self);

// HTML must match the registered name
onclick="MyApp:DoSomething('param')"  // Correct
onclick="Form1:DoSomething('param')"  // Wrong name -- will not find the object
```

### Form Control Name Matching

**Symptom**: `FormData.Values['username']` returns empty string even though the user typed in the field.

**Fix**: The `name` attribute in the HTML must match exactly. Case matters:

```html
<input type="text" name="userName">   <!-- FormData.Values['userName'] -->
<input type="text" name="username">   <!-- FormData.Values['username'] -->
```

### Escaped Quotes in HTML Strings

**Symptom**: Compilation error or garbled HTML.

**Fix**: In Delphi string literals, use doubled single quotes `''` for apostrophes inside HTML attributes:

```pascal
// WRONG -- compilation error
HTML.Text := '<button onclick="App:Do('param')">Click</button>';

// CORRECT -- doubled single quotes
HTML.Text := '<button onclick="App:Do(''param'')">Click</button>';
```

---

## Summary

| What | How |
|---|---|
| Basic rendering | `HTMLRender1.HTML.Text := '<h1>Hello</h1>'` |
| External CSS | `<link rel="stylesheet" href="...">` |
| Style blocks | `<style>.card { ... }</style>` |
| Inline styles | `style="color: blue;"` |
| CSS variables | `var(--primary)` with `:root` |
| Form controls | `<input>`, `<select>`, `<textarea>`, `<button>` |
| Form submit | `OnFormSubmit` event -- `FormData.Values['name']` |
| RTTI onclick | `onclick="ObjName:Method(params)"` + `RegisterObject` |
| DOM: set value | `SetElementValue('id', 'value')` |
| DOM: show/hide | `SetElementVisible('id', True/False)` |
| DOM: enable | `SetElementEnabled('id', True/False)` |
| DOM: text | `SetElementText('id', 'text')` |
| DOM: style | `SetElementStyle('id', 'prop', 'value')` |
| Image caching | `CacheEnabled := True` + `CacheDir := '...'` |
