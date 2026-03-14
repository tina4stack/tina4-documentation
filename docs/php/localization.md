# Localization
::: tip Hot Tips
- Tina4 localization is based on the GNU GetText standard.
- The `ext-gettext` PHP extension is recommended but not required -- a built-in `.po` file parser is included as a fallback.
- The base language is assumed to be English with UTF-8 encoding.
- GetText tooling (`msgfmt`, `msginit`, `xgettext`) ships in the `bin/` folder on Windows after module initialization.
:::

## Overview {#overview}

The `tina4stack/tina4php-localization` module lets you translate your application into multiple languages using the
well-established GetText workflow: mark translatable strings in your code, extract them into `.pot` / `.po` files,
compile to `.mo` files, and switch locale at runtime.

The main class is `\Tina4\Localization`. It wraps PHP's native `gettext` functions when the extension is available,
and falls back to parsing `.po` files directly when it is not.

## Installation {#installation}

Install the module via Composer:

```bash
composer require tina4stack/tina4php-localization
```

The module requires **PHP 8.1** or newer. The `ext-gettext` PHP extension is optional but recommended for production
use.

## Setting Up Locale Directories {#directory-structure}

GetText expects a specific directory layout. Create a `locale` folder at the root of your project with the following
structure:

```
locale/
  en_US/
    LC_MESSAGES/
      messages.po
      messages.mo
  es_ES/
    LC_MESSAGES/
      messages.po
      messages.mo
  de_DE/
    LC_MESSAGES/
      messages.po
      messages.mo
```

