# tina4-js frontend feature reference

The frontend companion to `feature-reference-table.md` (which covers the four backends). tina4-js is
the reactive browser framework used by all four Tina4 backends. It is zero-dependency, tree-shakeable,
and ships vendored inside tina4-css so every backend gets it with no install. Same "is it already in
the box?" rule: before adding a frontend library, check here.

Grounded in the tina4-js source at **v1.5.1** (public exports per module, verified 2026-07-23), not
the skill (the installed skill is v1.2.7 and predates the `rtc` module).

## Modules (10)

| # | Feature | Module | Public API | What it does / instead of |
|---|---------|--------|-----------|---------------------------|
| 1 | Signals (reactive state) | core | `signal`, `computed`, `effect`, `batch`, `isSignal` | Fine-grained reactivity, no virtual DOM. Instead of Redux/MobX/Zustand/Vuex |
| 2 | html DOM renderer | core | `html` | Tagged-template real-DOM rendering with reactive bindings. Instead of JSX/lit-html/Handlebars |
| 3 | Web Component base | core | `Tina4Element` | Reactive custom elements via `static props`. Instead of Lit/Stencil |
| 4 | Client-side router | router | `route`, `navigate`, `router` | Hash routing, `{param}` patterns, guards, `change` event. Instead of react-router/vue-router |
| 5 | API client | api | `api` (+ request/response interceptors) | fetch wrapper: Bearer + formToken auth, JSON, consistent result shape, talks to Tina4 backends. Instead of axios |
| 6 | WebSocket client | ws | `ws`, `ManagedSocket` | Signal-driven status/connected, auto-reconnect, pipe messages into signals. Instead of socket.io-client |
| 7 | SSE / NDJSON client | sse | `sse`, `ManagedStream` | Signal-driven Server-Sent-Events / NDJSON streaming, same reconnect shape as ws. Instead of an SSE lib |
| 8 | WebRTC realtime | rtc | `rtc`, `rtcConfig`, `CallSession`, `ChatSession` | Perfect-negotiation calls + data-channel chat + file transfer, pairs with the backend realtime collab. Instead of simple-peer/PeerJS |
| 9 | Persisted signals | storage | `persist`, `clearPersistedKeys` | Persist a signal to localStorage: versioned, cross-tab, migratable (never store secrets). Instead of a state-persistence lib |
| 10 | Reactive i18n | i18n | `createI18n`, `i18n`, `t`, `setLocale`, `getLocale` | Locale is a signal so `t()` re-renders on `setLocale`; Intl number/currency/date + RTL `dir()`. Mirrors the backend I18n. Instead of i18next |
| 11 | PWA runtime | pwa | `pwa` | Runtime service-worker + web-manifest generation: installable/offline, no build step. Instead of Workbox |
| 12 | Debug overlay | debug | `enableDebug`, `Tina4Debug`, `signalTracker`, `componentTracker`, `routeTracker`, `apiTracker` | Dev overlay (Ctrl+Shift+D) tracking signals, components, routes, API calls. Dev-only, never shipped |

Rows 1-3 are the `core` module (the sub-3KB headline bundle); the other nine modules are each a
separate tree-shakeable entry point (`tina4js/router`, `tina4js/api`, ...). Counting the core as its
three primitives gives **12 frontend features across 10 modules**.

## Distribution facts (for the docs)

- Zero runtime dependencies. `core` gzips to ~1.5 KB; each other module is 0.1 to 2.3 KB.
- Ships as an IIFE bundle (`dist/tina4js.min.js`) that exposes everything on `window.Tina4`, and is
  vendored inside tina4-css so all four backends serve it with no npm install.
- Tree-shakeable: import only the modules you use.

## Next step

Feeds a `docs/js/` feature-list page (parallel to the four backend `NN-feature-list.md` pages), to be
written when the backend feature-list regeneration runs. Verify each row against the running tina4-js
docs (`docs/js/*`) during that write.
