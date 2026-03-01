# HTML Renderer

::: tip
TTina4HTMLRender is an FMX control that parses and renders HTML with CSS support directly on a canvas, including native form controls, Bootstrap 5 class support, and interactive event handling.
:::

## Basic Usage {#usage}

```pascal
Tina4HTMLRender1.HTML.Text := '<h1>Hello</h1><p>This is <b>bold</b> and <i>italic</i>.</p>';
```

## Supported HTML {#html}

- **Block elements**: `h1`-`h6`, `p`, `div`, `pre`, `blockquote`, `hr`, `fieldset`
- **Inline elements**: `span`, `b`/`strong`, `i`/`em`, `a`, `br`, `small`, `label`
- **Semantic inline**: `kbd`, `abbr`, `cite`, `q`, `var`, `samp`, `dfn`, `time`
- **Lists**: `ul`, `ol`, `li` with bullet/number markers and configurable `list-style-type`
- **Tables**: `table`, `tr`, `td`, `th`, `thead`, `tbody`, `tfoot` with collapsed borders
- **Images**: `img` with HTTP download, async loading, and disk-based caching
- **Forms**: `input` (text, password, email, radio, checkbox, submit, button, reset, file), `textarea`, `select`/`option`, `button`, `label`, `fieldset`/`legend`

## CSS Support {#css}

- **External stylesheets**: `<link rel="stylesheet" href="...">` with HTTP loading and caching
- **`<style>` blocks**: Embedded CSS parsed and applied
- **Inline styles**: `style="..."` attribute
- **Selectors**: tag, `.class`, `#id`, combined selectors, specificity-based cascade
- **Custom properties**: `var()` resolution with `:root` and element-level scoping
- **Box model**: `margin`, `padding`, `border`, `border-top`/`right`/`bottom`/`left`, `border-radius`, `width`, `height`, `box-sizing`, `min-width`, `max-width`, `min-height`, `max-height`, `box-shadow`
- **Display modes**: `block`, `inline`, `inline-block`, `none`, `table`, `table-row`, `table-cell`, `list-item`
- **Text**: `color`, `font-size`, `font-family`, `font-weight`, `font-style`, `text-align`, `line-height`, `text-decoration`, `white-space`, `text-transform`, `letter-spacing`, `text-indent`, `text-overflow`
- **Background**: `background-color`, `opacity`
- **Visibility**: `visibility`, `overflow`
- **Word wrapping**: `word-break`, `overflow-wrap`/`word-wrap`
- **Bootstrap 5 fallbacks**: `.btn` variants, `.form-control`, `.form-check`, `.text-muted`

## Form Controls {#forms}

Native FMX controls are created for form elements, styled with CSS properties from the HTML.

```pascal
Tina4HTMLRender1.HTML.Text :=
  '<form name="login">' +
  '  <input type="text" name="username" placeholder="Username">' +
  '  <input type="password" name="password" placeholder="Password">' +
  '  <input type="file" name="avatar" accept="image/*">' +
  '  <button type="submit" class="btn btn-primary">Login</button>' +
  '</form>';
```

## Events {#events}

| Event | Signature | Description |
|---|---|---|
| `OnFormControlChange` | `procedure(Sender: TObject; const Name, Value: string)` | Form control value changes |
| `OnFormControlClick` | `procedure(Sender: TObject; const Name, Value: string)` | Form control clicked |
| `OnFormControlEnter` | `procedure(Sender: TObject; const Name, Value: string)` | Form control gains focus |
| `OnFormControlExit` | `procedure(Sender: TObject; const Name, Value: string)` | Form control loses focus |
| `OnFormSubmit` | `procedure(Sender: TObject; const FormName: string; FormData: TStrings)` | Submit button clicked with all form data |
| `OnElementClick` | `procedure(Sender: TObject; const ObjectName, MethodName: string; Params: TStrings)` | Element with `onclick` clicked |
| `OnLinkClick` | `procedure(Sender: TObject; const AURL: string; var Handled: Boolean)` | Anchor `<a href>` clicked |

## OnFormSubmit {#form-submit}

```pascal
procedure TForm1.HTMLRender1FormSubmit(Sender: TObject;
  const FormName: string; FormData: TStrings);
begin
  ShowMessage('Form: ' + FormName);
  for var I := 0 to FormData.Count - 1 do
    ShowMessage(FormData[I]);  // e.g. "username=admin"
end;
```

## onclick Events and RTTI {#onclick}

Any HTML element can call a Pascal method directly via RTTI using `onclick="ObjectName:MethodName(params)"`.

Register your Delphi objects:
```pascal
procedure TForm3.FormCreate(Sender: TObject);
begin
  HTMLRender1.RegisterObject('Form3', Self);
end;
```

Then in HTML:
```html
<span onclick="Form3:ShowSomething('World')">Click me</span>
<button onclick="Form3:HandleClick(document.getElementById('nameInput').value)">Submit</button>
```

The method is called directly:
```pascal
procedure TForm3.ShowSomething(Name: String);
begin
  ShowMessage('Hello ' + Name);
end;
```

### Supported Parameter Expressions {#param-expressions}

| Expression | Resolves to |
|---|---|
| `'literal'` or `"literal"` | String literal |
| `123` | Numeric literal |
| `this.value` | Value of the clicked element |
| `this.id` | ID of the clicked element |
| `document.getElementById('id').value` | Value of element by ID |
| `document.getElementById('id').<attr>` | Any attribute by ID |

## DOM Manipulation {#dom}

Modify rendered HTML elements from Delphi code at runtime:

```pascal
// Get/set values
HTMLRender1.SetElementValue('emailInput', 'user@example.com');
var Value := HTMLRender1.GetElementValue('emailInput');

// Enable/disable controls
HTMLRender1.SetElementEnabled('submitBtn', False);

// Show/hide elements
HTMLRender1.SetElementVisible('errorMessage', True);

// Change text content
HTMLRender1.SetElementText('statusLabel', 'Loading...');

// Change inline styles
HTMLRender1.SetElementStyle('myDiv', 'background-color', 'red');
```

### DOM Methods {#dom-methods}

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

## Image Loading and Caching {#images}

Images are downloaded via HTTP asynchronously and cached to disk.

```pascal
Tina4HTMLRender1.CacheEnabled := True;
Tina4HTMLRender1.CacheDir := 'C:\MyApp\cache';
Tina4HTMLRender1.HTML.Text := '<img src="https://example.com/photo.jpg" width="200" height="150">';
```

<div v-pre>

## Twig Template Integration {#twig}

The `Twig` property accepts Twig template content that is automatically rendered to HTML.

```pascal
// Set template variables first
Tina4HTMLRender1.SetTwigVariable('title', 'Hello World');
Tina4HTMLRender1.SetTwigVariable('name', 'Andre');

// Set Twig template -- automatically renders to HTML
Tina4HTMLRender1.Twig.Text :=
  '<h1>{{ title }}</h1>' +
  '<p>Welcome, {{ name }}!</p>' +
  '{% if name %}' +
  '  <p>User is logged in.</p>' +
  '{% endif %}';
```

For file-based templates:
```pascal
Tina4HTMLRender1.TwigTemplatePath := 'C:\MyApp\templates';
Tina4HTMLRender1.Twig.LoadFromFile('C:\MyApp\templates\page.html');
```

| Property / Method | Description |
|---|---|
| `Twig: TStringList` | Twig template content -- renders to HTML on change |
| `TwigTemplatePath: string` | Base path for `{% include %}` and `{% extends %}` |
| `SetTwigVariable(Name, Value)` | Pass a variable to the Twig context |

</div>