Each locale folder is named with the standard `language_COUNTRY` code (see the [Supported Locales](#supported-locales)
table below). Inside each locale you need a `LC_MESSAGES` directory containing your `.po` (source) and `.mo` (compiled)
files.

## Creating .po and .mo Files {#po-and-mo-files}

### The .pot Template

Start with a `.pot` (Portable Object Template) file that lists every translatable string. You can create one by hand or
extract strings from your source code with `xgettext`:

```bash
xgettext --language=PHP --from-code=UTF-8 -o template.pot src/*.php
```

A `.pot` file looks like this:

```
#: src/Controllers/HomeController.php:12
msgid "Enter a comma separated list of user names."
msgstr ""

#: src/Controllers/HomeController.php:25
msgid "Unable to find user: @users"
msgid_plural "Unable to find users: @users"
msgstr[0] ""
msgstr[1] ""
```

### Creating a .po File

Copy the template and fill in the translations for each locale:

```bash
cp template.pot locale/de_DE/LC_MESSAGES/messages.po
```

Then edit `messages.po` and fill in each `msgstr`:

```
msgid "Enter a comma separated list of user names."
msgstr "Eine kommagetrennte Liste von Benutzernamen."
```

For plurals, provide each form:

```
msgid "Unable to find user: @users"
msgid_plural "Unable to find users: @users"
msgstr[0] "Benutzer konnte nicht gefunden werden: @users"
msgstr[1] "Benutzer konnten nicht gefunden werden: @users"
```

### Compiling to .mo

The `.mo` (Machine Object) binary format is what GetText reads at runtime. Compile with `msgfmt`:

```bash
msgfmt locale/de_DE/LC_MESSAGES/messages.po -o locale/de_DE/LC_MESSAGES/messages.mo
```

::: warning
If you are relying on the native `ext-gettext` extension, you **must** compile `.mo` files. The fallback parser reads
`.po` files directly, so `.mo` compilation is only strictly required when `ext-gettext` is enabled.
:::

## Basic Usage in PHP {#php-usage}

### Creating a Localization Instance

```php
// Default: en_US locale, ./locale path, "messages" domain, UTF-8
$locale = new \Tina4\Localization();

// Custom locale and path
$locale = new \Tina4\Localization("de_DE", "./locale");

// Full control: locale, path, domain, codeset
$locale = new \Tina4\Localization("de_DE", "./locale", "messages", "UTF-8");
```

### Translating Strings

```php
// Simple translation
echo $locale->translate("Enter a comma separated list of user names.");
// Output: "Eine kommagetrennte Liste von Benutzernamen."

// The object is invokable, so this also works:
echo $locale("Enter a comma separated list of user names.");
```

### Plural Translations

```php
$count = 3;
echo $locale->translatePlural("Unable to find user: @users", "Unable to find users: @users", $count);
```

### Context-Based Translation

When the same English string has different meanings in different contexts, use `translateContext`:

```php
// "File" in a menu vs "File" as a document
echo $locale->translateContext("menu", "File");
echo $locale->translateContext("document", "File");
```

## Switching Locales {#switching-locales}

You can change the locale at runtime without creating a new instance:

```php
$locale = new \Tina4\Localization("en_US", "./locale");

echo $locale->translate("Hello World"); // English

$locale->setLocale("de_DE");
echo $locale->translate("Hello World"); // German

$locale->setLocale("es_ES");
echo $locale->translate("Hello World"); // Spanish
```

### Inspecting Available Locales

The module can scan your locale directory and return which locales have been set up:

```php
$locale = new \Tina4\Localization("en_US", "./locale");
$available = $locale->getAvailableLocales();
// e.g. ["de_DE", "en_US", "es_ES"]
```

### Checking GetText Availability

```php
if ($locale->isGettextAvailable()) {
    echo "Using native gettext extension";
} else {
    echo "Using fallback PO file parser";
}
```

## Usage in Twig Templates {#twig-usage}

To use translations inside Twig, pass the `Localization` instance (or a helper function) to your template context:

```php
\Tina4\Get::add("/home", function (\Tina4\Response $response) {
    $locale = new \Tina4\Localization("de_DE", "./locale");

    return $response(
        \Tina4\renderTemplate("home.twig", [
            "locale" => $locale,
            "greeting" => $locale->translate("Welcome to our site"),
        ])
    );
});
```

In your Twig template you can then output translated values:

```twig
<h1>{{ greeting }}</h1>
<p>{{ locale.translate("Enter a comma separated list of user names.") }}</p>
```

Alternatively, register a Twig function globally so every template can call it:

```php
// In your bootstrap or index.php
$locale = new \Tina4\Localization("de_DE", "./locale");

$twig->addFunction(new \Twig\TwigFunction('t', function (string $msg) use ($locale) {
    return $locale->translate($msg);
}));
```

Then in any template:

```twig
<h1>{{ t("Welcome to our site") }}</h1>
```

## Supported Locales {#supported-locales}

| Locale    | Language               | Country         |
|-----------|------------------------|-----------------|
| da_DK     | Danish                 | Denmark         |
| de_AT     | German                 | Austria         |
| de_CH     | German                 | Switzerland     |
| de_DE     | German                 | Germany         |
| el_GR     | Greek                  | Greece          |
| en_CA     | English                | Canada          |
| en_GB     | English                | United Kingdom  |
| en_IE     | English                | Ireland         |
| en_US     | English                | United States   |
| es_ES     | Spanish                | Spain           |
| fi_FI     | Finnish                | Finland         |
| fr_BE     | French                 | Belgium         |
| fr_CA     | French                 | Canada          |
| fr_CH     | French                 | Switzerland     |
| fr_FR     | French                 | France          |
| it_CH     | Italian                | Switzerland     |
| it_IT     | Italian                | Italy           |
| ja_JP     | Japanese               | Japan           |
| ko_KR     | Korean                 | Korea           |
| nl_BE     | Dutch                  | Belgium         |
| nl_NL     | Dutch                  | Netherlands     |
| no_NO     | Norwegian (Nynorsk)    | Norway          |
| no_NO_B   | Norwegian (Bokmal)     | Norway          |
| pt_PT     | Portuguese             | Portugal        |
| sv_SE     | Swedish                | Sweden          |
| tr_TR     | Turkish                | Turkey          |
| zh_CN     | Chinese (Simplified)   | China           |
| zh_TW     | Chinese (Traditional)  | Taiwan          |

::: tip
Any valid POSIX locale code works. The table above is a common reference -- you can add any locale by creating the
matching directory structure under your `locale/` folder.
:::

## API Reference {#api-reference}

| Method | Description |
|--------|-------------|
| `__construct(string $locale, string $localePath, string $domain, string $codeset)` | Create a new instance. All parameters are optional with sensible defaults. |
| `translate(string $message): string` | Translate a single string. |
| `translatePlural(string $singular, string $plural, int $count): string` | Translate a plural string based on count. |
| `translateContext(string $context, string $message): string` | Translate with disambiguation context. |
| `setLocale(string $locale): void` | Switch to a different locale at runtime. |
| `getLocale(): string` | Get the current locale string. |
| `getLocalePath(): string` | Get the configured locale directory path. |
| `getDomain(): string` | Get the current text domain. |
| `isGettextAvailable(): bool` | Check if the native gettext extension is loaded. |
| `getAvailableLocales(): array` | Scan the locale directory and return available locale codes. |
| `__invoke(string $message): string` | Shorthand -- call the object directly to translate. |
