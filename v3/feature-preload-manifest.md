# Tina4 Production Feature Preload (lazy load + generated manifest)

## Problem
Tina4 ships ~98 features. Python (`__init__.py`) and Ruby (`lib/tina4.rb`)
eager-load ALL of them at import/require; PHP wires optional + dev subsystems
(DevAdmin, Swagger, MCP) at every `App::start`; Node mostly static-imports.
A production app that uses 6 features pays the memory + boot cost of all 98,
and dev tooling (DevAdmin/MCP) loads in production. Goal: in production, load
ONLY what the app actually uses.

## Three tiers of features
1. **Core (always loaded)** - router, request, response, server, env/config,
   log, events, container. The minimal HTTP runtime.
2. **Dev-only (NEVER in production)** - DevAdmin dashboard, MCP dev server,
   dev error overlay, request logger, gallery, docs_search. Gated on
   `TINA4_DEBUG` truthy / not `--production`. (Partly done; make comprehensive.)
3. **Optional (manifest-driven / load-on-demand)** - ORM, QueryBuilder,
   Migration, Seeder, GraphQL, WSDL, WebSocket, Queue(+one backend),
   Cache(+one backend), Session(+one backend), Messenger, DocStore, MQTT,
   Swagger, Auth, I18n, API client, Realtime/RTC, HtmlElement, Frond.

## The preload manifest (`.tina4/preload.json`)
Generated, committable for reproducible deploys. Example:
```json
{
  "tina4_version": "3.13.82",
  "generated_at": "<iso8601>",
  "src_hash": "<sha256 of src/ tree>",
  "features": ["orm","queryBuilder","migration","graphql","session","auth","frond"],
  "backends": { "database": "postgres", "cache": "redis", "session": "file", "queue": "none" },
  "dependencies_ok": true
}
```
- `features` = subsystems the app references. `backends` = the ONE concrete
  driver per pluggable subsystem, so only that driver loads (not all 7 caches).

## Discovery pass = the "first run checks dependencies"
`tina4 preload` (new CLI cmd), and auto-run by the FIRST `tina4 serve --production`
when no manifest exists:
1. Static-scan `src/{routes,orm,services,app}` for Tina4 subsystem references
   (imports + class/namespace use + route registrations: WSDL ops, GraphQL
   resolvers, WS routes, queue consumers, `getCollection`, `Cache`, `Session`...).
2. Read `.env` for backend selections (`TINA4_CACHE_BACKEND`,
   `TINA4_SESSION_BACKEND`, `TINA4_QUEUE_BACKEND`, `TINA4_DATABASE_URL` scheme).
3. **Check dependencies**: for each used feature+backend confirm its driver /
   extension is installed (ext-mongodb / pymongo / mongo gem / npm driver;
   redis client; pg/mysql/tedious...). Missing -> FAIL with an actionable message.
4. Write the manifest.

## Production boot with the manifest
Framework boot reads `.tina4/preload.json` and eager-loads ONLY the listed
features + core; the rest are never loaded (no GraphQL/WSDL/MQTT/Messenger, no
DevAdmin/MCP, only the one selected cache/session/queue backend). If the manifest
is missing in production, run discovery once then boot (or boot lazy + warn).
Dev (`TINA4_DEBUG=true`) ignores the manifest: everything is available on-demand
+ dev tooling on.

## Per-language lazy mechanism (concept uniform, mechanism idiomatic)
- **Python**: replace eager `__init__.py` imports with **PEP 562 module
  `__getattr__`** - optional subsystems import on first attribute access.
  Manifest -> eager-preload the listed ones (no first-request latency).
- **Ruby**: switch optional `require_relative` in `lib/tina4.rb` to
  **`autoload :GraphQL, "tina4/graphql"`** - deferred until the constant is
  referenced. Manifest -> eager-require the listed ones.
- **Node**: **dynamic `import()`** for optional subsystems at server boot
  (swagger already does this). Manifest -> preload listed; rest on first use.
- **PHP**: PSR-4 already lazy per-class. Gate boot-time WIRING
  (`DevAdmin::register()`, `Swagger::register()`, MCP mount, realtime) behind
  `!production || manifest.includes(...)`. Only wire what's used.

## CLI integration (tina4 Rust CLI)
- `tina4 preload` - run discovery + dependency check + write manifest (report).
- `tina4 serve --production` - no manifest -> run discovery first ("first run
  checks dependencies"), then boot lean; successive runs read the manifest.
- Manifest auto-invalidates when `src_hash` changes (re-run discovery).

## Payoff (ties to the size/perf audit)
- Production loads only used features -> less memory, faster boot.
- Dev tooling (DevAdmin/MCP - the biggest LOC/size chunks) never in prod.
- Only the used DB/cache/queue driver loads, not all backends.
- The code still ships in the package, but the RUNTIME footprint matches the app.

## Parity + scope
Same manifest format + `tina4 preload` + 3-tier model across all 4 frameworks;
per-language mechanism differs as above. Big feature - implement Python master
first, then mirror. Lock-in test per framework: an app using only {orm, graphql}
must NOT load {wsdl, mqtt, messenger, devadmin, mcp} in production (assert via
loaded-modules introspection: sys.modules / $LOADED_FEATURES /
get_declared_classes / require.cache).

## Status: DESIGN - awaiting go-ahead
```
