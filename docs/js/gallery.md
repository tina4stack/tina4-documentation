# Gallery: Real-World Examples

Live interactive demos showing tina4js in real-world scenarios. Each demo is one self-contained HTML file, so there's no build step. Click "Open full demo" to run it in a new tab.

### 📊 Admin Dashboard

Live stats with reactive counters, computed KPIs, polling effects, and a notification feed.

`signal` `computed` `effect` `component`

<a href="/gallery/01-dashboard.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 👥 Contact Manager

Full CRUD: create, edit, delete contacts with search filtering and form validation.

`signal` `api` `html` `routing`

<a href="/gallery/02-contacts.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 💬 Live Chat

WebSocket-powered chat with signal-driven message list, auto-scroll, and reconnect status.

`websocket` `signal` `component`

<a href="/gallery/03-chat.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 🔐 Auth Flow

Login / logout with JWT token storage, route guards, protected pages, and 401 redirect.

`api` `routing` `signal`

<a href="/gallery/04-auth.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 🛒 Shopping Cart

Product listing, add-to-cart, quantity controls, computed totals, and checkout summary.

`signal` `computed` `batch`

<a href="/gallery/05-cart.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 📝 Dynamic Form Builder

Add/remove fields at runtime, reactive validation, conditional sections, and live preview.

`signal` `html` `effect`

<a href="/gallery/06-forms.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 📱 PWA Notes

Offline-capable notes app with service worker, localStorage persistence, and install prompt.

`pwa` `signal` `component`

<a href="/gallery/07-pwa-notes.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 📋 Data Table

Sortable, paginated data table with column filters, row selection, and CSV export.

`signal` `computed` `html`

<a href="/gallery/08-datatable.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 🔍 Live Search

Debounced search with API calls, loading states, highlight matching, and keyboard navigation.

`signal` `api` `effect`

<a href="/gallery/09-search.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 💾 Persistent Prefs

Theme, language, and sidebar state survive a refresh via `persist()`: opt-in localStorage with credential-shape warnings, version migration, and cross-tab sync.

`signal` `persist` `storage`

<a href="/gallery/10-persistent-prefs.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 🌍 Localization (i18n)

Switch between six languages and watch every translated string plus Intl number, currency, and date formatting update in place. Arabic flips the layout to right-to-left. The active locale is a signal.

`i18n` `signal` `intl` `rtl`

<a href="/gallery/11-i18n.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 📡 Live Streaming (SSE)

Server-Sent Events and NDJSON streaming wired to signals: an AI-style token stream and a live server-event feed, each piped into state behind a reactive status badge.

`sse` `signal` `pipe`

<a href="/gallery/12-streaming.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 🏝️ Islands (Web Components)

A static, server-rendered product page with three self-hydrating Tina4Element islands - star rating, add-to-cart, and a live viewer count - each shadow-DOM encapsulated with its own scoped styles.

`component` `shadow-dom` `signal`

<a href="/gallery/13-islands.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 🔗 GraphQL Client

Typed queries and mutations through api.graphql(): search with variables, restock with a mutation, and a live wire console showing the exact request and response.

`graphql` `api` `signal`

<a href="/gallery/14-graphql.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

### 📤 File Upload

Drag-and-drop or browse, a real FileReader preview, and multipart api.upload() with a live per-file progress bar.

`api` `upload` `signal`

<a href="/gallery/15-upload.html" target="_blank" rel="noreferrer">Open full demo ↗</a>

## Using the Examples as Starting Points

Each demo is a single self-contained HTML file. Copy any one and start editing:

```bash
# View the source of any live demo
curl https://tina4.com/gallery/01-dashboard.html
```

Or grab the whole gallery from the repo:

```bash
git clone https://github.com/tina4stack/tina4-js.git
open tina4-js/examples/gallery/index.html
```

All examples use the CDN build so they work without a build step:

```html
<script type="module">
  import { signal, html } from 'https://cdn.jsdelivr.net/npm/tina4js@latest/dist/index.es.js';
</script>
```
