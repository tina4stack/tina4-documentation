# Chapter 14: Localization

## 1. One App, Many Languages

Your app goes live. Users arrive from Germany, Brazil, Japan. Everything is in English. They bounce.

Localization (L10n) makes the same app speak every language. UI strings, error messages, date formats, and number formatting adapt to the user's locale. The code stays the same.

Tina4 provides a built-in `I18n` class that loads JSON locale files, interpolates variables, falls back to a default locale when a key is missing, and requires no external packages.

---

## 2. Locale Files

Store translations as JSON files. One file per locale. Place them in `src/locales/` by convention.

**`src/locales/en.json`:**

```json
{
  "welcome": "Welcome, {name}!",
  "goodbye": "Goodbye, {name}.",
  "errors": {
    "required": "The {field} field is required.",
    "min_length": "The {field} must be at least {min} characters.",
    "not_found": "The requested resource was not found."
  },
  "orders": {
    "count": "You have {count} order(s).",
    "empty": "You have no orders yet."
  },
  "nav": {
    "home": "Home",
    "products": "Products",
    "account": "My Account",
    "logout": "Log Out"
  }
}
```

**`src/locales/de.json`:**

```json
{
  "welcome": "Willkommen, {name}!",
  "goodbye": "Auf Wiedersehen, {name}.",
  "errors": {
    "required": "Das Feld {field} ist erforderlich.",
    "min_length": "Das Feld {field} muss mindestens {min} Zeichen lang sein.",
    "not_found": "Die angeforderte Ressource wurde nicht gefunden."
  },
  "orders": {
    "count": "Sie haben {count} Bestellung(en).",
    "empty": "Sie haben noch keine Bestellungen."
  },
  "nav": {
    "home": "Startseite",
    "products": "Produkte",
    "account": "Mein Konto",
    "logout": "Abmelden"
  }
}
```

**`src/locales/pt.json`:**

```json
{
  "welcome": "Bem-vindo, {name}!",
  "goodbye": "Até logo, {name}.",
  "errors": {
    "required": "O campo {field} é obrigatório.",
    "not_found": "O recurso solicitado não foi encontrado."
  },
  "nav": {
    "home": "Início",
    "products": "Produtos",
    "account": "Minha Conta",
    "logout": "Sair"
  }
}
```

---

## 3. Loading and Using I18n

```php
<?php
use Tina4\I18n;

// Load locale files
$i18n = new I18n('src/locales');

// Set the active locale
$i18n->setLocale('de');

// Translate a key
echo $i18n->t('welcome', ['name' => 'Alice']);
// Output: Willkommen, Alice!

echo $i18n->t('errors.not_found');
// Output: Die angeforderte Ressource wurde nicht gefunden.

echo $i18n->t('orders.count', ['count' => 3]);
// Output: Sie haben 3 Bestellung(en).
```

Dot notation navigates nested keys. `'errors.required'` accesses `$translations['errors']['required']`.

---

## 4. Fallback Locale

When a key exists in `en.json` but not in the active locale file, `I18n` falls back to the default locale automatically.

```php
<?php
use Tina4\I18n;

$i18n = new I18n('src/locales', defaultLocale: 'en');
$i18n->setLocale('pt');

// 'orders.count' missing from pt.json -- falls back to en.json
echo $i18n->t('orders.count', ['count' => 2]);
// Output: You have 2 order(s).

// 'nav.home' exists in pt.json
echo $i18n->t('nav.home');
// Output: Início
```

Fallback prevents blank strings from appearing in partially translated apps. Ship the English version first. Translations can come later without breaking anything.

---

## 5. Locale Switching in API Routes

Detect the locale from the `Accept-Language` header, a query parameter, or the user's profile. Then set it on the `I18n` instance.

```php
<?php
use Tina4\Router;
use Tina4\I18n;

$i18n = new I18n('src/locales', defaultLocale: 'en');

function resolveLocale($request, I18n $i18n): string {
    // 1. Query parameter: ?lang=de
    if (!empty($request->params['lang'])) {
        return $request->params['lang'];
    }

    // 2. Accept-Language header: Accept-Language: de-DE,de;q=0.9
    $header = $request->headers['Accept-Language'] ?? 'en';
    $primary = explode(',', $header)[0];
    $lang = explode('-', $primary)[0];

    // 3. Fall back to default
    return $i18n->hasLocale($lang) ? $lang : 'en';
}

/**
 * @noauth
 */
Router::get('/api/greeting', function ($request, $response) use ($i18n) {
    $locale = resolveLocale($request, $i18n);
    $i18n->setLocale($locale);

    $name = $request->params['name'] ?? 'stranger';

    return $response->json([
        'locale'  => $locale,
        'message' => $i18n->t('welcome', ['name' => $name]),
        'nav'     => [
            'home'     => $i18n->t('nav.home'),
            'products' => $i18n->t('nav.products'),
            'account'  => $i18n->t('nav.account')
        ]
    ]);
});
```

```bash
curl "http://localhost:7146/api/greeting?name=Alice&lang=de"
```

```json
{
  "locale": "de",
  "message": "Willkommen, Alice!",
  "nav": {
    "home": "Startseite",
    "products": "Produkte",
    "account": "Mein Konto"
  }
}
```

```bash
curl "http://localhost:7146/api/greeting?name=Alice&lang=pt"
```

```json
{
  "locale": "pt",
  "message": "Bem-vindo, Alice!",
  "nav": {
    "home": "Início",
    "products": "Produtos",
    "account": "Minha Conta"
  }
}
```

