# 3.13.42 — Swagger configurability (external/public API support)

Closes the four real gaps that forced projects to hand-roll their own OpenAPI
spec instead of using the built-in generator. Python master = reference:
- `tina4-python/tina4_python/swagger/__init__.py`
- tests: `tina4-python/tests/test_swagger_v3_13_42.py`

## The four gaps + the contract (must match Python master behaviour)

### 1. Configurable security schemes + per-route scopes
- **Default bearer format** configurable: env `TINA4_SWAGGER_BEARER_FORMAT` (default `JWT`)
  -> `components.securitySchemes.bearerAuth.bearerFormat`. (Supports opaque / `sk_live_` keys.)
- **apiKey scheme**: when `TINA4_SWAGGER_API_KEY_NAME` is set, emit a scheme named
  `apiKeyAuth` = `{type: apiKey, name: <that>, in: <TINA4_SWAGGER_API_KEY_IN or "header">}`
  (`in` one of header/query/cookie).
- **Default scheme** for secured routes: `TINA4_SWAGGER_DEFAULT_SCHEME` (default `bearerAuth`).
  A secured route with no explicit security gets `[{<default_scheme>: []}]`.
- **Programmatic registry** (parity method names): `Swagger.add_security_scheme(name, definition)`
  and `Swagger.reset_registry()`. Registered schemes are merged into securitySchemes and
  may override the built-in bearerAuth (e.g. register an `oauth2` scheme with scopes).
- **Per-route security** (use each framework's existing route-metadata idiom — decorator,
  swagger_meta, or route `meta`): declare `security` as a normalized OpenAPI requirement list.
  Accept: a scheme name + scopes; a single `{name: [scopes]}` dict; a list of dicts (OR); and
  an explicit "public" (-> emit `security: []`, overriding auth_required).
- **Scope validity**: scopes are kept ONLY for schemes whose registered `type` is
  `oauth2`/`openIdConnect`; for `http`/`apiKey` schemes the scope array is forced to `[]`
  (OpenAPI requires that). This keeps output valid 3.0/3.1.

### 2. Path filtering
- `TINA4_SWAGGER_INCLUDE` (comma-separated prefixes; if set, ONLY routes whose raw path
  starts with one are documented) and `TINA4_SWAGGER_EXCLUDE` (prefixes to drop).
- Framework internals (`/swagger`, `/__dev`) are ALWAYS excluded.

### 3. OpenAPI 3.1 opt-in
- `TINA4_SWAGGER_OPENAPI` (default `3.0.3`); `3.1`/`3.1.0` -> emit `"3.1.0"`. The schemas the
  generator emits are valid in both dialects, so this is a version-string flip.

### 4. Reusable custom component schemas
- `Swagger.add_schema(name, schema)` registers a component schema. A route references it via
  `@request_schema(name)` / `@response_schema(name, status, is_list)` (or the framework's
  meta equivalent), emitting `$ref: #/components/schemas/<name>` and ensuring the schema lands
  in `components.schemas`. This extends the existing ORM-model `$ref` to arbitrary shared schemas.

## Env vars (NEW — must be identical across all 4 + documented; audit-truth gate)
`TINA4_SWAGGER_BEARER_FORMAT`, `TINA4_SWAGGER_API_KEY_NAME`, `TINA4_SWAGGER_API_KEY_IN`,
`TINA4_SWAGGER_DEFAULT_SCHEME`, `TINA4_SWAGGER_INCLUDE`, `TINA4_SWAGGER_EXCLUDE`,
`TINA4_SWAGGER_OPENAPI`.

## Tests (mirror test_swagger_v3_13_42.py, framework-idiomatic)
openapi default 3.0.3 / opt-in 3.1; bearerFormat configurable; apiKey scheme from env;
default-scheme drives secured routes; @security overrides; "public" -> security []; oauth2
scopes preserved; scopes dropped on non-oauth2; OR-requirements; path include/exclude +
internals excluded; request_schema/response_schema $ref + registered schema present.

## Status
Python master DONE + committed (0e790f6 on feature/release3.13.42; full suite 3266, ruff clean).
Mirror PHP/Ruby/Node next, then release 3.13.42 + cleanup branch.
