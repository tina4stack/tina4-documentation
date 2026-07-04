# Gallery: Real-World Examples

Live interactive demos showing tina4js in real-world scenarios. Each example is self-contained and uses the CDN build, so no build step is required.

### 📊 Admin Dashboard

Live stats with reactive counters, computed KPIs, polling effects, and a notification feed.

signalcomputedeffectcomponent[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/01-dashboard.html)

### 👥 Contact Manager

Full CRUD: create, edit, delete contacts with search filtering and form validation.

signalapihtmlrouting[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/02-contacts.html)

### 💬 Live Chat

WebSocket-powered chat with signal-driven message list, auto-scroll, and reconnect status.

websocketsignalcomponent[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/03-chat.html)

### 🔐 Auth Flow

Login / logout with JWT token storage, route guards, protected pages, and 401 redirect.

apiroutingsignal[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/04-auth.html)

### 🛒 Shopping Cart

Product listing, add-to-cart, quantity controls, computed totals, and checkout summary.

signalcomputedbatch[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/05-cart.html)

### 📝 Dynamic Form Builder

Add/remove fields at runtime, reactive validation, conditional sections, and live preview.

signalhtmleffect[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/06-forms.html)

### 📱 PWA Notes

Offline-capable notes app with service worker, localStorage persistence, and install prompt.

pwasignalcomponent[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/07-pwa-notes.html)

### 📋 Data Table

Sortable, paginated data table with column filters, row selection, and CSV export.

signalcomputedhtml[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/08-datatable.html)

### 🔍 Live Search

Debounced search with API calls, loading states, highlight matching, and keyboard navigation.

signalapieffect[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/09-search.html)

### 💾 Persistent Prefs

Theme, language, and sidebar state survive a refresh via `persist()`: opt-in localStorage with credential-shape warnings, version migration, and cross-tab sync.

signalpersiststorage[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/10-persistent-prefs.html)

### 🌍 Localization (i18n)

Switch between six languages and watch every translated string plus Intl number, currency, and date formatting update in place. Arabic flips the layout to right-to-left. The active locale is a signal.

i18nsignalintlrtl[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/11-i18n.html)

### 📡 Live Streaming (SSE)

Server-Sent Events and NDJSON streaming wired to signals: an AI-style token stream and a live server-event feed, each piped into state behind a reactive status badge.

ssesignalpipe[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/12-streaming.html)

### 🏝️ Islands (Web Components)

A static, server-rendered product page with three self-hydrating Tina4Element islands - star rating, add-to-cart, and a live viewer count - each shadow-DOM encapsulated with its own scoped styles.

componentshadow-domsignal[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/13-islands.html)

### 🔗 GraphQL Client

Typed queries and mutations through api.graphql(): search with variables, restock with a mutation, and a live wire console showing the exact request and response.

graphqlapisignal[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/14-graphql.html)

### 📤 File Upload

Drag-and-drop or browse, a real FileReader preview, and multipart api.upload() with a live per-file progress bar.

apiuploadsignal[Open full demo ↗](https://github.com/tina4stack/tina4-documentation/blob/main/gallery/15-upload.html)

## Using the Examples as Starting Points

Each demo is a single self-contained HTML file. Copy any one and start editing:

```bash
# View source of any demo
curl https://tina4stack.github.io/tina4-js/examples/gallery/01-dashboard.html
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
