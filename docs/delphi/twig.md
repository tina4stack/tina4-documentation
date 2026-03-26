# Twig Templates

::: tip
TTina4Twig is a Twig-compatible template engine for server-side rendering, supporting variables, control structures, filters, functions, template inheritance, and macros.
:::

## Basic Usage {#usage}

```pascal
var
  Twig: TTina4Twig;
  Variables: TStringDict;
begin
  Twig := TTina4Twig.Create('C:\templates');
  Variables := TStringDict.Create;
  try
    Variables.Add('name', 'Andre');
    Variables.Add('items', TValue.From<TArray<String>>(['Apple', 'Banana', 'Cherry']));

    Memo1.Lines.Text := Twig.Render('hello.html', Variables);
  finally
    Variables.Free;
    Twig.Free;
  end;
end;
```

<div v-pre>

## Variables {#variables}

Output variables with double curly braces:

```
{{ name }}
{{ user.email }}
```

### Setting Variables {#set}

```
{% set greeting = 'Hello' %}
{% set items = ['Apple', 'Banana'] %}
{% set total = price * quantity %}
```

## Control Structures {#control}

### if / elseif / else {#if}

```
{% if users|length > 0 %}
  <ul>
    {% for user in users %}
      <li>{{ user.name }}</li>
    {% endfor %}
  </ul>
{% elseif guests|length > 0 %}
  <p>Guests only</p>
{% else %}
  <p>No users found</p>
{% endif %}
```

### for loops {#for}

```
{% for item in items %}
  <p>{{ item }}</p>
{% endfor %}

{% for key, value in pairs %}
  <p>{{ key }}: {{ value }}</p>
{% endfor %}

{% for i in 0..10 %}
  <p>{{ i }}</p>
{% endfor %}
```

### with {#with}

Scopes variables to a block:

```
{% with { title: 'Hello' } %}
  <h1>{{ title }}</h1>
{% endwith %}
```

## Template Inheritance {#inheritance}

### extends and block {#extends}

**base.html:**
```
<html>
<head><title>{% block title %}Default{% endblock %}</title></head>
<body>
  {% block content %}{% endblock %}
</body>
</html>
```

**page.html:**
```
{% extends 'base.html' %}

{% block title %}My Page{% endblock %}

{% block content %}
  <h1>Hello World</h1>
{% endblock %}
```

### include {#include}

```
{% include 'header.html' %}
{% include 'sidebar.html' with { menu: items } %}
```

</div>

Set the template path so includes resolve correctly:

```pascal
Twig := TTina4Twig.Create('C:\MyApp\templates');
```

<div v-pre>

## Macros {#macros}

Define reusable template fragments:

```
{% macro input(name, value, type) %}
  <input type="{{ type|default('text') }}" name="{{ name }}" value="{{ value }}">
{% endmacro %}

{{ input('username', '', 'text') }}
{{ input('password', '', 'password') }}
```

## Filters {#filters}

Filters transform values using the pipe `|` operator. They can be chained:

```
{{ name|upper|length }}
```

### String Filters {#string-filters}

| Filter | Description | Example |
|---|---|---|
| `upper` | Uppercase | `<span v-pre>{{ 'hello'\|upper }}</span>` &rarr; `HELLO` |
| `lower` | Lowercase | `<span v-pre>{{ 'HELLO'\|lower }}</span>` &rarr; `hello` |
| `capitalize` | Capitalize first letter | `<span v-pre>{{ 'hello'\|capitalize }}</span>` &rarr; `Hello` |
| `title` | Title case | `<span v-pre>{{ 'hello world'\|title }}</span>` &rarr; `Hello World` |
| `trim` | Remove whitespace | `<span v-pre>{{ ' hi '\|trim }}</span>` &rarr; `hi` |
| `nl2br` | Newlines to `<br>` | `<span v-pre>{{ text\|nl2br }}</span>` |
| `striptags` | Remove HTML tags | `<span v-pre>{{ html\|striptags }}</span>` |
| `replace` | Replace values | `<span v-pre>{{ 'hello'\|replace({'e': 'a'}) }}</span>` |
| `split` | Split into array | `<span v-pre>{{ 'a,b,c'\|split(',') }}</span>` |
| `slug` | URL-friendly slug | `<span v-pre>{{ 'Hello World'\|slug }}</span>` &rarr; `hello-world` |
| `spaceless` | Remove whitespace between tags | `<span v-pre>{{ html\|spaceless }}</span>` |
| `u` | Unicode string | `<span v-pre>{{ text\|u }}</span>` |

### Number Filters {#number-filters}

| Filter | Description | Example |
|---|---|---|
| `abs` | Absolute value | `<span v-pre>{{ -5\|abs }}</span>` &rarr; `5` |
| `number_format` | Format number | `<span v-pre>{{ 1234.5\|number_format(2, '.', ',') }}</span>` |
| `format_number` | Format with decimals | `<span v-pre>{{ 1234\|format_number }}</span>` |
| `format_currency` | Format as currency | `<span v-pre>{{ 1234\|format_currency('USD') }}</span>` |

### Array Filters {#array-filters}

