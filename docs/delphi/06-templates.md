# Chapter 6: Twig Templates

## HTML Without the String Concatenation Hell

You have built REST calls. You have populated MemTables. You have rendered HTML in your Delphi forms. But every time you construct HTML, you end up with code like this:

```pascal
HTML := '<div class="card">' +
  '<h2>' + Customer.Name + '</h2>' +
  '<p>' + Customer.Email + '</p>' +
  '</div>';
```

Six lines. Two bugs waiting to happen. One missing quote away from a broken layout. And when the designer changes the card to include a phone number, you are back in the Pascal editor, escaping quotes and hoping the HTML is still valid.

<div v-pre>

Twig templates fix this. Write HTML in HTML files. Drop in variables with `{{ name }}`. Add loops with `{% for %}`. Inherit layouts with `{% extends %}`. The template engine handles the rest. Your Pascal code passes data in; the template decides how to display it.

</div>

TTina4Twig is a Twig-compatible engine built directly into the Tina4 Delphi component library. It supports variables, control structures, filters, functions, template inheritance, macros, and integration with the HTML renderer. Every feature documented here works at design time and runtime.

---

## 1. TTina4Twig Standalone Usage

The simplest way to use Twig is standalone -- create an instance, set variables, render a template string or file.

### Create and Render

```pascal
uses
  Tina4Twig;

procedure TForm1.RenderGreeting;
var
  Twig: TTina4Twig;
  Variables: TStringDict;
begin
  Twig := TTina4Twig.Create('C:\MyApp\templates');
  Variables := TStringDict.Create;
  try
    Variables.Add('name', 'Andre');
    Variables.Add('role', 'Developer');

    Memo1.Lines.Text := Twig.Render('greeting.html', Variables);
  finally
    Variables.Free;
    Twig.Free;
  end;
end;
```

<div v-pre>

The constructor takes a template path. This is the root directory where Twig looks for template files referenced by `{% include %}` and `{% extends %}` tags. Every file reference is relative to this path.

</div>

### Render from a String

You can also render inline template strings without loading from a file:

```pascal
var
  Twig: TTina4Twig;
  Variables: TStringDict;
begin
  Twig := TTina4Twig.Create('');
  Variables := TStringDict.Create;
  try
    Variables.Add('name', 'World');

    Memo1.Lines.Text := Twig.Render(
      '<h1>Hello {{ name }}!</h1>', Variables);
    // Output: <h1>Hello World!</h1>
  finally
    Variables.Free;
    Twig.Free;
  end;
end;
```

### Passing Complex Data

Variables can be strings, numbers, arrays, or nested objects:

```pascal
Variables.Add('name', 'Andre');
Variables.Add('score', TValue.From<Integer>(42));
Variables.Add('items', TValue.From<TArray<String>>(['Apple', 'Banana', 'Cherry']));
```

---

## 2. Variables

Variables are the bridge between your Pascal code and your templates. Everything you pass via `SetVariable` or through a `TStringDict` is accessible inside double curly braces.

### Simple Variables

```
Hello {{ name }}!
Your score is {{ score }}.
```

### Nested Properties

Access object properties with dot notation:

```
{{ user.email }}
{{ order.customer.name }}
{{ settings.theme.primaryColor }}
```

### Setting Variables Inside Templates

<div v-pre>

Use `{% set %}` to define variables directly in a template:

</div>

```
{% set greeting = 'Hello' %}
{% set items = ['Apple', 'Banana'] %}
{% set total = price * quantity %}
{% set fullName = firstName ~ ' ' ~ lastName %}

<p>{{ greeting }}, {{ fullName }}!</p>
<p>Total: {{ total }}</p>
```

<div v-pre>

The `~` operator concatenates strings. Variables set with `{% set %}` are scoped to the current template block.

</div>

---

## 3. Control Structures

### if / elseif / else

Conditional rendering. Test any expression -- variable truthiness, comparisons, filters:

```
{% if users|length > 0 %}
  <ul>
    {% for user in users %}
      <li>{{ user.name }}</li>
    {% endfor %}
  </ul>
{% elseif guests|length > 0 %}
  <p>Guests only today.</p>
{% else %}
  <p>No users found.</p>
{% endif %}
```

Combine conditions with `and`, `or`, `not`:

```
{% if user.isAdmin and user.isActive %}
  <a href="#admin">Admin Panel</a>
{% endif %}

{% if not user.isVerified %}
  <div class="alert alert-warning">Please verify your email.</div>
{% endif %}
```

### for Loops

Iterate over arrays:

```
{% for item in items %}
  <p>{{ item }}</p>
{% endfor %}
```

Key-value pairs:

```
{% for key, value in settings %}
  <tr>
    <td>{{ key }}</td>
    <td>{{ value }}</td>
  </tr>
{% endfor %}
```

Ranges:

```
{% for i in 0..10 %}
  <option value="{{ i }}">{{ i }}</option>
{% endfor %}

{% for letter in 'a'..'f' %}
  <span>{{ letter }}</span>
{% endfor %}
```

The `loop` variable is available inside every for loop:

```
{% for item in items %}
  <tr class="{% if loop.first %}first{% endif %}{% if loop.last %}last{% endif %}">
    <td>{{ loop.index }}</td>
    <td>{{ item.name }}</td>
  </tr>
{% endfor %}
```

### with Blocks

Scope variables to a block without polluting the outer context:

