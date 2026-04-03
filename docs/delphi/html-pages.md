# Page Navigation

::: tip
TTina4HTMLPages provides SPA-style page navigation using TTina4HTMLRender. Pages are defined as a collection at design time. Navigation is triggered by `<a href="#pagename">` links.
:::

## Basic Setup {#setup}

```pascal
// Drop TTina4HTMLPages and TTina4HTMLRender on the form
// Link them at design time or runtime:
Tina4HTMLPages1.Renderer := Tina4HTMLRender1;

// Pages are defined in the collection editor at design time,
// or created at runtime:
var Page := Tina4HTMLPages1.Pages.Add;
Page.PageName := 'home';
Page.IsDefault := True;
Page.HTMLContent.Text := '<h1>Home</h1><a href="#about">Go to About</a>';

Page := Tina4HTMLPages1.Pages.Add;
Page.PageName := 'about';
Page.HTMLContent.Text := '<h1>About</h1><a href="#home">Back to Home</a>';
```

<div v-pre>

## Navigation with Frond (Twig) Templates {#twig}

Pages can use Twig templates instead of raw HTML:

```pascal
Tina4HTMLPages1.SetTwigVariable('userName', 'Andre');

var Page := Tina4HTMLPages1.Pages.Add;
Page.PageName := 'dashboard';
Page.TwigContent.Text :=
  '<h1>Welcome {{ userName }}</h1>' +
  '<a href="#settings">Settings</a>';
```

</div>

For file-based templates with `{% include %}` or `{% extends %}`:
```pascal
Tina4HTMLPages1.TwigTemplatePath := 'C:\MyApp\templates';
```

## Programmatic Navigation {#navigate}

```pascal
Tina4HTMLPages1.NavigateTo('dashboard');
```

## Link Convention {#links}

Anchor `href` values are mapped to page names by stripping the leading `#` or `/`:

| `href` value | Maps to PageName |
|---|---|
| `#dashboard` | `dashboard` |
| `/settings` | `settings` |
| `about` | `about` |

## Events {#events}

| Event | Signature | Description |
|---|---|---|
| `OnBeforeNavigate` | `procedure(Sender: TObject; const FromPage, ToPage: string; var Allow: Boolean)` | Fires before navigation; set `Allow := False` to cancel |
| `OnAfterNavigate` | `procedure(Sender: TObject)` | Fires after the new page has been rendered |

## TTina4Page Properties {#page-properties}

| Property | Type | Description |
|---|---|---|
| `PageName` | `string` | Unique name used as navigation target |
| `TwigContent` | `TStringList` | Twig template source (rendered via TTina4Twig) |
| `HTMLContent` | `TStringList` | Raw HTML (used when TwigContent is empty) |
| `IsDefault` | `Boolean` | If `True`, this page is shown on startup |

## TTina4HTMLPages Properties {#component-properties}

| Property | Type | Description |
|---|---|---|
| `Pages` | `TTina4PageCollection` | Collection of pages (design-time editable) |
| `Renderer` | `TTina4HTMLRender` | The HTML renderer that displays the active page |
| `ActivePage` | `string` | Name of the currently displayed page |
| `TwigTemplatePath` | `string` | Base path for Twig `{% include %}` / `{% extends %}` |
