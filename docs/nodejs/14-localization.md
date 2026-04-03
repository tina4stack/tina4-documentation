# Chapter 14: Localization

## 1. Your App Speaks One Language. Your Users Speak Many.

An e-commerce store. Half your traffic is German. Error messages in English. Product descriptions in English. Currency formatted American-style. Visitors leave.

Localization means serving content in the user's language and format. Tina4 provides an `I18n` class that loads JSON locale files, interpolates variables, falls back to a default locale when a key is missing, and switches locale per request.

---

## 2. Locale Files

Locale files are JSON files stored in a `locales/` directory in your project root. One file per language:

```
locales/
  en.json
  de.json
  fr.json
  es.json
```

`locales/en.json`:

```json
{
  "welcome": "Welcome, {{name}}!",
  "errors": {
    "not_found": "The page you requested was not found.",
    "unauthorized": "You must be logged in to access this page.",
    "validation": "{{field}} is required."
  },
  "orders": {
    "placed": "Your order #{{orderId}} has been placed.",
    "total": "Total: {{currency}}{{amount}}"
  },
  "nav": {
    "home": "Home",
    "products": "Products",
    "cart": "Cart",
    "account": "Account"
  }
}
```

`locales/de.json`:

```json
{
  "welcome": "Willkommen, {{name}}!",
  "errors": {
    "not_found": "Die angeforderte Seite wurde nicht gefunden.",
    "unauthorized": "Sie müssen angemeldet sein, um auf diese Seite zuzugreifen.",
    "validation": "{{field}} ist erforderlich."
  },
  "orders": {
    "placed": "Ihre Bestellung #{{orderId}} wurde aufgegeben.",
    "total": "Gesamt: {{currency}}{{amount}}"
  },
  "nav": {
    "home": "Startseite",
    "products": "Produkte",
    "cart": "Warenkorb",
    "account": "Konto"
  }
}
```

---

## 3. Creating an I18n Instance

```typescript
import { I18n } from "tina4-nodejs";

// Loads all JSON files from ./locales/
// Default locale is "en"
const i18n = new I18n({
    localesPath: "./locales",
    defaultLocale: "en"
});
```

| Option | Default | Description |
|--------|---------|-------------|
| `localesPath` | `"./locales"` | Directory containing locale JSON files |
| `defaultLocale` | `"en"` | Fallback locale when a key is missing |
| `fallbackLocale` | same as `defaultLocale` | Explicit fallback, if different from default |

---

## 4. Translating Keys with t()

The `t()` method looks up a translation key in the current locale:

```typescript
const i18n = new I18n({ localesPath: "./locales", defaultLocale: "en" });

i18n.setLocale("en");
console.log(i18n.t("nav.home"));         // "Home"
console.log(i18n.t("nav.products"));     // "Products"

i18n.setLocale("de");
console.log(i18n.t("nav.home"));         // "Startseite"
console.log(i18n.t("nav.products"));     // "Produkte"
```

Keys use dot notation to access nested values. `"errors.not_found"` reaches `errors -> not_found` in the JSON file.

---

## 5. Interpolation

Pass variables to replace `{{placeholder}}` tokens:

```typescript
i18n.setLocale("en");
console.log(i18n.t("welcome", { name: "Alice" }));
// "Welcome, Alice!"

console.log(i18n.t("errors.validation", { field: "Email" }));
// "Email is required."

console.log(i18n.t("orders.placed", { orderId: "10042" }));
// "Your order #10042 has been placed."

i18n.setLocale("de");
console.log(i18n.t("welcome", { name: "Alice" }));
// "Willkommen, Alice!"
```

Any key not found in the variables object is left as-is in the output string.

---

## 6. Locale Switching Per Request

Detect the user's preferred locale from the `Accept-Language` header, a query parameter, or a session value:

```typescript
import { Router, I18n } from "tina4-nodejs";

const i18n = new I18n({ localesPath: "./locales", defaultLocale: "en" });

Router.get("/api/greeting", async (req, res) => {
    // Priority: ?lang query param > Accept-Language header > default
    const lang = req.query.lang
        ?? (req.headers["accept-language"]?.split(",")[0]?.split("-")[0])
        ?? "en";

    i18n.setLocale(lang);

    return res.json({
        locale: lang,
        message: i18n.t("welcome", { name: req.query.name ?? "guest" })
    });
});
```

```bash
curl "http://localhost:7145/api/greeting?name=Alice&lang=de"
```

```json
{
  "locale": "de",
  "message": "Willkommen, Alice!"
}
```

```bash
curl "http://localhost:7145/api/greeting?name=Alice&lang=en"
```

```json
{
  "locale": "en",
  "message": "Welcome, Alice!"
}
```

---

## 7. Fallback Locale

When a key exists in the default locale but is missing from the requested locale, `I18n` falls back automatically rather than returning an empty string or throwing:

```typescript
// locales/fr.json is missing the "orders" section
i18n.setLocale("fr");
console.log(i18n.t("orders.placed", { orderId: "202" }));
// Falls back to "en": "Your order #202 has been placed."
```

The fallback locale is configured once and applied globally. You never need to check whether a translation exists before calling `t()`.

---