```
{% with { title: 'Dashboard', subtitle: 'Overview' } %}
  <div class="header">
    <h1>{{ title }}</h1>
    <p>{{ subtitle }}</p>
  </div>
{% endwith %}
```

---

## 4. Template Inheritance

This is where Twig saves you from copy-pasting the same header and footer into 30 pages.

### Base Template (base.html)

```html
<!DOCTYPE html>
<html>
<head>
  <title>&#123;% block title %&#125;My App&#123;% endblock %&#125;</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
    .header { background: #2c3e50; color: white; padding: 15px; }
    .content { padding: 20px; }
    .footer { border-top: 1px solid #ccc; padding: 10px; color: #666; }
  </style>
  &#123;% block head %&#125;&#123;% endblock %&#125;
</head>
<body>
  <div class="header">
    <h1>&#123;% block header %&#125;My Application&#123;% endblock %&#125;</h1>
  </div>
  <div class="content">
    &#123;% block content %&#125;&#123;% endblock %&#125;
  </div>
  <div class="footer">
    &#123;% block footer %&#125;&copy; 2026 My Company&#123;% endblock %&#125;
  </div>
</body>
</html>
```

### Child Template (dashboard.html)

```html
&#123;% extends 'base.html' %&#125;

&#123;% block title %&#125;Dashboard - My App&#123;% endblock %&#125;

&#123;% block header %&#125;Dashboard&#123;% endblock %&#125;

&#123;% block content %&#125;
  <h2>Welcome, &#123;&#123; userName &#125;&#125;</h2>
  <p>You have &#123;&#123; messageCount &#125;&#125; new messages.</p>
&#123;% endblock %&#125;
```

The child template only defines the blocks it wants to override. Everything else comes from the base. Change the footer in `base.html` and every page that extends it picks up the change.

### include

Pull in reusable fragments:

```
{% include 'header.html' %}

<div class="main">
  {% include 'sidebar.html' with { menu: menuItems } %}
  <div class="content">
    {{ content }}
  </div>
</div>

{% include 'footer.html' %}
```

The `with` clause passes variables to the included template. Without it, the included template inherits the parent's variables.

### Setting the Template Path in Pascal

<div v-pre>

For `{% extends %}` and `{% include %}` to resolve correctly, set the template path:

</div>

```pascal
Twig := TTina4Twig.Create('C:\MyApp\templates');
```

<div v-pre>

All template references are relative to this path. If `dashboard.html` says `{% extends 'base.html' %}`, Twig looks for `C:\MyApp\templates\base.html`.

</div>

---

## 5. Macros

Macros are reusable template fragments -- the Twig equivalent of functions. Define them once, call them everywhere.

### Define a Macro

```
{% macro input(name, value, type) %}
  <div class="form-group">
    <label for="{{ name }}">{{ name|capitalize }}</label>
    <input type="{{ type|default('text') }}"
           id="{{ name }}"
           name="{{ name }}"
           value="{{ value }}"
           class="form-control">
  </div>
{% endmacro %}
```

### Call a Macro

```
{{ input('username', '', 'text') }}
{{ input('email', user.email, 'email') }}
{{ input('password', '', 'password') }}
```

### A More Complex Macro

```
{% macro alert(message, type) %}
  <div class="alert alert-{{ type|default('info') }}" role="alert">
    {% if type == 'danger' %}
      <strong>Error!</strong>
    {% elseif type == 'warning' %}
      <strong>Warning!</strong>
    {% endif %}
    {{ message }}
  </div>
{% endmacro %}

{{ alert('Record saved successfully.', 'success') }}
{{ alert('Please check your input.', 'warning') }}
{{ alert('Connection failed.', 'danger') }}
```

---

## 6. Filters Reference

Filters transform output values. Chain them with the pipe `|` operator:

```
{{ name|upper|length }}
{{ description|striptags|trim|truncate(100) }}
```

### String Filters

| Filter | What it does | Example |
|---|---|---|
<div v-pre>

| `upper` | Uppercase | `{{ 'hello'\|upper }}` produces `HELLO` |
| `lower` | Lowercase | `{{ 'HELLO'\|lower }}` produces `hello` |
| `capitalize` | First letter uppercase | `{{ 'hello world'\|capitalize }}` produces `Hello world` |
| `title` | Title case every word | `{{ 'hello world'\|title }}` produces `Hello World` |
| `trim` | Strip leading/trailing whitespace | `{{ '  hi  '\|trim }}` produces `hi` |
| `nl2br` | Convert newlines to `<br>` | `{{ "line1\nline2"\|nl2br }}` |
| `striptags` | Remove HTML tags | `{{ '<b>bold</b>'\|striptags }}` produces `bold` |
| `replace` | Replace substrings | `{{ 'hello'\|replace({'e': 'a'}) }}` produces `hallo` |
| `split` | Split into array | `{{ 'a,b,c'\|split(',') }}` produces `['a','b','c']` |
| `slug` | URL-friendly slug | `{{ 'Hello World!'\|slug }}` produces `hello-world` |
| `spaceless` | Remove whitespace between HTML tags | `{{ '<p> hi </p>'\|spaceless }}` |
| `u` | Unicode string wrapper | `{{ text\|u }}` |

</div>

**Practical example -- building a navigation menu:**

```
{% for page in pages %}
  <a href="/{{ page.title|slug }}"
     class="nav-link {% if page.title == currentPage %}active{% endif %}">
    {{ page.title|title }}
  </a>
{% endfor %}
```

### Number Filters

| Filter | What it does | Example |
|---|---|---|
<div v-pre>

