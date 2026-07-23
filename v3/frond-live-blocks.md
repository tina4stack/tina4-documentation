# Frond live blocks (`{% live %}`) - design + release plan

**Status:** ALL 4 FRAMEWORKS IMPLEMENTED + TESTED + BANKED (feature/release3.13.52). Release tail remains: docs (FROND.md + per-framework + book), skills correction, release notes, version bumps, tag/publish.
**Owner:** Andre (approver); implementation: maintainer agent
**Master:** tina4-python, then mirror PHP / Ruby / Node (full parity: logic AND tests)
**Target version:** 3.14.0 (new user-facing capability) or next 3.13.x - owner picks at tag time

## Goal

Server-rendered live regions in a Frond template: a block re-renders on the server and swaps
its HTML into the page over poll, SSE, or WebSocket, with no client framework and no hand-written
fetch code.

## Context

`{% live %}` was documented in the skills but never built (no parser branch, no `FROND.md` entry,
no `frond.js` support). Rather than delete the aspirational doc, make it true. The niche is real:
server-side-rendered apps that want a few live regions (a cart badge, a notifications list, a chat
pane) without adopting tina4-js. This is the Turbo-Frames / LiveView / HTMX lane, sitting next to
tina4-js (the client-framework lane), not replacing it.

Roughly 80 percent of the plumbing already ships:
- `Frond.render` / `Frond.render_string(source, data)` - render an isolated fragment (engine.py).
- WebSocket rooms - `join_room`, `rooms`, `broadcast_to_room(room, msg, exclude)` (websocket/__init__.py).
- SSE - `response.stream(source, "text/event-stream")` (core/response.py).
- Client transports in frond.js - `frond.load(url, targetId)`, `frond.inject(html, targetId)`,
  `frond.ws(url, opts)`, `frond.sse(url, opts)`.

Net-new is modest: the tag, a data-source contract, one framework route, and a small `frond.live`
client bootstrap over the transports that already exist.

## Non-goals (v1)

- No nested live blocks. A `{% live %}` inside a `{% live %}` is a parse error in v1.
- No automatic diffing or partial-patch protocol. The server sends the whole fragment HTML.
- No client state. Live blocks are one-way (server to client). For two-way, use tina4-js.

## Tag grammar

```
{% live "<name>" <transport> [src "<url>"] %} ... body ... {% endlive %}
```

- `<name>` - stable id, unique per page. Becomes the DOM id `live-<name>` and, for ws, the room name.
- `<transport>` - one of:
  - `poll <seconds>` - client re-fetches every N seconds.
  - `sse` - client opens an EventSource; server pushes fragments.
  - `ws "<path>"` - client joins the WebSocket at `<path>`; server pushes fragments to a room.
- `src "<url>"` - optional. Where refreshes come from (see Data source). If omitted, the block uses
  a registered `@live_source(<name>)` provider and the auto endpoint `/__frond/live/<name>`.

Examples:
```twig
{% live "notifications" poll 5 %}
  <ul>{% for n in notifications %}<li>{{ n.text }}</li>{% endfor %}</ul>
{% endlive %}

{% live "chat" ws "/ws/chat" %}
  {% for m in messages %}<p><b>{{ m.user }}</b>: {{ m.text }}</p>{% endfor %}
{% endlive %}
```

## Desugaring (what the tag compiles to)

At render time `_handle_live` does three things:

1. Renders the body once with the current page context (server-rendered first paint - no flash, SEO-safe).
2. Wraps it in a marker element:
   ```html
   <div data-frond-live="notifications" id="live-notifications"
        data-mode="poll" data-interval="5" data-src="/__frond/live/notifications">
     <!-- first-paint body -->
   </div>
   ```
3. Registers the body source under the name in a per-render fragment registry so the auto endpoint
   can re-render it later: `Frond.register_live("notifications", body_source)`.

Implementation mirrors `_handle_cache` (a paired `{% cache %}...{% endcache %}` handler that already
captures a body between open/close tokens) plus the `{% block %}` body-capture in `_extract_blocks`.
Dispatch is one new `elif tag == "live":` branch in `_render_tokens` (~line 1719) calling
`_handle_live(tokens, start, context) -> (html, next_index)`.