## 8. Listing Available Locales

```typescript
const locales = i18n.availableLocales();
console.log(locales);
// ["en", "de", "fr", "es"]
```

Use this to build a language picker in your UI or to validate the `lang` parameter on requests.

---

## 9. Using I18n in Templates

Pass the translation function to Frond templates:

```typescript
import { Router, I18n } from "tina4-nodejs";

const i18n = new I18n({ localesPath: "./locales", defaultLocale: "en" });

Router.get("/store", async (req, res) => {
    const lang = req.query.lang ?? "en";
    i18n.setLocale(lang as string);

    return res.render("store.frond", {
        t: (key: string, vars?: Record<string, string>) => i18n.t(key, vars),
        locale: lang,
        locales: i18n.availableLocales()
    });
});
```

In `templates/store.frond`:

```html
<nav>
  <a href="/">{{t("nav.home")}}</a>
  <a href="/products">{{t("nav.products")}}</a>
  <a href="/cart">{{t("nav.cart")}}</a>
</nav>
```

---

## 10. Exercise: Multilingual API Errors

Build an API that returns validation error messages in the user's language.

### Requirements

1. Create locale files for `en` and `de` with an `errors` section covering `required`, `too_short`, and `invalid_email`
2. Create a `POST /api/contact` endpoint that validates a `name` (required, min 2 chars) and `email` (required, valid format) field
3. Return error messages in the locale specified by the `lang` query parameter (default: `en`)

### Test with:

```bash
# English errors
curl -X POST "http://localhost:7145/api/contact?lang=en" \
  -H "Content-Type: application/json" \
  -d '{"name": "A", "email": "not-an-email"}'

# German errors
curl -X POST "http://localhost:7145/api/contact?lang=de" \
  -H "Content-Type: application/json" \
  -d '{"name": "A", "email": "not-an-email"}'
```

---

## 11. Solution

`locales/en.json`:

```json
{
  "errors": {
    "required": "{{field}} is required.",
    "too_short": "{{field}} must be at least {{min}} characters.",
    "invalid_email": "{{field}} must be a valid email address."
  },
  "contact": {
    "success": "Thank you, {{name}}. We will be in touch."
  }
}
```

`locales/de.json`:

```json
{
  "errors": {
    "required": "{{field}} ist erforderlich.",
    "too_short": "{{field}} muss mindestens {{min}} Zeichen lang sein.",
    "invalid_email": "{{field}} muss eine gültige E-Mail-Adresse sein."
  },
  "contact": {
    "success": "Danke, {{name}}. Wir werden uns bei Ihnen melden."
  }
}
```

`src/routes/contact.ts`:

```typescript
import { Router, I18n } from "tina4-nodejs";

const i18n = new I18n({ localesPath: "./locales", defaultLocale: "en" });

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

Router.post("/api/contact", async (req, res) => {
    const lang = (req.query.lang ?? "en") as string;
    i18n.setLocale(lang);

    const body = req.body;
    const errors: string[] = [];

    if (!body.name) {
        errors.push(i18n.t("errors.required", { field: "Name" }));
    } else if (String(body.name).length < 2) {
        errors.push(i18n.t("errors.too_short", { field: "Name", min: "2" }));
    }

    if (!body.email) {
        errors.push(i18n.t("errors.required", { field: "Email" }));
    } else if (!EMAIL_RE.test(String(body.email))) {
        errors.push(i18n.t("errors.invalid_email", { field: "Email" }));
    }

    if (errors.length > 0) {
        return res.status(422).json({ locale: lang, errors });
    }

    return res.json({
        locale: lang,
        message: i18n.t("contact.success", { name: body.name })
    });
});
```

English error response:

```json
{
  "locale": "en",
  "errors": [
    "Name must be at least 2 characters.",
    "Email must be a valid email address."
  ]
}
```

German error response:

```json
{
  "locale": "de",
  "errors": [
    "Name muss mindestens 2 Zeichen lang sein.",
    "Email muss eine gültige E-Mail-Adresse sein."
  ]
}
```

---

## 12. Gotchas

### 1. Locale files must be valid JSON

A trailing comma or missing quote breaks the entire locale file silently. `I18n` will log a parse error and skip the file, falling back to the default locale for all keys.

**Fix:** Use a JSON linter or your editor's JSON validation before deploying. CI pipelines should run `JSON.parse()` against all locale files.

### 2. Missing keys return the key string

If a key does not exist in any locale, `t()` returns the key itself (e.g., `"orders.shipped"`). This makes missing translations visible in production.

**Fix:** Maintain the English locale as the complete reference. Other locales can be partial -- they fall back to English. Audit periodically with a script that compares all locale files against the English baseline.

### 3. setLocale is not thread-safe for concurrent requests

If multiple concurrent requests call `i18n.setLocale()` on the same instance, they interfere with each other.

**Fix:** Create a new `I18n` instance per request, or use `i18n.translate(key, vars, locale)` which accepts the locale as a parameter without mutating instance state.

### 4. Placeholder names are case-sensitive

`{{Name}}` and `{{name}}` are different placeholders. A mismatch silently leaves the placeholder unreplaced.

**Fix:** Use consistent lowercase placeholder names in all locale files.
