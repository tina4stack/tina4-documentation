# Chapter 14: Localization

## 1. Your App Speaks One Language

Every string in your app is hard-coded English. A French user sees "Order Confirmation". A German user sees "Error: Invalid email". A Japanese user sees dates as "April 2, 2026" instead of "2026年4月2日".

Localization separates translatable strings from code. Add a locale file per language. Switch the active locale per request. Every `t("key")` call returns the right string for the current user.

---

## 2. Locale Files

Store locale files as JSON in `src/locales/`. Name them by locale code.

`src/locales/en.json`:

```json
{
  "greeting": "Hello, %{name}!",
  "order": {
    "confirmation": "Order Confirmation",
    "placed": "Your order #%{number} has been placed.",
    "total": "Total: %{currency}%{amount}"
  },
  "errors": {
    "invalid_email": "Invalid email address.",
    "required": "%{field} is required."
  },
  "nav": {
    "home": "Home",
    "account": "My Account",
    "logout": "Log Out"
  }
}
```

`src/locales/fr.json`:

```json
{
  "greeting": "Bonjour, %{name}!",
  "order": {
    "confirmation": "Confirmation de commande",
    "placed": "Votre commande #%{number} a été passée.",
    "total": "Total: %{currency}%{amount}"
  },
  "errors": {
    "invalid_email": "Adresse e-mail invalide.",
    "required": "%{field} est requis."
  },
  "nav": {
    "home": "Accueil",
    "account": "Mon compte",
    "logout": "Se déconnecter"
  }
}
```

---

## 3. Basic Translation

`Tina4::Localization` is a module-level singleton. Load the locale files once at startup, then translate with `t`:

```ruby
Tina4::Localization.load          # scans locales/, translations/, i18n/, src/locales/
Tina4::Localization.set_locale("en")

puts Tina4::Localization.t("greeting", name: "Alice")
# => Hello, Alice!

puts Tina4::Localization.t("order.confirmation")
# => Order Confirmation

puts Tina4::Localization.t("nav.logout")
# => Log Out
```

Dot notation navigates nested keys. `"order.confirmation"` maps to `locales["order"]["confirmation"]`.

---

## 4. Interpolation

Use `%{placeholder}` in locale values. Pass named keyword arguments to `t`.

```ruby
puts Tina4::Localization.t("order.placed", number: "1042")
# => Your order #1042 has been placed.

puts Tina4::Localization.t("order.total", currency: "$", amount: "79.99")
# => Total: $79.99

puts Tina4::Localization.t("errors.required", field: "Email")
# => Email is required.
```

Missing interpolation variables are left as-is in the output string.

---

## 5. Switching Locales

Call `set_locale` to change the active locale, or pass `locale:` to a single `t` call.

```ruby
Tina4::Localization.set_locale("en")

puts Tina4::Localization.t("greeting", name: "Alice")
# => Hello, Alice!

Tina4::Localization.set_locale("fr")

puts Tina4::Localization.t("greeting", name: "Alice")
# => Bonjour, Alice!

# Or override for a single call without changing the active locale:
puts Tina4::Localization.t("greeting", locale: "fr", name: "Alice")
# => Bonjour, Alice!
```

---

## 6. Fallback Locale

When a key is missing from the active locale, `t` automatically falls back to English (`"en"`) before returning the key itself.

```ruby
Tina4::Localization.set_locale("de")

# "de" locale has no "nav.logout" key
puts Tina4::Localization.t("nav.logout")
# => Log Out  (falls back to English)

# You can also supply an explicit default for a single call:
puts Tina4::Localization.t("nav.missing", default: "Menu")
# => Menu
```

Fallback prevents missing key errors in partially translated locales.

---

## 7. Per-Request Locale in Routes

Read the user's preferred locale from a header, cookie, or query param and pass it to `t` with `locale:`. Passing `locale:` per call avoids mutating the shared active locale across concurrent requests.

```ruby
# @noauth
Tina4::Router.get("/api/greeting") do |request, response|
  locale = request.headers["Accept-Language"]&.split(",")&.first&.strip || "en"
  locale = locale[0..1]  # normalize "fr-FR" to "fr"

  response.json({
    message: Tina4::Localization.t("greeting", locale: locale, name: "World"),
    locale: locale
  })
end
```

```bash
curl -H "Accept-Language: fr" http://localhost:7147/api/greeting
```

```json
{ "message": "Bonjour, World!", "locale": "fr" }
```

```bash
curl -H "Accept-Language: de" http://localhost:7147/api/greeting
```

```json
{ "message": "Hello, World!", "locale": "en" }
```

German falls back to English because `de.json` does not exist.

---

## 8. Available Locales

List all locale files present in the locales directory.

```ruby
Tina4::Localization.load
puts Tina4::Localization.available_locales.inspect
# => ["en", "fr"]
```

Use this to build a language switcher UI.

```ruby
# @noauth
Tina4::Router.get("/api/locales") do |request, response|
  response.json({ locales: Tina4::Localization.available_locales })
end
```

---

## 9. Locale in Templates

Tina4 auto-wires `t()` as a template global, so templates call it directly. Set the active locale for the request before rendering.

```ruby
Tina4::Router.get("/dashboard") do |request, response|
  locale = request.cookies["locale"] || "en"
  Tina4::Localization.set_locale(locale)

  response.render("dashboard.html", { user: { name: "Alice" } })
end
```

In `src/templates/dashboard.html` (Frond template):

```html
<nav>
  <a href="/">{{ t("nav.home") }}</a>
  <a href="/account">{{ t("nav.account") }}</a>
  <a href="/logout">{{ t("nav.logout") }}</a>
</nav>

<h1>{{ t("greeting", name=user.name) }}</h1>
```

---

## 10. Date and Number Formatting

Add locale-specific formatting helpers to your locale files or handle them with Ruby's standard library.

```ruby
# Format a date string for the current locale
date = Time.now

formatted = case Tina4::Localization.current_locale
            when "en" then date.strftime("%B %-d, %Y")
            when "fr" then date.strftime("%-d %B %Y")
            when "de" then date.strftime("%-d. %B %Y")
            else date.strftime("%Y-%m-%d")
            end

puts formatted
# en: April 2, 2026
# fr: 2 avril 2026
# de: 2. April 2026
```

---

## 11. Gotchas

### 1. Missing locale file returns fallback silently

If the requested locale file does not exist and a fallback is set, the fallback runs without warning. Log the missing locale in development.

### 2. Nested key typo

`Tina4::Localization.t("order.confimation")` (typo) returns the key string `"order.confimation"` unchanged. If you see keys appearing raw in the UI, check for spelling mistakes in your `t()` calls.

### 3. Reload locale files in development

Locale file changes do not reload automatically in a running server. Restart the server or implement a dev-mode watch pattern.

### 4. Interpolation keys are case-sensitive

`{Name}` in the locale file is not the same as `name:` in the `t()` call. Keep all interpolation placeholders lowercase.