---

## 6. Interpolation

Placeholders use `{key}` syntax. Pass values as an associative array.

```php
<?php
use Tina4\I18n;

$i18n = new I18n('src/locales');
$i18n->setLocale('en');

// Single value
echo $i18n->t('welcome', ['name' => 'Bob']);
// Welcome, Bob!

// Multiple values
echo $i18n->t('errors.min_length', [
    'field' => 'password',
    'min'   => 8
]);
// The password must be at least 8 characters.

// Missing placeholder value -- left as-is
echo $i18n->t('welcome');
// Welcome, {name}!
```

No special escaping needed. Values are inserted as-is.

---

## 7. Checking Available Locales

```php
<?php
use Tina4\I18n;

$i18n = new I18n('src/locales');

// List all loaded locales
$locales = $i18n->getLocales();
// ['en', 'de', 'pt']

// Check if a locale exists
$has = $i18n->hasLocale('fr');  // false
$has = $i18n->hasLocale('de');  // true

// Get the current active locale
$current = $i18n->getLocale();  // 'en' (default)
```

Expose available locales via API for frontend locale switchers:

```php
Router::get('/api/locales', function ($request, $response) use ($i18n) {
    return $response->json([
        'available' => $i18n->getLocales(),
        'default'   => 'en'
    ]);
});
```

---

## 8. Localized Validation Errors

Return validation errors in the user's language:

```php
<?php
use Tina4\Router;
use Tina4\I18n;

$i18n = new I18n('src/locales', defaultLocale: 'en');

Router::post('/api/users', function ($request, $response) use ($i18n) {
    $lang = $request->params['lang'] ?? 'en';
    $i18n->setLocale($lang);
    $body = $request->body;

    $errors = [];

    if (empty($body['name'])) {
        $errors[] = $i18n->t('errors.required', ['field' => 'name']);
    }

    if (empty($body['email'])) {
        $errors[] = $i18n->t('errors.required', ['field' => 'email']);
    }

    if (!empty($body['password']) && strlen($body['password']) < 8) {
        $errors[] = $i18n->t('errors.min_length', ['field' => 'password', 'min' => 8]);
    }

    if (!empty($errors)) {
        return $response->json(['errors' => $errors], 422);
    }

    return $response->json(['message' => 'User created'], 201);
});
```

```bash
curl -X POST "http://localhost:7146/api/users?lang=de" \
  -H "Content-Type: application/json" \
  -d '{"password": "abc"}'
```

```json
{
  "errors": [
    "Das Feld name ist erforderlich.",
    "Das Feld email ist erforderlich.",
    "Das Feld password muss mindestens 8 Zeichen lang sein."
  ]
}
```

---

## 9. Adding Locales at Runtime

Load additional locale data programmatically (useful when translations come from a database):

```php
<?php
use Tina4\I18n;

$i18n = new I18n('src/locales');

// Add or extend a locale at runtime
$i18n->addTranslations('fr', [
    'welcome'    => 'Bienvenue, {name} !',
    'goodbye'    => 'Au revoir, {name}.',
    'nav' => [
        'home'     => 'Accueil',
        'products' => 'Produits',
        'account'  => 'Mon Compte',
        'logout'   => 'Déconnexion'
    ]
]);

$i18n->setLocale('fr');
echo $i18n->t('welcome', ['name' => 'Alice']);
// Bienvenue, Alice !
```

---

## 10. Exercise: Multilingual API

Build a product API that returns localized content.

### Requirements

1. Create locale files for `en`, `de`, and one other language of your choice with keys for:
   - `product.in_stock`, `product.out_of_stock`
   - `product.price` (e.g., "Price: {amount}")
   - `errors.not_found`

2. Create `GET /api/products/{id}` that:
   - Accepts `?lang=` query parameter
   - Returns product data with localized status and label strings

3. Create `GET /api/locales` that returns the list of available locales

### Test with:

```bash
curl "http://localhost:7146/api/products/1?lang=en"
curl "http://localhost:7146/api/products/1?lang=de"
curl "http://localhost:7146/api/products/999?lang=de"
curl "http://localhost:7146/api/locales"
```

---

## 11. Gotchas

### 1. Missing keys return the key name

**Problem:** The UI shows `errors.not_found` instead of a message.

**Cause:** The key does not exist in the active locale, and `defaultLocale` is not set or that locale also lacks the key.

**Fix:** Set `defaultLocale: 'en'` and ensure the English locale file has all keys. It is the source of truth.

### 2. Locale files not loaded

**Problem:** `$i18n->t('welcome')` returns the raw key on all locales.

**Cause:** The locale directory path is wrong, or JSON files have a syntax error.

**Fix:** Verify the path passed to `new I18n()` is correct relative to the project root. Validate JSON files with `php -r "echo json_encode(json_decode(file_get_contents('src/locales/en.json')));"`.

### 3. Placeholder not replaced

**Problem:** Output shows `Welcome, {name}!` with the literal `{name}`.

**Cause:** You called `$i18n->t('welcome')` without passing the values array.

**Fix:** Always pass replacement values: `$i18n->t('welcome', ['name' => $user['name']])`.

### 4. Locale not resetting between requests

**Problem:** After one request with `?lang=de`, subsequent requests without a `lang` parameter return German text.

**Cause:** The `I18n` instance is shared and locale state persists across the request lifecycle if the instance lives in a service container.

**Fix:** Always call `$i18n->setLocale($locale)` at the start of each request before calling `t()`. Do not assume the locale from a previous request.