| `abs` | Absolute value | `{{ -42\|abs }}` produces `42` |
| `number_format` | Format with decimals, separators | `{{ 1234.5\|number_format(2, '.', ',') }}` produces `1,234.50` |
| `format_number` | Locale-aware number format | `{{ 1234\|format_number }}` |
| `format_currency` | Format as currency | `{{ 1234.50\|format_currency('USD') }}` produces `$1,234.50` |

</div>

**Practical example -- product pricing:**

```
{% for product in products %}
  <div class="product-card">
    <h3>{{ product.name }}</h3>
    <p class="price">{{ product.price|format_currency('USD') }}</p>
    {% if product.discount > 0 %}
      <p class="discount">Save {{ product.discount|abs }}%</p>
    {% endif %}
  </div>
{% endfor %}
```

### Array Filters

| Filter | What it does | Example |
|---|---|---|
<div v-pre>

| `length` | Count elements | `{{ items\|length }}` |
| `first` | First element | `{{ items\|first }}` |
| `last` | Last element | `{{ items\|last }}` |
| `join` | Join into string | `{{ items\|join(', ') }}` |
| `keys` | Get object keys | `{{ settings\|keys }}` |
| `merge` | Merge two arrays | `{{ defaults\|merge(overrides) }}` |
| `sort` | Sort ascending | `{{ items\|sort }}` |
| `reverse` | Reverse order | `{{ items\|reverse }}` |
| `shuffle` | Random order | `{{ items\|shuffle }}` |
| `slice` | Extract subset | `{{ items\|slice(0, 5) }}` -- first 5 items |
| `batch` | Split into chunks | `{{ items\|batch(3) }}` -- groups of 3 |
| `column` | Extract one property | `{{ users\|column('name') }}` |
| `filter` | Keep matching items | `{{ items\|filter }}` |
| `find` | Find first match | `{{ items\|find }}` |
| `map` | Transform each item | `{{ items\|map }}` |
| `reduce` | Reduce to single value | `{{ items\|reduce }}` |
| `min` | Smallest value | `{{ prices\|min }}` |
| `max` | Largest value | `{{ prices\|max }}` |

</div>

**Practical example -- rendering a product grid:**

```
{% for row in products|batch(3) %}
  <div class="row">
    {% for product in row %}
      <div class="col">
        <h4>{{ product.name }}</h4>
        <p>{{ product.price|number_format(2) }}</p>
      </div>
    {% endfor %}
  </div>
{% endfor %}

<p>Showing {{ products|length }} products.
   Price range: {{ products|column('price')|min|format_currency('USD') }}
   to {{ products|column('price')|max|format_currency('USD') }}</p>

<p>Categories: {{ products|column('category')|sort|join(', ') }}</p>
```

### Date Filters

| Filter | What it does | Example |
|---|---|---|
<div v-pre>

| `date` | Format a date | `{{ order.created\|date('Y-m-d') }}` |
| `date_modify` | Shift a date | `{{ order.created\|date_modify('+30 days') }}` |
| `format_date` | Format date (alias) | `{{ order.created\|format_date }}` |
| `format_datetime` | Format date and time | `{{ order.created\|format_datetime }}` |
| `format_time` | Format time only | `{{ order.created\|format_time }}` |

</div>

**Date format specifiers** (PHP-style, auto-converted by Tina4):

| Specifier | Meaning | Output |
|---|---|---|
| `Y` | 4-digit year | `2026` |
| `y` | 2-digit year | `26` |
| `m` | Month, zero-padded | `03` |
| `n` | Month, no padding | `3` |
| `d` | Day, zero-padded | `01` |
| `j` | Day, no padding | `1` |
| `H` | Hour 24h, zero-padded | `14` |
| `h` | Hour 12h, zero-padded | `02` |
| `i` | Minutes | `30` |
| `s` | Seconds | `05` |
| `A` | AM/PM | `PM` |
| `D` | Short day name | `Mon` |
| `l` | Full day name | `Monday` |
| `M` | Short month name | `Jan` |
| `F` | Full month name | `January` |

**Practical example -- order timeline:**

```
<h3>Order #{{ order.id }}</h3>
<table>
  <tr>
    <td>Placed:</td>
    <td>{{ order.created|date('F j, Y') }} at {{ order.created|date('h:i A') }}</td>
  </tr>
  <tr>
    <td>Ships by:</td>
    <td>{{ order.created|date_modify('+3 days')|date('F j, Y') }}</td>
  </tr>
  <tr>
    <td>Delivery estimate:</td>
    <td>{{ order.created|date_modify('+7 days')|date('l, F j') }}</td>
  </tr>
</table>
```

### Encoding Filters

| Filter | What it does | Example |
|---|---|---|
<div v-pre>

| `escape` / `e` | Escape HTML entities | `{{ userInput\|escape }}` |
| `raw` | Output without escaping | `{{ trustedHtml\|raw }}` |
| `url_encode` | URL-encode a string | `{{ query\|url_encode }}` |
| `json_encode` | Encode as JSON | `{{ data\|json_encode }}` |
| `json_decode` | Decode from JSON | `{{ jsonString\|json_decode }}` |
| `convert_encoding` | Convert character encoding | `{{ text\|convert_encoding('UTF-8') }}` |
| `data_uri` | Create a data URI | `{{ imageData\|data_uri }}` |

</div>

**Practical example -- building a search URL:**