| Filter | Description | Example |
|---|---|---|
| `length` | Length of array/string | `<span v-pre>{{ items\|length }}</span>` |
| `first` | First element | `<span v-pre>{{ items\|first }}</span>` |
| `last` | Last element | `<span v-pre>{{ items\|last }}</span>` |
| `join` | Join into string | `<span v-pre>{{ items\|join(', ') }}</span>` |
| `keys` | Get array keys | `<span v-pre>{{ obj\|keys }}</span>` |
| `merge` | Merge arrays | `<span v-pre>{{ arr1\|merge(arr2) }}</span>` |
| `sort` | Sort array | `<span v-pre>{{ items\|sort }}</span>` |
| `reverse` | Reverse array/string | `<span v-pre>{{ items\|reverse }}</span>` |
| `shuffle` | Randomize order | `<span v-pre>{{ items\|shuffle }}</span>` |
| `slice` | Extract portion | `<span v-pre>{{ items\|slice(1, 3) }}</span>` |
| `batch` | Split into chunks | `<span v-pre>{{ items\|batch(3) }}</span>` |
| `column` | Extract column | `<span v-pre>{{ users\|column('name') }}</span>` |
| `filter` | Filter with callback | `<span v-pre>{{ items\|filter }}</span>` |
| `find` | Find value | `<span v-pre>{{ items\|find }}</span>` |
| `map` | Map with callback | `<span v-pre>{{ items\|map }}</span>` |
| `reduce` | Reduce to single value | `<span v-pre>{{ items\|reduce }}</span>` |
| `min` | Minimum value | `<span v-pre>{{ items\|min }}</span>` |
| `max` | Maximum value | `<span v-pre>{{ items\|max }}</span>` |

### Date Filters {#date-filters}

| Filter | Description | Example |
|---|---|---|
| `date` | Format date | `<span v-pre>{{ post.created\|date('Y-m-d') }}</span>` |
| `date_modify` | Modify date | `<span v-pre>{{ date\|date_modify('+1 day') }}</span>` |
| `format_date` | Format date (alias) | `<span v-pre>{{ date\|format_date }}</span>` |
| `format_datetime` | Format datetime (alias) | `<span v-pre>{{ date\|format_datetime }}</span>` |
| `format_time` | Format time | `<span v-pre>{{ date\|format_time }}</span>` |

</div>

Date format uses PHP-style specifiers that are automatically converted:

| Specifier | Meaning | Example |
|---|---|---|
| `Y` | 4-digit year | `2026` |
| `y` | 2-digit year | `26` |
| `m` | Month (zero-padded) | `03` |
| `n` | Month (no padding) | `3` |
| `d` | Day (zero-padded) | `01` |
| `j` | Day (no padding) | `1` |
| `H` | Hour 24h (zero-padded) | `14` |
| `h` | Hour 12h (zero-padded) | `02` |
| `i` | Minutes | `30` |
| `s` | Seconds | `05` |
| `A` | AM/PM | `PM` |
| `D` | Short day name | `Mon` |
| `l` | Full day name | `Monday` |
| `M` | Short month name | `Jan` |
| `F` | Full month name | `January` |

<div v-pre>

### Encoding Filters {#encoding-filters}

| Filter | Description | Example |
|---|---|---|
| `escape` / `e` | Escape HTML entities | `<span v-pre>{{ html\|escape }}</span>` |
| `raw` | No escaping | `<span v-pre>{{ html\|raw }}</span>` |
| `url_encode` | URL encode | `<span v-pre>{{ text\|url_encode }}</span>` |
| `json_encode` | Encode to JSON | `<span v-pre>{{ data\|json_encode }}</span>` |
| `json_decode` | Decode from JSON | `<span v-pre>{{ json\|json_decode }}</span>` |
| `convert_encoding` | Convert charset | `<span v-pre>{{ text\|convert_encoding('UTF-8') }}</span>` |
| `data_uri` | Create data URI | `<span v-pre>{{ content\|data_uri }}</span>` |

### Other Filters {#other-filters}

| Filter | Description |
|---|---|
| `default` | Fallback value: `<span v-pre>{{ name\|default('Guest') }}</span>` |
| `format` | String formatting: `<span v-pre>{{ 'Hi %s'\|format(name) }}</span>` |
| `plural` | Plural form |
| `singular` | Singular form |

## Functions {#functions}

| Function | Description | Example |
|---|---|---|
| `range` | Generate number/letter sequence | `{% for i in range(1, 10) %}` |
| `dump` | Debug output | `<span v-pre>{{ dump(variable) }}</span>` |
| `date` | Create/format dates | `<span v-pre>{{ date('now', 'Y-m-d') }}</span>` |

</div>

## Operators {#operators}

| Category | Operators |
|---|---|
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Logical | `and`, `or`, `not` |
| String | `~` (concatenation), `in`, `starts with`, `ends with`, `matches` |
| Math | `+`, `-`, `*`, `/`, `%`, `**` |
| Range | `..` (e.g., `1..10`, `'a'..'z'`) |

## Integration with TTina4HTMLRender {#html-render}

The HTML renderer has built-in Twig support via its `Twig` property:

<div v-pre>

```pascal
Tina4HTMLRender1.SetTwigVariable('title', 'Hello');
Tina4HTMLRender1.Twig.Text := '<h1>{{ title }}</h1>';
```

</div>

See [HTML Renderer - Twig Integration](/delphi/html-render.md#twig) for details.
