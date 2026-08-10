# Tina4 3.14 feature audit ledger

The active audit now follows the flat 133-feature catalog in
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
| 31 | 6 | Router and dispatch | `features/031-router-and-dispatch.md` |
| 33 | 7 | Middleware pipeline | `features/033-middleware-pipeline.md` |
| 38 | 8 | Health and readiness | `features/038-health-check.md` |
| 39 | 9 | Graceful shutdown | `features/039-graceful-shutdown.md` |
| 34 | 10 | CORS middleware | `features/034-cors-middleware.md` |
| 35 | 11 | Rate limiting | `features/035-rate-limiting.md` |
| 30 | 12 | Response types | `features/030-response-types.md` |
| 17 | 13 | ORM base class | `features/017-orm-base-class.md` |
| 20 | 14 | Soft delete | `features/020-soft-delete.md` |
| 21 | 15 | Relationships | `features/021-relationships.md` |
| 23 | 16 | Scopes | `features/023-scopes.md` |
| 18 | 17 | ORM fields and column mapping | `features/018-orm-fields.md` |
| 24 | 18 | Paginated results | `features/024-paginated-results.md` |
| 25 | 19 | ORM result caching | `features/025-orm-result-caching.md` |
| 19 | 20 | Input and request validation | `features/019-input-validation.md` |
| 15 | 27 | Migrations | `features/015-migrations.md` |
| 48 | 28 | Frond lexer | `features/048-frond-lexer.md` |
| 49 | 29 | Frond parser | `features/049-frond-parser.md` |
| 50 | 30 | Frond compiler | `features/050-frond-compiler.md` |
| 51 | 31 | Frond runtime | `features/051-frond-runtime.md` |
| 52 | 32 | Frond filters | `features/052-frond-filters.md` |
| 57 | 37 | Auto-escaping | `features/057-auto-escaping.md` |
| 58 | 38 | Sandboxing | `features/058-sandboxing.md` |
| 64 | 41 | JWT authentication | `features/064-jwt-authentication.md` |
| 65 | 42 | Session lifecycle | `features/065-session-handling.md` |
| 72 | 43 | Cache interface | `features/072-cache-interface.md` |
| 89 | 48 | Queue lifecycle | `features/089-queue.md` |

## Additional historical evidence

| Current # | Legacy # | Feature | Packet |
| ---: | ---: | --- | --- |
| 59 | 39 | Template caching | `features/059-template-caching.md` |
| 60 | 40 | Fragment caching | `features/060-fragment-caching.md` |
| 45 | 47 | Swagger and OpenAPI | `features/045-swagger-openapi.md` |
| 81 | 50 | HTTP API client | `features/081-api-client.md` |
| 88 | 55 / pilot 0 | Email and messenger | `features/088-email-messenger.md` |
| 115 | 64 | CLI route inspection | `features/115-cli-routes.md` |
| 32 | 79 | Route groups | `features/032-route-groups.md` |

## Current audit rule

The walk runs from Feature 1 through Feature 133. Each audit must complete its
template, owner decisions, shared fixture, mutation witnesses, integration map,
migration notes and clean-room porting capsule. The audit commits each approved
packet as it closes.

The catalog count is not a parity claim. Python code ownership is inventoried;
the PHP, Ruby and Node columns stay marked `inventory pending` until their code
surfaces are checked against the same 133 rows.
