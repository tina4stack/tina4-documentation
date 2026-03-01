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
| `upper` | Uppercase | `{{ 'hello'\|upper }}` &rarr; `HELLO` |
| `lower` | Lowercase | `{{ 'HELLO'\|lower }}` &rarr; `hello` |
| `capitalize` | Capitalize first letter | `{{ 'hello'\|capitalize }}` &rarr; `Hello` |
| `title` | Title case | `{{ 'hello world'\|title }}` &rarr; `Hello World` |
| `trim` | Remove whitespace | `{{ ' hi '\|trim }}` &rarr; `hi` |
| `nl2br` | Newlines to `<br>` | `{{ text\|nl2br }}` |
| `striptags` | Remove HTML tags | `{{ html\|striptags }}` |
| `replace` | Replace values | `{{ 'hello'\|replace({'e': 'a'}) }}` |
| `split` | Split into array | `{{ 'a,b,c'\|split(',') }}` |
| `slug` | URL-friendly slug | `{{ 'Hello World'\|slug }}` &rarr; `hello-world` |
| `spaceless` | Remove whitespace between tags | `{{ html\|spaceless }}` |
| `u` | Unicode string | `{{ text\|u }}` |

### Number Filters {#number-filters}

| Filter | Description | Example |
|---|---|---|
| `abs` | Absolute value | `{{ -5\|abs }}` &rarr; `5` |
| `number_format` | Format number | `{{ 1234.5\|number_format(2, '.', ',') }}` |
| `format_number` | Format with decimals | `{{ 1234\|format_number }}` |
| `format_currency` | Format as currency | `{{ 1234\|format_currency('USD') }}` |

### Array Filters {#array-filters}

| Filter | Description | Example |
|---|---|---|
| `length` | Length of array/string | `{{ items\|length }}` |
| `first` | First element | `{{ items\|first }}` |
| `last` | Last element | `{{ items\|last }}` |
| `join` | Join into string | `{{ items\|join(', ') }}` |
| `keys` | Get array keys | `{{ obj\|keys }}` |
| `merge` | Merge arrays | `{{ arr1\|merge(arr2) }}` |
| `sort` | Sort array | `{{ items\|sort }}` |
| `reverse` | Reverse array/string | `{{ items\|reverse }}` |
| `shuffle` | Randomize order | `{{ items\|shuffle }}` |
| `slice` | Extract portion | `{{ items\|slice(1, 3) }}` |
| `batch` | Split into chunks | `{{ items\|batch(3) }}` |
| `column` | Extract column | `{{ users\|column('name') }}` |
| `filter` | Filter with callback | `{{ items\|filter }}` |
| `find` | Find value | `{{ items\|find }}` |
| `map` | Map with callback | `{{ items\|map }}` |
| `reduce` | Reduce to single value | `{{ items\|reduce }}` |
| `min` | Minimum value | `{{ items\|min }}` |
| `max` | Maximum value | `{{ items\|max }}` |

### Date Filters {#date-filters}

| Filter | Description | Example |
|---|---|---|
| `date` | Format date | `{{ post.created\|date('Y-m-d') }}` |
| `date_modify` | Modify date | `{{ date\|date_modify('+1 day') }}` |
| `format_date` | Format date (alias) | `{{ date\|format_date }}` |
| `format_datetime` | Format datetime (alias) | `{{ date\|format_datetime }}` |
| `format_time` | Format time | `{{ date\|format_time }}` |

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
| `escape` / `e` | Escape HTML entities | `{{ html\|escape }}` |
| `raw` | No escaping | `{{ html\|raw }}` |
| `url_encode` | URL encode | `{{ text\|url_encode }}` |
| `json_encode` | Encode to JSON | `{{ data\|json_encode }}` |
| `json_decode` | Decode from JSON | `{{ json\|json_decode }}` |
| `convert_encoding` | Convert charset | `{{ text\|convert_encoding('UTF-8') }}` |
| `data_uri` | Create data URI | `{{ content\|data_uri }}` |

### Other Filters {#other-filters}

| Filter | Description |
|---|---|
| `default` | Fallback value: `{{ name\|default('Guest') }}` |
| `format` | String formatting: `{{ 'Hi %s'\|format(name) }}` |
| `plural` | Plural form |
| `singular` | Singular form |

## Functions {#functions}

| Function | Description | Example |
|---|---|---|
| `range` | Generate number/letter sequence | `{% for i in range(1, 10) %}` |
| `dump` | Debug output | `{{ dump(variable) }}` |
| `date` | Create/format dates | `{{ date('now', 'Y-m-d') }}` |

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
