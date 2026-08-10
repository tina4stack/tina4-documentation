# Tina4 3.14 feature audit ledger

The active audit now follows the flat 132-feature catalog in
`01-FEATURE-MATRIX.md`. Every capability and selectable provider has one whole
number. The old grouped audit remains intact at
`archive/98-feature-audit-pre-flat.md`.

## What changed

- The catalog follows shipped code, starting with the Python module inventory.
- Provider identifiers such as `4.2`, `42.6` and `48.4` are retired.
- Test suites verify features; they are not product features in the count.
- Existing audit evidence moved with its feature packet. It was not discarded.
- A queued packet is present for every feature, but a packet is not complete
  until its closure checklist passes.

## Historical audited set mapped to current numbers

The old audit recorded 32 audited items. That count remains historical evidence;
it does not mean 32 packets meet the 3.14 closure bar.

| Current # | Legacy # | Feature | Packet |
| ---: | ---: | --- | --- |
| 1 | 1 | DotEnv and typed environment | `features/001-dotenv.md` |
| 2 | 2 | Structured logger | `features/002-structured-logger.md` |
| 3 | 3 | Database adapter interface | `features/003-database-adapter-interface.md` |
| 5 | 4 | Database facade and safe writes | `features/005-database-write-facade.md` |
| 4 | 5 | Database URL parser | `features/004-database-url-parser.md` |
| 30 | 6 | Router and dispatch | `features/030-router-and-dispatch.md` |
| 32 | 7 | Middleware pipeline | `features/032-middleware-pipeline.md` |
| 37 | 8 | Health and readiness | `features/037-health-check.md` |
| 38 | 9 | Graceful shutdown | `features/038-graceful-shutdown.md` |
| 33 | 10 | CORS middleware | `features/033-cors-middleware.md` |
| 34 | 11 | Rate limiting | `features/034-rate-limiting.md` |
| 29 | 12 | Response types | `features/029-response-types.md` |
| 16 | 13 | ORM base class | `features/016-orm-base-class.md` |
| 19 | 14 | Soft delete | `features/019-soft-delete.md` |
| 20 | 15 | Relationships | `features/020-relationships.md` |
| 22 | 16 | Scopes | `features/022-scopes.md` |
| 17 | 17 | ORM fields and column mapping | `features/017-orm-fields.md` |
| 23 | 18 | Paginated results | `features/023-paginated-results.md` |
| 24 | 19 | ORM result caching | `features/024-orm-result-caching.md` |
| 18 | 20 | Input and request validation | `features/018-input-validation.md` |
| 14 | 27 | Migrations | `features/014-migrations.md` |
| 47 | 28 | Frond lexer | `features/047-frond-lexer.md` |
| 48 | 29 | Frond parser | `features/048-frond-parser.md` |
| 49 | 30 | Frond compiler | `features/049-frond-compiler.md` |
| 50 | 31 | Frond runtime | `features/050-frond-runtime.md` |
| 51 | 32 | Frond filters | `features/051-frond-filters.md` |
| 56 | 37 | Auto-escaping | `features/056-auto-escaping.md` |
| 57 | 38 | Sandboxing | `features/057-sandboxing.md` |
| 63 | 41 | JWT authentication | `features/063-jwt-authentication.md` |
| 64 | 42 | Session lifecycle | `features/064-session-handling.md` |
| 71 | 43 | Cache interface | `features/071-cache-interface.md` |
| 88 | 48 | Queue lifecycle | `features/088-queue.md` |

## Additional historical evidence

| Current # | Legacy # | Feature | Packet |
| ---: | ---: | --- | --- |
| 58 | 39 | Template caching | `features/058-template-caching.md` |
| 59 | 40 | Fragment caching | `features/059-fragment-caching.md` |
| 44 | 47 | Swagger and OpenAPI | `features/044-swagger-openapi.md` |
| 80 | 50 | HTTP API client | `features/080-api-client.md` |
| 87 | 55 / pilot 0 | Email and messenger | `features/087-email-messenger.md` |
| 114 | 64 | CLI route inspection | `features/114-cli-routes.md` |
| 31 | 79 | Route groups | `features/031-route-groups.md` |

## Current audit rule

The walk runs from Feature 1 through Feature 132. Each audit must complete its
template, owner decisions, shared fixture, mutation witnesses, integration map,
migration notes and clean-room porting capsule. The audit commits each approved
packet as it closes.

The catalog count is not a parity claim. Python code ownership is inventoried;
the PHP, Ruby and Node columns stay marked `inventory pending` until their code
surfaces are checked against the same 132 rows.