## Data source (the crux)

A live block cannot re-execute an arbitrary slice of the original page scope - the loop vars and
locals are gone once the response is sent. So the refresh data must be explicit. Two forms, both shipped:

**A. Provider (primary DX)** - a named provider supplies the context; the framework re-renders the
registered body and returns HTML. No hand-written route, no duplicated template.
```python
@live_source("notifications")
async def notifications(request):
    return {"notifications": Notification.where("user_id = ?", [request.session["uid"]])}
```
The auto endpoint `GET /__frond/live/notifications` runs the provider with the live `request`,
renders the registered body via `render_string`, returns the fragment.

**B. Route (escape hatch)** - point at a route you already have; the block body is only the initial
paint, refreshes come from the route:
```twig
{% live "cart" poll 5 src "/fragments/cart" %}{% include "fragments/cart.twig" %}{% endlive %}
```
Needs zero new server machinery - `frond.load("/fragments/cart", "live-cart")` on a timer.

## Server pieces

- **Auto endpoint** `GET /__frond/live/{name}` (registered once, debug-independent): resolve provider
  by name -> run with `request` -> `render_string(body, ctx)` -> return HTML fragment. Runs through
  the normal middleware chain, so **auth and session scoping re-apply on every refresh** (a live
  "my cart" cannot leak another user's cart). 404 if no provider and no `src`.
- **`@live_source(name)` registry** - decorator (Python/Node), registration call (PHP/Ruby).
- **`push_live(name, request=None)` helper** - re-renders the fragment and pushes to the ws room /
  sse channel named `name`. Built on the existing `broadcast_to_room`. Apps call it after a state
  change (new chat message, order update).

## Transports (client - `frond.live` bootstrap)

New: on `DOMContentLoaded`, scan `[data-frond-live]` and wire each element by `data-mode`. All three
swap helpers already exist; this is ~40 lines of new glue in frond.js.

- **poll** - `setInterval(() => frond.load(el.dataset.src, el.id), interval*1000)`. Pause on
  `document.hidden` (visibilitychange) and clear when the element leaves the DOM (MutationObserver).
- **sse** - `frond.sse(el.dataset.src).on("message", html => frond.inject(html, el.id))`.
- **ws** - `frond.ws(el.dataset.ws).on("message", msg => frond.inject(msg.html, el.id))`.

Emit the same `data-frond-live` contract in all four backends so the one shared `frond.js`/`frond.min.js`
drives them identically.

## Security

- Refresh endpoint goes through normal middleware -> auth/session re-checked every refresh (no IDOR).
- Fragment HTML is auto-escaped by Frond, same as any template (no new XSS surface).
- ws/sse push only to the room/channel for that block; a client only receives its subscribed blocks.
- `src` URLs are same-origin only; reject absolute/cross-origin `src` at parse time.

## Performance

- poll is the heavy mode (N clients x interval x provider cost). Docs lead with ws/sse; poll is the
  fallback. Per-fragment response cache keyed by `(name, session-scope)` to collapse duplicate renders.
- Pause polling on hidden tabs; stop timers/observers when the block unmounts.

## Cross-framework parity matrix

| Piece | Python (master) | PHP | Ruby | Node |
|---|---|---|---|---|
| `{% live %}` parse + `_handle_live` + registry | new | mirror | mirror | mirror |
| `data-frond-live` desugar contract | define | match | match | match |
| `@live_source` registry + `/__frond/live/{name}` route | new | mirror | mirror | mirror |
| `push_live()` over `broadcast_to_room` | new | mirror | mirror | mirror |
| `frond.js` `frond.live` bootstrap | **shared file** - write once, ships in all 4 | " | " | " |

frond.js is a single shared asset (shipped inside tina4-css and each framework's public/js), so the
client half is written once and propagated, not reimplemented per language.

## Test plan (real, no mocks)

- **Engine unit** - `{% live %}` renders first-paint body correctly; registers the fragment; nested
  live raises; `src` cross-origin rejected; unknown transport rejected.
- **Endpoint integration** - `GET /__frond/live/{name}` re-renders with provider data; returns 404
  for unknown name; **re-applies auth** (request without session gets the unauth fragment, not
  another user's data) - this is a named regression/contract test.
- **ws push** - real WebSocket client joins the room, `push_live` broadcasts, client receives the
  rendered fragment (real server, no mock, per the no-mock rule).
- **sse push** - real EventSource receives a pushed fragment.
- **Client** - a headless page load asserts `[data-frond-live]` wiring and that a poll swaps innerHTML.
- Same suite mirrored across all four frameworks; engine-agnostic contract tests lock the wire shape.

## Release checklist

- [x] Python master ENGINE: `{% live %}` parse (poll/sse/ws + `src`), first-paint render, marker
      element (`data-frond-live`/`id`/`data-mode`/`data-interval`/`data-src`/`data-ws`), body-source
      registry, `Frond.render_live(name, data)`, `@live_source(name)` decorator, dispatch branch,
      `clear_registry` extended. `tests/test_frond_live.py` 11/11 green; 327 existing Frond tests green.
- [x] Python master: `/__frond/live/{name}` auto endpoint (`live_endpoint` in frond/__init__.py;
      resolves `@live_source` provider, awaits async providers, `render_live` -> fragment; 404 on
      unknown/unrendered; registered always-on in server.py next to /health). `tests/test_frond_live_endpoint.py`
      7/7 green incl. the auth-reapply IDOR contract (anon -> guest, never another user's fragment).
- [x] Python master: `push_live(name, data)` in frond/__init__.py - renders via render_live + broadcasts a
      `{type,name,html}` envelope over WS to the block's declared `data-ws` path (registered in
      `_class_live_ws_paths` at render), else to room `name`; resilient (logs on failure). Real ws test in
      `tests/test_frond_live_push.py` 4/4: renders correct fragment, broadcasts over the declared path, and
      does NOT reach a connection on a different path. Uses real WebSocketManager/Connection/frame codec.
- [x] `frond.live` client SHIPPED - added to `tina4-css/src/js/frond.ts`: `liveInit` scans `[data-frond-live]`,
      wires poll (setInterval + request + swap, pauses on `document.hidden`) and ws (`frond.ws` -> envelope
      route by name); minimal-move keyed morph (`_liveReconcile`/`_liveMorphNode`) that preserves form-control
      focus+value and only moves out-of-place nodes; auto-inits on DOMContentLoaded; `frond.live` on the
      namespace. sse emits a console warning (its server stream is v1.1). Footer + package bumped to Frond
      v2.2.0 (was v2.1.3/2.1.4). Built both bundles, propagated to all 4 frameworks' public/js + 2 example
      dirs + tina4-css dist (parity: 7x frond.js one md5, 7x frond.min.js one md5). See [[reference_frond_js_build]].
- [x] Live-verified in a real browser (built frond.min.js vs a dynamic /frag server): poll re-renders the
      fragment (timestamp changed), the keyed morph reuses the same input node, and BOTH focus and typed value
      survive the update (caught + fixed a blur bug: unconditional re-append -> minimal-move reconcile). No
      console errors. ws-push path proven by the real-WS `push_live` test. sse browser + server stream = v1.1.
- [x] BANKED: tina4-python `feature/release3.13.52` (engine + endpoint + push_live + 22 tests + propagated
      bundles), tina4-css `feature/frond-live-blocks` (frond.ts + built v2.2.0 bundles). Both pushed.
- [x] PHP mirror BANKED (`tina4-php` feature/release3.13.52). `Tina4/Frond.php`: `handleLive` (parse dispatch)
      builds the live AST node, `renderLiveNode` registers into static `$liveFragments`/`$liveSources`/`$liveWsPaths`
      (cleared in `clearRegistry`), first-paint via `execute($body,$data)` + marker div; statics `renderLive`,
      `liveSource`, `getLiveSource`, `hasLiveFragment`, `getLiveWsPath`, `respondLive`, `pushLive`. `Tina4/App.php`:
      always-on `GET /__frond/live/{name}` via `registerLiveEndpoint()` (after health). `tests/FrondLiveTest.php`
      = 18 real tests (11 engine + 5 endpoint incl auth-reapply + 2 push). Green: 18/18 + 293 Frond regression.
- [x] Ruby mirror BANKED (`tina4-ruby` feature/release3.13.52). `lib/tina4/frond.rb` (single-pass, mirrors
      Python): `LIVE_RE`/`LIVE_WS_RE`/`LIVE_SRC_RE` + `live_attr`; `@@class_live_*` registries + clear; dispatch
      `when "live"`; `handle_live` + class API `render_live`/`live_source`/`get_live_source`/`has_live_fragment?`/
      `get_live_ws_path`/`respond_live`/`push_live`/`register_live_endpoint!`. `WebSocket.current` process-wide
      engine handle (set by RackApp) so `push_live` broadcasts; endpoint registered in `cli.rb` after health.
      `spec/frond_live_spec.rb` = 18 real specs. Green: 18/18 + 283 Frond regression + WS/router/rack_app 247.
- [x] Node mirror BANKED (`tina4-nodejs` feature/release3.13.52). `packages/frond/src/engine.ts` (single-pass):
      LIVE regexes + `liveAttr`; static `liveFragments`/`liveSources`/`liveWsPaths` + clear; dispatch
      `else if (tag === "live")`; `handleLive` + static API `renderLive`/`liveSource`/`getLiveSource`/
      `hasLiveFragment`/`getLiveWsPath`/`respondLive` (pure `{status,body}`)/`pushLive`/`setLiveBroadcaster`;
      new public types `LiveProvider`/`LiveRequest`/`LiveResponse`/`LiveBroadcaster`. `packages/core/src/server.ts`
      registers `GET /__frond/live/{name}` (applies respondLive via `res.html`) + wires the broadcaster to
      `wsRouteManager.broadcastPath` (frond is a zero-dep leaf, cannot import core). `test/frondLive.test.ts`
      = 31 real assertions. Green: 31/31 + 278+18 Frond regression + full typecheck 0 errors.
- [x] All 4 implemented + tested + banked to feature/release3.13.52. Shared frond.js (frond.live) byte-identical
      across all 4 (md5 dc5bc37 / min 43efea6) + carries liveInit. Independent verification: re-ran each suite
      myself (targeted regression + typecheck; the feature has no external dependency so no live-infra run needed).
- [ ] `FROND.md` spec: add the `{% live %}` section (it currently has no "live").
- [ ] Docs (content-writer, ASCII only): new page under each framework's Frond/templates section +
      general concept page; add to cheatsheet.
- [ ] Book: chapter section on live blocks (all 4 books).
- [ ] Re-enable + correct the skills: the `{% live %}` block in `tina4-developer` SKILL.md and the
      `templates-and-frontend` / `frond-and-frontend` references now describes a real feature - align
      wording to the shipped API. (This replaces the pending "delete aspirational doc" task.)
- [ ] Release notes: add the version entry across the 8 `36-releases.md` files + landing `index.md`
      "What's new" (the third doc surface that must bump every release).
- [ ] Version bump all 4 manifests; bump the install-skills pin to the new tag (ships the corrected skill).
- [ ] Retrain note for aatos: once shipped, `{% live %}` is legitimate training data for tina4-coder.
- [ ] feature/release<version> -> v3 ff-merge -> tag -> watch CI green -> publish PyPI/Packagist/RubyGems/npm.

## Locked decisions (rationale)

1. Keep the name `{% live %}` - developers already "know" it from the docs; making it real closes the gap.
2. Ship both data-source forms; provider is the headline DX, `src` is the zero-machinery escape hatch.
3. v1 uses `frond.inject` swap; morph is v1.1. Honest limitation documented for input-bearing blocks.
4. ws/sse are the recommended transports; poll is supported but flagged as the heavy option.

## Open for owner

- Version number: 3.14.0 (signals a real new feature) vs next 3.13.x (stays in the patch line).
- Is v1-without-morph acceptable to ship, or should morph land in the same release?
