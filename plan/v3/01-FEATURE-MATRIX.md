# Tina4 3.14 flat feature matrix

This catalog follows the code. Every public capability and every selectable
provider has one whole-number identifier. Private helpers stay inside their
owner. Verification suites prove features; they are not counted as product
features.

Numbers are contiguous and append-only from this baseline. The 3.14 reset
retires the old grouped identifiers such as `4.2`, `42.6` and `48.4`.
Historical documents remain in `archive/`; active packets use this table.

**Current catalog: 133 flat features.**

## Foundation

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | [DotEnv and typed environment](features/001-dotenv.md) | `tina4_python/dotenv/__init__.py; tina4_python/env.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 2 | [Structured logger](features/002-structured-logger.md) | `tina4_python/debug/__init__.py` | inventory pending | inventory pending | inventory pending | decision-ready |

## Database and providers

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 3 | [Database adapter interface](features/003-database-adapter-interface.md) | `tina4_python/database/adapter.py; tina4_python/database/connection.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 4 | [Database URL parser](features/004-database-url-parser.md) | `tina4_python/database/database_url.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 5 | [Database facade and safe writes](features/005-database-write-facade.md) | `tina4_python/database/__init__.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 6 | [Query builder](features/006-query-builder.md) | `tina4_python/query_builder/__init__.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 7 | [SQL translator](features/007-sql-translator.md) | `tina4_python/database/sql_translator.py` | inventory pending | inventory pending | inventory pending | queued |
| 8 | [SQLite provider](features/008-sqlite-provider.md) | `tina4_python/database/sqlite.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 9 | [PostgreSQL provider](features/009-postgresql-provider.md) | `tina4_python/database/postgres.py` | inventory pending | inventory pending | inventory pending | queued |
| 10 | [MySQL provider](features/010-mysql-provider.md) | `tina4_python/database/mysql.py` | inventory pending | inventory pending | inventory pending | queued |
| 11 | [MSSQL provider](features/011-mssql-provider.md) | `tina4_python/database/mssql.py` | inventory pending | inventory pending | inventory pending | queued |
| 12 | [Firebird provider](features/012-firebird-provider.md) | `tina4_python/database/firebird.py` | inventory pending | inventory pending | inventory pending | queued |
| 13 | [ODBC provider](features/013-odbc-provider.md) | `tina4_python/database/odbc.py` | inventory pending | inventory pending | inventory pending | queued |
| 14 | [MongoDB SQL-translation provider](features/014-mongodb-sql-provider.md) | `tina4_python/database/mongodb.py` | inventory pending | inventory pending | inventory pending | queued |
| 15 | [Migrations](features/015-migrations.md) | `tina4_python/migration/__init__.py; tina4_python/migration/runner.py` | inventory pending | inventory pending | inventory pending | auditing |
| 16 | [Race-safe database sequences](features/016-database-next-id.md) | `tina4_python/database/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## ORM and data layer

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 17 | [ORM base class](features/017-orm-base-class.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 18 | [ORM fields and column mapping](features/018-orm-fields.md) | `tina4_python/orm/fields.py` | inventory pending | inventory pending | inventory pending | auditing |
| 19 | [Input and request validation](features/019-input-validation.md) | `tina4_python/validator/__init__.py; tina4_python/orm/fields.py` | inventory pending | inventory pending | inventory pending | auditing |
| 20 | [Soft delete](features/020-soft-delete.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 21 | [Declarative ORM relationships](features/021-relationships.md) | `tina4_python/orm/__init__.py; tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 22 | [Imperative ORM relationships](features/022-imperative-relationships.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | queued |
| 23 | [ORM scopes](features/023-scopes.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 24 | [Paginated database and ORM results](features/024-paginated-results.md) | `tina4_python/database/__init__.py; tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 25 | [ORM result caching](features/025-orm-result-caching.md) | `tina4_python/orm/model.py; tina4_python/core/cache.py` | inventory pending | inventory pending | inventory pending | auditing |
| 26 | [ORM instance loading](features/026-orm-load.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | queued |
| 27 | [Automatic CRUD from models](features/027-auto-crud.md) | `tina4_python/crud/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 28 | [Seeder and fake data](features/028-seeder-fake-data.md) | `tina4_python/seeder/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## HTTP core

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 29 | [HTTP request model](features/029-request.md) | `tina4_python/core/request.py` | inventory pending | inventory pending | inventory pending | queued |
| 30 | [HTTP response model and representation types](features/030-response-types.md) | `tina4_python/core/response.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 31 | [Router and dispatch](features/031-router-and-dispatch.md) | `tina4_python/core/router.py; tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 32 | [Route groups](features/032-route-groups.md) | `tina4_python/core/router.py` | inventory pending | inventory pending | inventory pending | auditing |
| 33 | [Middleware pipeline](features/033-middleware-pipeline.md) | `tina4_python/core/middleware.py; tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | decision-ready |

## HTTP policies

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 34 | [CORS middleware](features/034-cors-middleware.md) | `tina4_python/core/middleware.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 35 | [Rate limiting](features/035-rate-limiting.md) | `tina4_python/core/rate_limiter.py; tina4_python/core/middleware.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 36 | [Security headers middleware](features/036-security-headers.md) | `tina4_python/core/middleware.py` | inventory pending | inventory pending | inventory pending | queued |
| 37 | [CSRF protection](features/037-csrf.md) | `tina4_python/core/middleware.py` | inventory pending | inventory pending | inventory pending | queued |

## HTTP runtime

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 38 | [Health and readiness endpoints](features/038-health-check.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 39 | [Graceful shutdown](features/039-graceful-shutdown.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 40 | [HTTP compression and ETag](features/040-compression-etag.md) | `tina4_python/core/response.py; tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |
| 41 | [Static assets and cache revalidation](features/041-static-assets.md) | `tina4_python/core/server.py; tina4_python/public/` | inventory pending | inventory pending | inventory pending | queued |
| 42 | [Configurable error pages](features/042-error-pages.md) | `tina4_python/core/server.py; tina4_python/templates/errors/` | inventory pending | inventory pending | inventory pending | queued |
| 43 | [Request ID tracking](features/043-request-id.md) | `tina4_python/core/request.py; tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |
| 44 | [File upload contract](features/044-file-upload.md) | `tina4_python/core/request.py` | inventory pending | inventory pending | inventory pending | queued |
| 45 | [Swagger and OpenAPI](features/045-swagger-openapi.md) | `tina4_python/swagger/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 46 | [Default landing page](features/046-default-landing-page.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |
| 47 | [In-process background tasks](features/047-background-tasks.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |

## Frond template engine

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 48 | [Frond lexer](features/048-frond-lexer.md) | `tina4_python/frond/parser.py` | inventory pending | inventory pending | inventory pending | auditing |
| 49 | [Frond parser](features/049-frond-parser.md) | `tina4_python/frond/parser.py` | inventory pending | inventory pending | inventory pending | auditing |
| 50 | [Frond compiler](features/050-frond-compiler.md) | `tina4_python/frond/compiler.py` | inventory pending | inventory pending | inventory pending | auditing |
| 51 | [Frond runtime](features/051-frond-runtime.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 52 | [Frond filters](features/052-frond-filters.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 53 | [Frond tags](features/053-frond-tags.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | queued |
| 54 | [Frond expression tests](features/054-frond-tests.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | queued |
| 55 | [Frond functions](features/055-frond-functions.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | queued |
| 56 | [Frond extensibility API](features/056-frond-extensibility.md) | `tina4_python/frond/__init__.py; tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | queued |
| 57 | [Frond auto-escaping](features/057-auto-escaping.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 58 | [Frond sandboxing](features/058-sandboxing.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 59 | [Frond template caching](features/059-template-caching.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 60 | [Frond fragment caching](features/060-fragment-caching.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |

## Frontend assets

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 61 | [SCSS compiler](features/061-scss-compiler.md) | MOVED TO CLIENT: compiler in tina4 CLI (`tina4/src/scss.rs`), source in `tina4-css` repo; framework bundle removed | n/a (client) | n/a (client) | n/a (client) | client |
| 62 | [Tina4 CSS](features/062-tina4-css.md) | CLIENT ASSET: source+build in `tina4-css` repo (`dist/tina4.css`); framework vendors compiled `public/css/` byte-for-byte and serves it (stays) | vendored (client) | vendored (client) | vendored (client) | client |
| 63 | [Frond and Tina4 browser helpers](features/063-frond-js-helper.md) | CLIENT ASSET: source+build in `tina4-js` repo (esbuild); framework vendors compiled `public/js/` (`frond.js` etc.) and serves it (stays) | vendored (client) | vendored (client) | vendored (client) | client |

## Authentication

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 64 | [JWT and request authentication](features/064-jwt-authentication.md) | `tina4_python/auth/__init__.py` | `Tina4/Auth.php` | `lib/tina4/auth.rb` | `packages/core/src/auth.ts` + `authGate.ts` | decision-ready |

## Sessions and providers

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 65 | [Session lifecycle](features/065-session-handling.md) | `tina4_python/session/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 66 | [File session provider](features/066-session-file-provider.md) | `tina4_python/session/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 67 | [Redis session provider](features/067-session-redis-provider.md) | `tina4_python/session_handlers/redis_handler.py` | inventory pending | inventory pending | inventory pending | queued |
| 68 | [Valkey session provider](features/068-session-valkey-provider.md) | `tina4_python/session_handlers/valkey_handler.py` | inventory pending | inventory pending | inventory pending | queued |
| 69 | [MongoDB session provider](features/069-session-mongodb-provider.md) | `tina4_python/session_handlers/mongodb_handler.py` | inventory pending | inventory pending | inventory pending | queued |
| 70 | [Database session provider](features/070-session-database-provider.md) | `tina4_python/session/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 71 | [Memcached session provider](features/071-session-memcached-provider.md) | `tina4_python/session_handlers/memcached_handler.py` | inventory pending | inventory pending | inventory pending | queued |

## Cache and providers

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 72 | [Cache interface and provider selection](features/072-cache-interface.md) | `tina4_python/cache/__init__.py; tina4_python/core/cache.py` | inventory pending | inventory pending | inventory pending | auditing |
| 73 | [Memory cache provider](features/073-cache-memory-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 74 | [File cache provider](features/074-cache-file-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 75 | [Redis cache provider](features/075-cache-redis-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 76 | [Valkey cache provider](features/076-cache-valkey-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 77 | [Memcached cache provider](features/077-cache-memcached-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 78 | [MongoDB cache provider](features/078-cache-mongodb-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 79 | [Database cache provider](features/079-cache-database-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 80 | [HTTP response cache](features/080-response-cache.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## Integrations and storage

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 81 | [Standard-library HTTP API client](features/081-api-client.md) | `tina4_python/api/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 82 | [GraphQL](features/082-graphql.md) | `tina4_python/graphql/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 83 | [WebSocket protocol and server](features/083-websocket.md) | `tina4_python/websocket/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 84 | [Redis WebSocket backplane](features/084-websocket-redis-backplane.md) | `tina4_python/websocket/backplane.py` | inventory pending | inventory pending | inventory pending | queued |
| 85 | [NATS WebSocket backplane](features/085-websocket-nats-backplane.md) | `tina4_python/websocket/backplane.py` | inventory pending | inventory pending | inventory pending | queued |
| 86 | [WSDL and SOAP](features/086-wsdl-soap.md) | `tina4_python/wsdl/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 87 | [Localization and i18n](features/087-localization-i18n.md) | `tina4_python/i18n/__init__.py; tina4_python/translations/` | inventory pending | inventory pending | inventory pending | queued |
| 88 | [Email and messenger](features/088-email-messenger.md) | `tina4_python/messenger/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 89 | [Queue lifecycle](features/089-queue.md) | `tina4_python/queue/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 90 | [Lite queue provider](features/090-queue-lite-provider.md) | `tina4_python/queue/lite_backend.py` | inventory pending | inventory pending | inventory pending | queued |
| 91 | [RabbitMQ queue provider](features/091-queue-rabbitmq-provider.md) | `tina4_python/queue/rabbitmq_backend.py; tina4_python/queue_backends/rabbitmq_backend.py` | inventory pending | inventory pending | inventory pending | queued |
| 92 | [Kafka queue provider](features/092-queue-kafka-provider.md) | `tina4_python/queue/kafka_backend.py; tina4_python/queue_backends/kafka_backend.py` | inventory pending | inventory pending | inventory pending | queued |
| 93 | [MongoDB queue provider](features/093-queue-mongodb-provider.md) | `tina4_python/queue/mongo_backend.py; tina4_python/queue_backends/mongo_backend.py` | inventory pending | inventory pending | inventory pending | queued |
| 94 | [MQTT client](features/094-mqtt.md) | `tina4_python/mqtt/__init__.py; tina4_python/mqtt/message.py` | inventory pending | inventory pending | inventory pending | queued |
| 95 | [Document store interface](features/095-docstore.md) | `tina4_python/docstore/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 96 | [SQLite document store provider](features/096-docstore-sqlite-provider.md) | `tina4_python/docstore/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 97 | [MongoDB document store provider](features/097-docstore-mongodb-provider.md) | `tina4_python/docstore/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 98 | [Realtime collaboration](features/098-realtime-collaboration.md) | `tina4_python/realtime/__init__.py; tina4_python/realtime/models/` | inventory pending | inventory pending | inventory pending | queued |
| 99 | [Local realtime attachment storage](features/099-realtime-local-storage.md) | `tina4_python/realtime/storage.py` | inventory pending | inventory pending | inventory pending | queued |
| 100 | [S3 realtime attachment storage](features/100-realtime-s3-storage.md) | `tina4_python/realtime/storage.py` | inventory pending | inventory pending | inventory pending | queued |
| 101 | [Model Context Protocol server](features/101-mcp-server.md) | `tina4_python/mcp/__init__.py; tina4_python/mcp/protocol.py; tina4_python/mcp/tools.py` | inventory pending | inventory pending | inventory pending | queued |
| 102 | [Local source and documentation context index](features/102-context-index.md) | `tina4_python/context/__init__.py; tina4_python/context/chunker.py` | inventory pending | inventory pending | inventory pending | queued |
| 103 | [Live framework and application API index](features/103-live-api-index.md) | `tina4_python/docs.py` | inventory pending | inventory pending | inventory pending | queued |

## Application runtime

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 104 | [Event and listener system](features/104-events.md) | `tina4_python/core/events.py` | inventory pending | inventory pending | inventory pending | queued |
| 105 | [Dependency injection container](features/105-dependency-injection.md) | `tina4_python/container/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 106 | [Service runner](features/106-service-runner.md) | `tina4_python/service/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 107 | [HTML element builder](features/107-html-element.md) | `tina4_python/HtmlElement.py` | inventory pending | inventory pending | inventory pending | queued |
| 108 | [AI coding-tool integration](features/108-ai-tool-integration.md) | `tina4_python/ai/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 109 | [Lazy feature loading and preload manifest](features/109-feature-preload.md) | `tina4_python/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## CLI

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 110 | [CLI project initialization](features/110-cli-init.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 111 | [CLI development server](features/111-cli-serve.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 112 | [CLI migrations](features/112-cli-migrate.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 113 | [CLI seeding](features/113-cli-seed.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 114 | [CLI test runner](features/114-cli-test.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 115 | [CLI route inspection](features/115-cli-routes.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 116 | [CLI interactive console](features/116-cli-console.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 117 | [CLI environment management](features/117-cli-env.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 118 | [CLI queue management](features/118-cli-queue.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 119 | [CLI container build](features/119-cli-build.md) | `tina4_python/cli/__init__.py; tina4_python/templates/docker/` | inventory pending | inventory pending | inventory pending | queued |
| 120 | [CLI code generation](features/120-cli-generate.md) | `tina4_python/cli/__init__.py; tina4_python/templates/` | inventory pending | inventory pending | inventory pending | queued |
| 121 | [CLI code metrics](features/121-cli-metrics.md) | `tina4_python/cli/__init__.py; tina4_python/dev_admin/metrics.py` | inventory pending | inventory pending | inventory pending | queued |
| 122 | [CLI command discovery and help](features/122-cli-commands.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 123 | [CLI doctor](features/123-cli-doctor.md) | `delegated by tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 124 | [CLI guided setup](features/124-cli-setup.md) | `delegated by tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 125 | [CLI deployment](features/125-cli-deploy.md) | `delegated by tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## Developer runtime

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 126 | [Development error overlay](features/126-debug-overlay.md) | `tina4_python/debug/error_overlay.py` | inventory pending | inventory pending | inventory pending | queued |
| 127 | [Development admin dashboard](features/127-dev-admin.md) | `tina4_python/dev_admin/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 128 | [Dual development and test ports](features/128-dual-test-port.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |
| 129 | [Development port takeover](features/129-port-takeover.md) | `tina4_python/core/server.py; tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 130 | [Dynamic framework version](features/130-dynamic-version.md) | `tina4_python/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## Testing and verification tools

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 131 | [In-process HTTP test client](features/131-test-client.md) | `tina4_python/test_client/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 132 | [Inline testing API](features/132-inline-testing.md) | `tina4_python/Testing.py; tina4_python/test/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 133 | [Carbonah benchmark contract](features/133-carbonah-benchmarks.md) | `benchmarks/ and plan/v3/CARBONAH.md` | inventory pending | inventory pending | inventory pending | queued |
