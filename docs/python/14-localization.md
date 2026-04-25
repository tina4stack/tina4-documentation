# Chapter 14: Localization

## 1. One App, Many Languages

Your application is live. A customer in Berlin arrives and sees English. A customer in Tokyo sees English. A customer in São Paulo sees English.

Tina4 localization lets you write translations once and switch the active locale at runtime. Store JSON files in `src/locales/`, call `t()` at the point of use, and set the active language from a query parameter, a cookie, or an environment variable. No third-party libraries required.

---

## 2. Locale Files

Create one JSON file per locale in `src/locales/`. The filename is the locale code.

```
src/
  locales/
    en.json
    de.json
    ja.json
    pt.json
```

`src/locales/en.json`:

```json
{
  "welcome": "Welcome",
  "greeting": "Hello, {name}!",
  "order": {
    "placed": "Your order has been placed.",
    "total": "Order total: {currency}{amount}",
    "item_count": "{count} item in your order",
    "item_count_plural": "{count} items in your order"
  },
  "errors": {
    "not_found": "The requested resource was not found.",
    "unauthorized": "You are not authorized to access this resource."
  }
}
```

`src/locales/de.json`:

```json
{
  "welcome": "Willkommen",
  "greeting": "Hallo, {name}!",
  "order": {
    "placed": "Ihre Bestellung wurde aufgegeben.",
    "total": "Bestellsumme: {currency}{amount}",
    "item_count": "{count} Artikel in Ihrer Bestellung",
    "item_count_plural": "{count} Artikel in Ihrer Bestellung"
  },
  "errors": {
    "not_found": "Die angeforderte Ressource wurde nicht gefunden.",
    "unauthorized": "Sie sind nicht berechtigt, auf diese Ressource zuzugreifen."
  }
}
```

---

## 3. The t() Function

```python
from tina4_python.i18n import t

# Simple key
message = t("welcome")
# "Welcome"

# Nested key with dot notation
error = t("errors.not_found")
# "The requested resource was not found."

# Interpolation with {placeholder}
greeting = t("greeting", name="Alice")
# "Hello, Alice!"

order_total = t("order.total", currency="$", amount="99.99")
# "Order total: $99.99"
```

Keys use dot notation for nested structures. Placeholders in curly braces are replaced with keyword arguments.

---

## 4. The I18n Class

For more control — setting the locale per request, loading custom locale paths — use the `I18n` class directly:

```python
from tina4_python.i18n import I18n

i18n = I18n(locale="de", path="src/locales")

print(i18n.t("welcome"))
# "Willkommen"

print(i18n.t("greeting", name="Max"))
# "Hallo, Max!"

# Switch locale at runtime
i18n.set_locale("en")
print(i18n.t("welcome"))
# "Welcome"
```

The `I18n` class loads locale files lazily. Setting the locale to `"de"` loads `src/locales/de.json` the first time a translation is requested. Subsequent requests for the same locale use the in-memory cache.

---

## 5. Setting the Locale at Runtime

### From a Query Parameter

The simplest approach: read `?lang=` from the request and set the locale.

```python
from tina4_python.core.router import get
from tina4_python.i18n import I18n

@get("/api/welcome")
async def welcome(request, response):
    lang = request.params.get("lang", "en")
    i18n = I18n(locale=lang, path="src/locales")

    return response({
        "message": i18n.t("greeting", name="World"),
        "locale": lang
    })
```

```bash
curl "http://localhost:7146/api/welcome?lang=en"
# {"message": "Hello, World!", "locale": "en"}

curl "http://localhost:7146/api/welcome?lang=de"
# {"message": "Hallo, World!", "locale": "de"}
```

### From the Accept-Language Header

A more standard approach uses the browser's language preference:

```python
from tina4_python.core.router import get
from tina4_python.i18n import I18n

def detect_locale(request, default="en"):
    accept = request.headers.get("Accept-Language", default)
    # "de-DE,de;q=0.9,en;q=0.8" -> "de"
    primary = accept.split(",")[0].split("-")[0].strip()
    supported = ["en", "de", "ja", "pt"]
    return primary if primary in supported else default

@get("/api/dashboard")
async def dashboard(request, response):
    locale = detect_locale(request)
    i18n = I18n(locale=locale, path="src/locales")

    return response({
        "welcome": i18n.t("welcome"),
        "locale": locale
    })
```

### From a Session or Cookie

```python
@get("/api/home")
async def home(request, response):
    locale = request.session.get("locale", "en")
    i18n = I18n(locale=locale, path="src/locales")

    return response({"message": i18n.t("welcome")})

@post("/api/locale")
async def set_locale(request, response):
    locale = request.body.get("locale", "en")
    request.session["locale"] = locale
    return response({"locale": locale})
```

---

## 6. The TINA4_LOCALE Environment Variable

Set the application's default locale in `.env`:

```bash
TINA4_LOCALE=de
```

When `TINA4_LOCALE` is set, calls to `t()` without an explicit locale use German as the default. This is the locale loaded at application startup.

```python
from tina4_python.i18n import t

# Uses TINA4_LOCALE from .env (e.g., "de")
message = t("welcome")
# "Willkommen"
```

---

## 7. Interpolation with {placeholder}

Placeholders are written as `{name}` in the JSON file and filled via keyword arguments to `t()`:

```python
from tina4_python.i18n import I18n

i18n = I18n(locale="en", path="src/locales")

# Single placeholder
greeting = i18n.t("greeting", name="Alice")
# "Hello, Alice!"

# Multiple placeholders
total = i18n.t("order.total", currency="€", amount="149.99")
# "Order total: €149.99"
```

Missing placeholders are left as-is:

```python
i18n.t("order.total", currency="$")
# "Order total: ${amount}"  -- {amount} not supplied
```

Extra keyword arguments are silently ignored.

---

## 8. Fallback Behaviour

When a key is missing from the active locale, Tina4 falls back through a chain:

1. Active locale (`de`)
2. Base language (`de` if locale was `de_AT`)
3. Default locale (`en` or whatever `TINA4_LOCALE_FALLBACK` is set to)
4. The raw key string itself

```bash
TINA4_LOCALE=de
TINA4_LOCALE_FALLBACK=en
```

```json
// en.json
{
  "beta_feature": "This feature is in beta."
}

// de.json
{
  "welcome": "Willkommen"
  // beta_feature not yet translated
}
```

```python
i18n = I18n(locale="de", path="src/locales")
i18n.t("beta_feature")
# Falls back to en.json: "This feature is in beta."

i18n.t("completely.missing.key")
# Returns "completely.missing.key" -- the key itself
```

Your app never crashes on a missing translation. It returns the raw key string, which your translation team can search for to find gaps.

---

## 9. Translating Templates

In Frond templates, call `t()` directly:

```html
<h1>{{ t("welcome") }}</h1>
<p>{{ t("greeting", name=user.name) }}</p>

<div class="order-summary">
  <p>{{ t("order.placed") }}</p>
  <p>{{ t("order.total", currency="$", amount=order.total) }}</p>
</div>
```

Pass the locale through the template context:

```python
@get("/dashboard")
async def dashboard(request, response):
    locale = request.params.get("lang", "en")
    i18n = I18n(locale=locale, path="src/locales")

    return response.render("dashboard.html", {
        "t": i18n.t,
        "user": {"name": "Alice"},
        "locale": locale
    })
```

---

## 10. Exercise: Multi-Language API Responses

Build an API that returns translated error messages and UI strings based on the request locale.

### Requirements

1. Create locale files for `en`, `fr`, and `es` with these keys:
   - `errors.not_found`
   - `errors.validation`
   - `user.created`
   - `user.greeting`

2. Create `GET /api/users/{user_id}` that:
   - Detects locale from `?lang=` param (default: `en`)
   - Returns a user or a translated 404 message

3. Create `POST /api/users` that:
   - Validates required fields and returns translated validation errors
   - Returns a translated success message on creation

### Test with:

```bash
# English (default)
curl "http://localhost:7146/api/users/999"
# {"error": "The requested resource was not found."}

# French
curl "http://localhost:7146/api/users/999?lang=fr"
# {"error": "La ressource demandée est introuvable."}

# Spanish
curl "http://localhost:7146/api/users/999?lang=es"
# {"error": "El recurso solicitado no fue encontrado."}

# Create user in French
curl -X POST "http://localhost:7146/api/users?lang=fr" \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "name": "Alice"}'
```

---

## 11. Solution

`src/locales/en.json`:

```json
{
  "errors": {
    "not_found": "The requested resource was not found.",
    "validation": "Validation failed: {fields}"
  },
  "user": {
    "created": "User account created successfully.",
    "greeting": "Hello, {name}!"
  }
}
```

`src/locales/fr.json`:

```json
{
  "errors": {
    "not_found": "La ressource demandée est introuvable.",
    "validation": "Échec de validation : {fields}"
  },
  "user": {
    "created": "Compte utilisateur créé avec succès.",
    "greeting": "Bonjour, {name} !"
  }
}
```

`src/locales/es.json`:

```json
{
  "errors": {
    "not_found": "El recurso solicitado no fue encontrado.",
    "validation": "Error de validación: {fields}"
  },
  "user": {
    "created": "Cuenta de usuario creada con éxito.",
    "greeting": "¡Hola, {name}!"
  }
}
```

`src/routes/users_i18n.py`:

```python
from tina4_python.core.router import get, post
from tina4_python.i18n import I18n

USERS = {
    1: {"id": 1, "name": "Alice", "email": "alice@example.com"},
    2: {"id": 2, "name": "Bob", "email": "bob@example.com"}
}

SUPPORTED_LOCALES = ["en", "fr", "es"]

def get_i18n(request):
    lang = request.params.get("lang", "en")
    if lang not in SUPPORTED_LOCALES:
        lang = "en"
    return I18n(locale=lang, path="src/locales")


@get("/api/users/{user_id}")
async def get_user(request, response):
    i18n = get_i18n(request)
    user_id = int(request.params["user_id"])

    user = USERS.get(user_id)
    if user is None:
        return response({"error": i18n.t("errors.not_found")}, 404)

    return response({
        "user": user,
        "greeting": i18n.t("user.greeting", name=user["name"])
    })


@post("/api/users")
async def create_user(request, response):
    i18n = get_i18n(request)
    body = request.body

    missing = [f for f in ["email", "name"] if not body.get(f)]
    if missing:
        return response({
            "error": i18n.t("errors.validation", fields=", ".join(missing))
        }, 400)

    new_user = {
        "id": max(USERS.keys()) + 1,
        "name": body["name"],
        "email": body["email"]
    }
    USERS[new_user["id"]] = new_user

    return response({
        "message": i18n.t("user.created"),
        "user": new_user
    }, 201)
```

---

## 12. Gotchas

### 1. Missing locale file raises an error

**Problem:** `I18n(locale="zh", ...)` crashes because `src/locales/zh.json` does not exist.

**Fix:** Set `TINA4_LOCALE_FALLBACK=en`. Always validate user-supplied locale values against a supported list before creating the `I18n` instance.

### 2. Placeholder name mismatch

**Problem:** JSON has `{firstName}` but code calls `t("greeting", first_name="Alice")`. The placeholder is not replaced.

**Fix:** Placeholder names in JSON and keyword argument names in Python must match exactly. Use consistent naming conventions — either camelCase or snake_case throughout your locale files.

### 3. TINA4_LOCALE not set, t() uses "en"

**Problem:** `t()` returns English strings even though your app targets a different language.

**Fix:** Set `TINA4_LOCALE=de` (or your target locale) in `.env`. Without it, `t()` defaults to `"en"`.

### 4. Locale files not reloading during development

**Problem:** You updated a locale file but the app still serves the old translation.

**Fix:** The `I18n` class caches locale files in memory. Restart the dev server or set a shorter cache duration during development. In production this is the correct behaviour.
