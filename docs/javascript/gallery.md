# Gallery — Real-World Examples

Live interactive demos showing tina4js in real-world scenarios. Each example is self-contained and uses the CDN build — no build step required.

<style>
.gallery-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 1.5rem;
  margin: 2rem 0;
}
.gallery-card {
  border: 1px solid var(--vp-c-divider);
  border-radius: 10px;
  overflow: hidden;
  background: var(--vp-c-bg-soft);
  transition: box-shadow 0.2s;
}
.gallery-card:hover { box-shadow: 0 4px 20px rgba(0,0,0,0.15); }
.gallery-card iframe {
  width: 100%;
  height: 320px;
  border: none;
  display: block;
  background: #0f172a;
}
.gallery-card-body { padding: 1rem; }
.gallery-card-body h3 { margin: 0 0 0.4rem; font-size: 1rem; }
.gallery-card-body p { margin: 0 0 0.75rem; font-size: 0.85rem; color: var(--vp-c-text-2); }
.tags { display: flex; flex-wrap: wrap; gap: 0.3rem; }
.tag {
  font-size: 0.7rem; padding: 0.15rem 0.5rem;
  border-radius: 4px; background: var(--vp-c-brand-soft);
  color: var(--vp-c-brand-1); font-weight: 600; text-transform: uppercase;
}
.open-link {
  display: inline-block; margin-top: 0.75rem;
  font-size: 0.82rem; color: var(--vp-c-brand-1); text-decoration: none;
}
.open-link:hover { text-decoration: underline; }
</style>

<div class="gallery-grid">

  <div class="gallery-card">
    <iframe src="/gallery/01-dashboard.html" loading="lazy"></iframe>
    <div class="gallery-card-body">
      <h3>📊 Admin Dashboard</h3>
      <p>Live stats with reactive counters, computed KPIs, polling effects, and a notification feed.</p>
      <div class="tags"><span class="tag">signal</span><span class="tag">computed</span><span class="tag">effect</span><span class="tag">component</span></div>
      <a class="open-link" href="/gallery/01-dashboard.html" target="_blank">Open full demo ↗</a>
    </div>
  </div>

  <div class="gallery-card">
    <iframe src="/gallery/02-contacts.html" loading="lazy"></iframe>
    <div class="gallery-card-body">
      <h3>👥 Contact Manager</h3>
      <p>Full CRUD — create, edit, delete contacts with search filtering and form validation.</p>
      <div class="tags"><span class="tag">signal</span><span class="tag">api</span><span class="tag">html</span><span class="tag">routing</span></div>
      <a class="open-link" href="/gallery/02-contacts.html" target="_blank">Open full demo ↗</a>
    </div>
  </div>

  <div class="gallery-card">
    <iframe src="/gallery/03-chat.html" loading="lazy"></iframe>
    <div class="gallery-card-body">
      <h3>💬 Live Chat</h3>
      <p>WebSocket-powered chat with signal-driven message list, auto-scroll, and reconnect status.</p>
      <div class="tags"><span class="tag">websocket</span><span class="tag">signal</span><span class="tag">component</span></div>
      <a class="open-link" href="/gallery/03-chat.html" target="_blank">Open full demo ↗</a>
    </div>
  </div>

  <div class="gallery-card">
    <iframe src="/gallery/04-auth.html" loading="lazy"></iframe>
    <div class="gallery-card-body">
      <h3>🔐 Auth Flow</h3>
      <p>Login / logout with JWT token storage, route guards, protected pages, and 401 redirect.</p>
      <div class="tags"><span class="tag">api</span><span class="tag">routing</span><span class="tag">signal</span></div>
      <a class="open-link" href="/gallery/04-auth.html" target="_blank">Open full demo ↗</a>
    </div>
  </div>

  <div class="gallery-card">
    <iframe src="/gallery/05-cart.html" loading="lazy"></iframe>
    <div class="gallery-card-body">
      <h3>🛒 Shopping Cart</h3>
      <p>Product listing, add-to-cart, quantity controls, computed totals, and checkout summary.</p>
      <div class="tags"><span class="tag">signal</span><span class="tag">computed</span><span class="tag">batch</span></div>
      <a class="open-link" href="/gallery/05-cart.html" target="_blank">Open full demo ↗</a>
    </div>
  </div>

  <div class="gallery-card">
    <iframe src="/gallery/06-forms.html" loading="lazy"></iframe>
    <div class="gallery-card-body">
      <h3>📝 Dynamic Form Builder</h3>
      <p>Add/remove fields at runtime, reactive validation, conditional sections, and live preview.</p>
      <div class="tags"><span class="tag">signal</span><span class="tag">html</span><span class="tag">effect</span></div>
      <a class="open-link" href="/gallery/06-forms.html" target="_blank">Open full demo ↗</a>
    </div>
  </div>

  <div class="gallery-card">
    <iframe src="/gallery/07-pwa-notes.html" loading="lazy"></iframe>
    <div class="gallery-card-body">
      <h3>📱 PWA Notes</h3>
      <p>Offline-capable notes app with service worker, localStorage persistence, and install prompt.</p>
      <div class="tags"><span class="tag">pwa</span><span class="tag">signal</span><span class="tag">component</span></div>
      <a class="open-link" href="/gallery/07-pwa-notes.html" target="_blank">Open full demo ↗</a>
    </div>
  </div>

  <div class="gallery-card">
    <iframe src="/gallery/08-datatable.html" loading="lazy"></iframe>
    <div class="gallery-card-body">
      <h3>📋 Data Table</h3>
      <p>Sortable, paginated data table with column filters, row selection, and CSV export.</p>
      <div class="tags"><span class="tag">signal</span><span class="tag">computed</span><span class="tag">html</span></div>
      <a class="open-link" href="/gallery/08-datatable.html" target="_blank">Open full demo ↗</a>
    </div>
  </div>

  <div class="gallery-card">
    <iframe src="/gallery/09-search.html" loading="lazy"></iframe>
    <div class="gallery-card-body">
      <h3>🔍 Live Search</h3>
      <p>Debounced search with API calls, loading states, highlight matching, and keyboard navigation.</p>
      <div class="tags"><span class="tag">signal</span><span class="tag">api</span><span class="tag">effect</span></div>
      <a class="open-link" href="/gallery/09-search.html" target="_blank">Open full demo ↗</a>
    </div>
  </div>

</div>

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