```
<a href="/search?q={{ searchTerm|url_encode }}&category={{ category|url_encode }}">
  Search for "{{ searchTerm|escape }}"
</a>

<script>
  var config = {{ appSettings|json_encode|raw }};
</script>
```

### Other Filters

| Filter | What it does | Example |
|---|---|---|
<div v-pre>

| `default` | Fallback value if empty/null | `{{ name\|default('Guest') }}` |
| `format` | Printf-style formatting | `{{ 'Hello %s, you have %d items'\|format(name, count) }}` |
| `plural` | Pluralize a word | `{{ 'item'\|plural }}` produces `items` |
| `singular` | Singularize a word | `{{ 'items'\|singular }}` produces `item` |

</div>

```
<p>You have {{ count }} {{ 'item'|plural }} in your cart.</p>
<p>Welcome, {{ userName|default('Guest') }}!</p>
<p>{{ 'Found %d %s in %s'|format(results|length, 'result'|plural, category) }}</p>
```

---

## 7. Functions

Functions work like filters but are called directly:

| Function | What it does | Example |
|---|---|---|
<div v-pre>

| `range()` | Generate a sequence | `{% for i in range(1, 10) %}` |
| `dump()` | Debug output of a variable | `{{ dump(user) }}` |
| `date()` | Create or format a date | `{{ date('now', 'Y-m-d') }}` |

</div>

```
{# Generate page numbers #}
{% for page in range(1, totalPages) %}
  <a href="?page={{ page }}"
     class="{% if page == currentPage %}active{% endif %}">
    {{ page }}
  </a>
{% endfor %}

{# Debug during development #}
{% if debug %}
  <pre>{{ dump(order) }}</pre>
{% endif %}

{# Show current date #}
<p>Report generated: {{ date('now', 'F j, Y \\a\\t h:i A') }}</p>
```

---

## 8. Operators

| Category | Operators | Example |
|---|---|---|
<div v-pre>

| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` | `{% if price > 100 %}` |
| Logical | `and`, `or`, `not` | `{% if active and verified %}` |
| String | `~` (concat), `in`, `starts with`, `ends with`, `matches` | `{{ first ~ ' ' ~ last }}` |
| Math | `+`, `-`, `*`, `/`, `%`, `**` | `{{ price * quantity }}` |
| Range | `..` | `{% for i in 1..10 %}` |

</div>

**String operators in action:**

```
{# Concatenation #}
{% set fullName = firstName ~ ' ' ~ lastName %}

{# Membership test #}
{% if 'admin' in user.roles %}
  <a href="#admin">Admin Panel</a>
{% endif %}

{# String matching #}
{% if email ends with '@company.com' %}
  <span class="badge">Internal</span>
{% endif %}

{% if filename starts with 'report_' %}
  <span class="badge">Report</span>
{% endif %}

{% if phone matches '/^\\+27/' %}
  <span>South Africa</span>
{% endif %}
```

---

## 9. Integration with TTina4HTMLRender

The HTML renderer has built-in Twig support. You do not need to create a standalone TTina4Twig instance -- the renderer handles it internally.

### Setting Variables and Rendering

```pascal
// Set variables before assigning the template
Tina4HTMLRender1.SetTwigVariable('title', 'Dashboard');
Tina4HTMLRender1.SetTwigVariable('userName', 'Andre');
Tina4HTMLRender1.SetTwigVariable('messageCount', '5');

// Set the Twig template -- it renders to HTML automatically
Tina4HTMLRender1.Twig.Text :=
  '<div class="header">' +
  '  <h1>{{ title }}</h1>' +
  '  <p>Welcome back, {{ userName }}! You have {{ messageCount }} new messages.</p>' +
  '</div>';
```

### File-Based Templates with the Renderer

```pascal
// Set the template path for includes and extends
Tina4HTMLRender1.TwigTemplatePath := 'C:\MyApp\templates';

// Set variables
Tina4HTMLRender1.SetTwigVariable('userName', 'Andre');
Tina4HTMLRender1.SetTwigVariable('notifications', '3');

// Load from file -- Twig processes it, then the renderer displays the HTML
Tina4HTMLRender1.Twig.LoadFromFile('C:\MyApp\templates\dashboard.html');
```

### Combining with REST Data

The real power emerges when you combine REST data with Twig templates:

```pascal
procedure TForm1.LoadCustomerCard(CustomerID: Integer);
var
  StatusCode: Integer;
  Response: TJSONObject;
begin
  Response := Tina4REST1.Get(StatusCode, '/customers/' + CustomerID.ToString);
  try
    Tina4HTMLRender1.SetTwigVariable('customer',
      Response.GetValue<String>('name'));
    Tina4HTMLRender1.SetTwigVariable('email',
      Response.GetValue<String>('email'));
    Tina4HTMLRender1.SetTwigVariable('orders',
      Response.GetValue<String>('orderCount'));

    Tina4HTMLRender1.Twig.LoadFromFile(
      'C:\MyApp\templates\customer-card.html');
  finally
    Response.Free;
  end;
end;
```

---

## 10. Complete Example: Email Template System

Build a reusable email template system with a base layout, customer notification, and order confirmation.

### File Structure

```
templates/
  email/
    base.html           -- shared email layout
    notification.html   -- customer notification
    order-confirm.html  -- order confirmation with product loop
```

### base.html

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f4; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 8px; overflow: hidden; }
    .header { background: #2c3e50; color: white; padding: 20px; text-align: center; }
    .content { padding: 30px; }
    .footer { background: #ecf0f1; padding: 15px; text-align: center; font-size: 12px; color: #666; }
    .btn { display: inline-block; padding: 10px 20px; background: #1abc9c; color: white; text-decoration: none; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>&#123;% block header %&#125;&#123;&#123; companyName|default('My Company') &#125;&#125;&#123;% endblock %&#125;</h1>
    </div>
    <div class="content">
      &#123;% block content %&#125;&#123;% endblock %&#125;
    </div>
    <div class="footer">
      &#123;% block footer %&#125;
        &copy; &#123;&#123; date('now', 'Y') &#125;&#125; &#123;&#123; companyName|default('My Company') &#125;&#125;. All rights reserved.
      &#123;% endblock %&#125;
    </div>
  </div>
</body>
</html>
```

### notification.html

```html
&#123;% extends 'email/base.html' %&#125;

&#123;% block header %&#125;Notification&#123;% endblock %&#125;

&#123;% block content %&#125;
  <h2>Hello &#123;&#123; customerName|default('Customer') &#125;&#125;,</h2>
  <p>&#123;&#123; message &#125;&#125;</p>

  &#123;% if actionUrl %&#125;
    <p style="text-align: center; margin: 30px 0;">
      <a href="&#123;&#123; actionUrl &#125;&#125;" class="btn">&#123;&#123; actionText|default('View Details') &#125;&#125;</a>
    </p>
  &#123;% endif %&#125;

  &#123;% if notes|length > 0 %&#125;
    <h3>Additional Notes:</h3>
    <ul>
      &#123;% for note in notes %&#125;
        <li>&#123;&#123; note &#125;&#125;</li>
      &#123;% endfor %&#125;
    </ul>
  &#123;% endif %&#125;
&#123;% endblock %&#125;
```

### order-confirm.html

```html
&#123;% extends 'email/base.html' %&#125;

&#123;% block header %&#125;Order Confirmation&#123;% endblock %&#125;

&#123;% block content %&#125;
  <h2>Thank you, &#123;&#123; customerName &#125;&#125;!</h2>
  <p>Your order <strong>#&#123;&#123; orderId &#125;&#125;</strong> has been confirmed.</p>
  <p>Placed on: &#123;&#123; orderDate|date('F j, Y') &#125;&#125;</p>

  <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
    <thead>
      <tr style="background: #ecf0f1;">
        <th style="padding: 10px; text-align: left;">Product</th>
        <th style="padding: 10px; text-align: right;">Qty</th>
        <th style="padding: 10px; text-align: right;">Price</th>
        <th style="padding: 10px; text-align: right;">Total</th>
      </tr>
    </thead>
    <tbody>
      &#123;% for item in items %&#125;
        <tr style="border-bottom: 1px solid #eee;">
          <td style="padding: 10px;">&#123;&#123; item.name &#125;&#125;</td>
          <td style="padding: 10px; text-align: right;">&#123;&#123; item.quantity &#125;&#125;</td>
          <td style="padding: 10px; text-align: right;">&#123;&#123; item.price|format_currency('USD') &#125;&#125;</td>
          <td style="padding: 10px; text-align: right;">&#123;&#123; item.total|format_currency('USD') &#125;&#125;</td>
        </tr>
      &#123;% endfor %&#125;
    </tbody>
    <tfoot>
      <tr>
        <td colspan="3" style="padding: 10px; text-align: right;"><strong>Subtotal:</strong></td>
        <td style="padding: 10px; text-align: right;">&#123;&#123; subtotal|format_currency('USD') &#125;&#125;</td>
      </tr>
      <tr>
        <td colspan="3" style="padding: 10px; text-align: right;">Tax (&#123;&#123; taxRate &#125;&#125;%):</td>
        <td style="padding: 10px; text-align: right;">&#123;&#123; tax|format_currency('USD') &#125;&#125;</td>
      </tr>
      &#123;% if discount > 0 %&#125;
        <tr style="color: #e74c3c;">
          <td colspan="3" style="padding: 10px; text-align: right;">Discount:</td>
          <td style="padding: 10px; text-align: right;">-&#123;&#123; discount|format_currency('USD') &#125;&#125;</td>
        </tr>
      &#123;% endif %&#125;
      <tr style="font-size: 1.2em; font-weight: bold;">
        <td colspan="3" style="padding: 10px; text-align: right;">Total:</td>
        <td style="padding: 10px; text-align: right;">&#123;&#123; grandTotal|format_currency('USD') &#125;&#125;</td>
      </tr>
    </tfoot>
  </table>

  <p>Estimated delivery: &#123;&#123; orderDate|date_modify('+5 days')|date('l, F j, Y') &#125;&#125;</p>
&#123;% endblock %&#125;
```

### Pascal Code to Render

```pascal
procedure TForm1.SendOrderConfirmation(OrderID: Integer);
var
  Twig: TTina4Twig;
  Variables: TStringDict;
  EmailBody: String;
begin
  Twig := TTina4Twig.Create('C:\MyApp\templates');
  Variables := TStringDict.Create;
  try
    Variables.Add('companyName', 'Acme Store');
    Variables.Add('customerName', 'Andre van Zuydam');
    Variables.Add('orderId', OrderID.ToString);
    Variables.Add('orderDate', FormatDateTime('yyyy-mm-dd', Now));
    Variables.Add('subtotal', '149.97');
    Variables.Add('taxRate', '15');
    Variables.Add('tax', '22.50');
    Variables.Add('discount', '10.00');
    Variables.Add('grandTotal', '162.47');

    // Items would be passed as a JSON array string or structured data
    Variables.Add('items', '[' +
      '{"name": "Widget Pro", "quantity": "2", "price": "49.99", "total": "99.98"},' +
      '{"name": "Gadget Mini", "quantity": "1", "price": "49.99", "total": "49.99"}' +
      ']');

    EmailBody := Twig.Render('email/order-confirm.html', Variables);
    Memo1.Lines.Text := EmailBody;
  finally
    Variables.Free;
    Twig.Free;
  end;
end;
```

---

## 11. Complete Example: Report Generator

Build a product catalog report with categories, pricing, inventory status, filters, and macros.

### report-catalog.html

```html
&#123;% macro statusBadge(quantity) %&#125;
  &#123;% if quantity > 10 %&#125;
    <span style="color: #27ae60; font-weight: bold;">In Stock (&#123;&#123; quantity &#125;&#125;)</span>
  &#123;% elseif quantity > 0 %&#125;
    <span style="color: #f39c12; font-weight: bold;">Low Stock (&#123;&#123; quantity &#125;&#125;)</span>
  &#123;% else %&#125;
    <span style="color: #e74c3c; font-weight: bold;">Out of Stock</span>
  &#123;% endif %&#125;
&#123;% endmacro %&#125;

&#123;% macro priceCell(price, discount) %&#125;
  &#123;% if discount > 0 %&#125;
    <span style="text-decoration: line-through; color: #999;">&#123;&#123; price|format_currency('USD') &#125;&#125;</span>
    <span style="color: #e74c3c; font-weight: bold;">
      &#123;&#123; (price - discount)|format_currency('USD') &#125;&#125;
    </span>
  &#123;% else %&#125;
    &#123;&#123; price|format_currency('USD') &#125;&#125;
  &#123;% endif %&#125;
&#123;% endmacro %&#125;

<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #2c3e50; }
    h2 { color: #34495e; border-bottom: 2px solid #1abc9c; padding-bottom: 5px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
    th { background: #2c3e50; color: white; padding: 10px; text-align: left; }
    td { padding: 8px; border-bottom: 1px solid #eee; }
    tr:nth-child(even) { background: #f9f9f9; }
    .summary { background: #ecf0f1; padding: 15px; border-radius: 8px; margin: 20px 0; }
  </style>
</head>
<body>
  <h1>&#123;&#123; reportTitle|default('Product Catalog') &#125;&#125;</h1>
  <p>Generated: &#123;&#123; date('now', 'F j, Y \\a\\t h:i A') &#125;&#125;</p>
  <p>Total products: &#123;&#123; products|length &#125;&#125;</p>

  <div class="summary">
    <strong>Price Range:</strong>
    &#123;&#123; products|column('price')|min|format_currency('USD') &#125;&#125; -
    &#123;&#123; products|column('price')|max|format_currency('USD') &#125;&#125;
  </div>

  &#123;% for category in categories %&#125;
    <h2>&#123;&#123; category.name|title &#125;&#125;</h2>

    &#123;% set categoryProducts = products|filter %&#125;

    <table>
      <thead>
        <tr>
          <th>#</th>
          <th>Product</th>
          <th>SKU</th>
          <th>Price</th>
          <th>Stock</th>
        </tr>
      </thead>
      <tbody>
        &#123;% for product in category.products %&#125;
          <tr>
            <td>&#123;&#123; loop.index &#125;&#125;</td>
            <td>
              <strong>&#123;&#123; product.name &#125;&#125;</strong>
              &#123;% if product.description %&#125;
                <br><small style="color: #666;">&#123;&#123; product.description|striptags|slice(0, 80) &#125;&#125;...</small>
              &#123;% endif %&#125;
            </td>
            <td>&#123;&#123; product.sku|upper &#125;&#125;</td>
            <td>&#123;&#123; priceCell(product.price, product.discount|default(0)) &#125;&#125;</td>
            <td>&#123;&#123; statusBadge(product.stock) &#125;&#125;</td>
          </tr>
        &#123;% endfor %&#125;
      </tbody>
    </table>
  &#123;% endfor %&#125;

  <div class="summary">
    <h3>Report Summary</h3>
    <p>Categories: &#123;&#123; categories|length &#125;&#125;</p>
    <p>Total Products: &#123;&#123; products|length &#125;&#125;</p>
    <p>Products in stock: &#123;&#123; products|column('stock')|filter|length &#125;&#125;</p>
  </div>
</body>
</html>
```

### Pascal Code

```pascal
procedure TForm1.GenerateCatalogReport;
var
  Twig: TTina4Twig;
  Variables: TStringDict;
begin
  Twig := TTina4Twig.Create('C:\MyApp\templates');
  Variables := TStringDict.Create;
  try
    Variables.Add('reportTitle', 'Q1 2026 Product Catalog');

    // In a real app, this data comes from GetJSONFromDB or a REST call
    Variables.Add('categories', '[' +
      '{"name": "electronics", "products": [' +
        '{"name": "USB-C Hub", "sku": "elec-001", "price": "29.99", "stock": "45", "description": "7-port USB-C hub with HDMI"},' +
        '{"name": "Wireless Mouse", "sku": "elec-002", "price": "19.99", "stock": "3", "discount": "5.00"},' +
        '{"name": "Mechanical Keyboard", "sku": "elec-003", "price": "89.99", "stock": "0"}' +
      ']},' +
      '{"name": "office supplies", "products": [' +
        '{"name": "Notebook Set", "sku": "off-001", "price": "12.99", "stock": "120"},' +
        '{"name": "Pen Pack", "sku": "off-002", "price": "8.99", "stock": "200"}' +
      ']}' +
      ']');

    Variables.Add('products', '[' +
      '{"name": "USB-C Hub", "price": "29.99", "stock": "45"},' +
      '{"name": "Wireless Mouse", "price": "19.99", "stock": "3"},' +
      '{"name": "Mechanical Keyboard", "price": "89.99", "stock": "0"},' +
      '{"name": "Notebook Set", "price": "12.99", "stock": "120"},' +
      '{"name": "Pen Pack", "price": "8.99", "stock": "200"}' +
      ']');

    WebBrowser1.Navigate('about:blank');
    // Render and display the report
    var HTML := Twig.Render('report-catalog.html', Variables);
    Memo1.Lines.Text := HTML;
  finally
    Variables.Free;
    Twig.Free;
  end;
end;
```

---

## Exercise: Invoice Template

**Build an invoice template** with the following requirements:

1. Company header with logo placeholder, company name, and address
2. Customer billing and shipping address blocks
3. Line items loop with description, quantity, unit price, and line total
4. Subtotal, tax (configurable rate), and grand total calculations
5. Conditional discount display (only shows discount row if discount > 0)
6. Payment terms section with due date (30 days from invoice date)
7. Use macros for the address block (reuse for billing and shipping)
8. Use template inheritance -- extend a base invoice layout

### Solution

**invoice-base.html:**

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 30px; color: #333; }
    .invoice-header { display: flex; justify-content: space-between; margin-bottom: 30px; }
    .company-info h1 { margin: 0; color: #2c3e50; }
    .invoice-meta { text-align: right; }
    .addresses { display: flex; gap: 40px; margin-bottom: 30px; }
    .address-block { flex: 1; }
    .address-block h3 { color: #2c3e50; margin-bottom: 5px; }
    table { width: 100%; border-collapse: collapse; }
    th { background: #2c3e50; color: white; padding: 10px; text-align: left; }
    td { padding: 8px 10px; border-bottom: 1px solid #eee; }
    .totals td { border: none; }
    .grand-total { font-size: 1.3em; font-weight: bold; color: #2c3e50; }
    .terms { margin-top: 30px; padding: 15px; background: #f9f9f9; border-radius: 4px; }
  </style>
  &#123;% block head %&#125;&#123;% endblock %&#125;
</head>
<body>
  &#123;% block invoice %&#125;&#123;% endblock %&#125;
</body>
</html>
```

**invoice.html:**

```html
&#123;% extends 'invoice-base.html' %&#125;

&#123;% macro addressBlock(label, addr) %&#125;
  <div class="address-block">
    <h3>&#123;&#123; label &#125;&#125;</h3>
    <p>
      <strong>&#123;&#123; addr.name &#125;&#125;</strong><br>
      &#123;&#123; addr.street &#125;&#125;<br>
      &#123;&#123; addr.city &#125;&#125;, &#123;&#123; addr.state &#125;&#125; &#123;&#123; addr.zip &#125;&#125;<br>
      &#123;% if addr.country %&#125;&#123;&#123; addr.country &#125;&#125;<br>&#123;% endif %&#125;
      &#123;% if addr.phone %&#125;Tel: &#123;&#123; addr.phone &#125;&#125;&#123;% endif %&#125;
    </p>
  </div>
&#123;% endmacro %&#125;

&#123;% block invoice %&#125;
  <div class="invoice-header">
    <div class="company-info">
      <h1>&#123;&#123; company.name &#125;&#125;</h1>
      <p>&#123;&#123; company.address &#125;&#125;<br>
         &#123;&#123; company.city &#125;&#125;, &#123;&#123; company.state &#125;&#125; &#123;&#123; company.zip &#125;&#125;<br>
         &#123;&#123; company.email &#125;&#125;</p>
    </div>
    <div class="invoice-meta">
      <h2>INVOICE</h2>
      <p>
        <strong>Invoice #:</strong> &#123;&#123; invoiceNumber &#125;&#125;<br>
        <strong>Date:</strong> &#123;&#123; invoiceDate|date('F j, Y') &#125;&#125;<br>
        <strong>Due Date:</strong> &#123;&#123; invoiceDate|date_modify('+30 days')|date('F j, Y') &#125;&#125;
      </p>
    </div>
  </div>

  <div class="addresses">
    &#123;&#123; addressBlock('Bill To', billing) &#125;&#125;
    &#123;&#123; addressBlock('Ship To', shipping) &#125;&#125;
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 50%;">Description</th>
        <th style="text-align: right;">Qty</th>
        <th style="text-align: right;">Unit Price</th>
        <th style="text-align: right;">Total</th>
      </tr>
    </thead>
    <tbody>
      &#123;% for item in lineItems %&#125;
        <tr>
          <td>&#123;&#123; item.description &#125;&#125;</td>
          <td style="text-align: right;">&#123;&#123; item.quantity &#125;&#125;</td>
          <td style="text-align: right;">&#123;&#123; item.unitPrice|format_currency('USD') &#125;&#125;</td>
          <td style="text-align: right;">&#123;&#123; item.lineTotal|format_currency('USD') &#125;&#125;</td>
        </tr>
      &#123;% endfor %&#125;
    </tbody>
    <tfoot>
      <tr class="totals">
        <td colspan="3" style="text-align: right; padding-top: 15px;"><strong>Subtotal:</strong></td>
        <td style="text-align: right; padding-top: 15px;">&#123;&#123; subtotal|format_currency('USD') &#125;&#125;</td>
      </tr>
      &#123;% if discount > 0 %&#125;
        <tr class="totals" style="color: #27ae60;">
          <td colspan="3" style="text-align: right;">Discount (&#123;&#123; discountPercent &#125;&#125;%):</td>
          <td style="text-align: right;">-&#123;&#123; discount|format_currency('USD') &#125;&#125;</td>
        </tr>
      &#123;% endif %&#125;
      <tr class="totals">
        <td colspan="3" style="text-align: right;">Tax (&#123;&#123; taxRate &#125;&#125;%):</td>
        <td style="text-align: right;">&#123;&#123; tax|format_currency('USD') &#125;&#125;</td>
      </tr>
      <tr class="totals grand-total">
        <td colspan="3" style="text-align: right;">Total Due:</td>
        <td style="text-align: right;">&#123;&#123; grandTotal|format_currency('USD') &#125;&#125;</td>
      </tr>
    </tfoot>
  </table>

  <div class="terms">
    <h3>Payment Terms</h3>
    <p>Payment is due within 30 days of the invoice date.
       Please reference invoice #&#123;&#123; invoiceNumber &#125;&#125; with your payment.</p>
    <p>Bank: &#123;&#123; company.bank|default('First National Bank') &#125;&#125;<br>
       Account: &#123;&#123; company.account|default('Contact us for details') &#125;&#125;</p>
  </div>
&#123;% endblock %&#125;
```

**Pascal code to render the invoice:**

```pascal
procedure TForm1.GenerateInvoice;
var
  Twig: TTina4Twig;
  Variables: TStringDict;
begin
  Twig := TTina4Twig.Create('C:\MyApp\templates');
  Variables := TStringDict.Create;
  try
    Variables.Add('invoiceNumber', 'INV-2026-0042');
    Variables.Add('invoiceDate', FormatDateTime('yyyy-mm-dd', Now));

    Variables.Add('company', '{"name": "Acme Corp", "address": "123 Main St", ' +
      '"city": "Cape Town", "state": "WC", "zip": "8001", ' +
      '"email": "billing@acme.co.za"}');

    Variables.Add('billing', '{"name": "John Smith", "street": "456 Oak Ave", ' +
      '"city": "Johannesburg", "state": "GP", "zip": "2001", "phone": "+27 11 555 0123"}');

    Variables.Add('shipping', '{"name": "John Smith", "street": "789 Pine Rd", ' +
      '"city": "Durban", "state": "KZN", "zip": "4001"}');

    Variables.Add('lineItems', '[' +
      '{"description": "Widget Pro - Annual License", "quantity": "5", "unitPrice": "99.00", "lineTotal": "495.00"},' +
      '{"description": "Setup & Configuration", "quantity": "1", "unitPrice": "250.00", "lineTotal": "250.00"},' +
      '{"description": "Training (per hour)", "quantity": "4", "unitPrice": "75.00", "lineTotal": "300.00"}' +
      ']');

    Variables.Add('subtotal', '1045.00');
    Variables.Add('discountPercent', '10');
    Variables.Add('discount', '104.50');
    Variables.Add('taxRate', '15');
    Variables.Add('tax', '141.08');
    Variables.Add('grandTotal', '1081.58');

    Memo1.Lines.Text := Twig.Render('invoice.html', Variables);
  finally
    Variables.Free;
    Twig.Free;
  end;
end;
```

---

## Common Gotchas

<div v-pre>

**Template path resolution.** Every `{% extends %}` and `{% include %}` path is relative to the path you pass to `TTina4Twig.Create()`. If you pass an empty string, file-based template references will fail silently. Always set a real path:

</div>

```pascal
// Wrong -- includes and extends will not find files
Twig := TTina4Twig.Create('');

// Right
Twig := TTina4Twig.Create('C:\MyApp\templates');
```

<div v-pre>

**Variable scope in for loops.** Variables set inside a `{% for %}` block do not persist outside the loop. This trips people up when trying to accumulate a total:

</div>

```
{# This does NOT work as expected #}
{% set total = 0 %}
{% for item in items %}
  {% set total = total + item.price %}
{% endfor %}
<p>Total: {{ total }}</p>  {# Still 0! #}
```

Calculate totals in your Pascal code and pass them as variables instead.

**HTML escaping by default.** Twig escapes HTML entities by default. If you pass pre-formatted HTML as a variable, it will show raw tags. Use the `raw` filter for trusted content:

```
{# Variable contains '<strong>Bold</strong>' #}
{{ content }}          {# Shows: &lt;strong&gt;Bold&lt;/strong&gt; #}
{{ content|raw }}      {# Shows: Bold (rendered as HTML) #}
```

Only use `raw` on content you control. Never use it on user input.

**TStringDict memory management.** Always free the `TStringDict` and `TTina4Twig` in a `try/finally` block. Forgetting this is the most common memory leak with Twig templates:

```pascal
Twig := TTina4Twig.Create('C:\templates');
Variables := TStringDict.Create;
try
  // ... render ...
finally
  Variables.Free;  // Always free both
  Twig.Free;
end;
```

<div v-pre>

**Whitespace in templates.** Twig preserves whitespace exactly as written in the template. If you see extra blank lines in your output, your template has extra blank lines. Use `{%-` and `-%}` to trim whitespace around tags:

</div>

```
{%- for item in items -%}
  <li>{{ item }}</li>
{%- endfor -%}
```
