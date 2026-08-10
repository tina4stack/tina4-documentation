# Tina4 3.14 flat feature matrix

This catalog follows the code. Every public capability and every selectable
provider has one whole-number identifier. Private helpers stay inside their
owner. Verification suites prove features; they are not counted as product
features.

Numbers are contiguous and append-only from this baseline. The 3.14 reset
retires the old grouped identifiers such as `4.2`, `42.6` and `48.4`.
Historical documents remain in `archive/`; active packets use this table.

**Current catalog: 132 flat features.**

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
| 6 | [Query builder and SQL translation](features/006-query-builder.md) | `tina4_python/query_builder/__init__.py; tina4_python/database/sql_translator.py` | inventory pending | inventory pending | inventory pending | queued |
| 7 | [SQLite provider](features/007-sqlite-provider.md) | `tina4_python/database/sqlite.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 8 | [PostgreSQL provider](features/008-postgresql-provider.md) | `tina4_python/database/postgres.py` | inventory pending | inventory pending | inventory pending | queued |
| 9 | [MySQL provider](features/009-mysql-provider.md) | `tina4_python/database/mysql.py` | inventory pending | inventory pending | inventory pending | queued |
| 10 | [MSSQL provider](features/010-mssql-provider.md) | `tina4_python/database/mssql.py` | inventory pending | inventory pending | inventory pending | queued |
| 11 | [Firebird provider](features/011-firebird-provider.md) | `tina4_python/database/firebird.py` | inventory pending | inventory pending | inventory pending | queued |
| 12 | [ODBC provider](features/012-odbc-provider.md) | `tina4_python/database/odbc.py` | inventory pending | inventory pending | inventory pending | queued |
| 13 | [MongoDB SQL-translation provider](features/013-mongodb-sql-provider.md) | `tina4_python/database/mongodb.py` | inventory pending | inventory pending | inventory pending | queued |
| 14 | [Migrations](features/014-migrations.md) | `tina4_python/migration/__init__.py; tina4_python/migration/runner.py` | inventory pending | inventory pending | inventory pending | auditing |
| 15 | [Race-safe database sequences](features/015-database-next-id.md) | `tina4_python/database/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## ORM and data layer

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 16 | [ORM base class](features/016-orm-base-class.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 17 | [ORM fields and column mapping](features/017-orm-fields.md) | `tina4_python/orm/fields.py` | inventory pending | inventory pending | inventory pending | auditing |
| 18 | [Input and request validation](features/018-input-validation.md) | `tina4_python/validator/__init__.py; tina4_python/orm/fields.py` | inventory pending | inventory pending | inventory pending | auditing |
| 19 | [Soft delete](features/019-soft-delete.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 20 | [Declarative ORM relationships](features/020-relationships.md) | `tina4_python/orm/__init__.py; tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 21 | [Imperative ORM relationships](features/021-imperative-relationships.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | queued |
| 22 | [ORM scopes](features/022-scopes.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 23 | [Paginated database and ORM results](features/023-paginated-results.md) | `tina4_python/database/__init__.py; tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | auditing |
| 24 | [ORM result caching](features/024-orm-result-caching.md) | `tina4_python/orm/model.py; tina4_python/core/cache.py` | inventory pending | inventory pending | inventory pending | auditing |
| 25 | [ORM instance loading](features/025-orm-load.md) | `tina4_python/orm/model.py` | inventory pending | inventory pending | inventory pending | queued |
| 26 | [Automatic CRUD from models](features/026-auto-crud.md) | `tina4_python/crud/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 27 | [Seeder and fake data](features/027-seeder-fake-data.md) | `tina4_python/seeder/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## HTTP core

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 28 | [HTTP request model](features/028-request.md) | `tina4_python/core/request.py` | inventory pending | inventory pending | inventory pending | queued |
| 29 | [HTTP response model and representation types](features/029-response-types.md) | `tina4_python/core/response.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 30 | [Router and dispatch](features/030-router-and-dispatch.md) | `tina4_python/core/router.py; tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 31 | [Route groups](features/031-route-groups.md) | `tina4_python/core/router.py` | inventory pending | inventory pending | inventory pending | auditing |
| 32 | [Middleware pipeline](features/032-middleware-pipeline.md) | `tina4_python/core/middleware.py; tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | decision-ready |

## HTTP policies

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 33 | [CORS middleware](features/033-cors-middleware.md) | `tina4_python/core/middleware.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 34 | [Rate limiting](features/034-rate-limiting.md) | `tina4_python/core/rate_limiter.py; tina4_python/core/middleware.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 35 | [Security headers middleware](features/035-security-headers.md) | `tina4_python/core/middleware.py` | inventory pending | inventory pending | inventory pending | queued |
| 36 | [CSRF protection](features/036-csrf.md) | `tina4_python/core/middleware.py` | inventory pending | inventory pending | inventory pending | queued |

## HTTP runtime

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 37 | [Health and readiness endpoints](features/037-health-check.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 38 | [Graceful shutdown](features/038-graceful-shutdown.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | decision-ready |
| 39 | [HTTP compression and ETag](features/039-compression-etag.md) | `tina4_python/core/response.py; tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |
| 40 | [Static assets and cache revalidation](features/040-static-assets.md) | `tina4_python/core/server.py; tina4_python/public/` | inventory pending | inventory pending | inventory pending | queued |
| 41 | [Configurable error pages](features/041-error-pages.md) | `tina4_python/core/server.py; tina4_python/templates/errors/` | inventory pending | inventory pending | inventory pending | queued |
| 42 | [Request ID tracking](features/042-request-id.md) | `tina4_python/core/request.py; tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |
| 43 | [File upload contract](features/043-file-upload.md) | `tina4_python/core/request.py` | inventory pending | inventory pending | inventory pending | queued |
| 44 | [Swagger and OpenAPI](features/044-swagger-openapi.md) | `tina4_python/swagger/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 45 | [Default landing page](features/045-default-landing-page.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |
| 46 | [In-process background tasks](features/046-background-tasks.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |

## Frond template engine

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 47 | [Frond lexer](features/047-frond-lexer.md) | `tina4_python/frond/parser.py` | inventory pending | inventory pending | inventory pending | auditing |
| 48 | [Frond parser](features/048-frond-parser.md) | `tina4_python/frond/parser.py` | inventory pending | inventory pending | inventory pending | auditing |
| 49 | [Frond compiler](features/049-frond-compiler.md) | `tina4_python/frond/compiler.py` | inventory pending | inventory pending | inventory pending | auditing |
| 50 | [Frond runtime](features/050-frond-runtime.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 51 | [Frond filters](features/051-frond-filters.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 52 | [Frond tags](features/052-frond-tags.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | queued |
| 53 | [Frond expression tests](features/053-frond-tests.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | queued |
| 54 | [Frond functions](features/054-frond-functions.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | queued |
| 55 | [Frond extensibility API](features/055-frond-extensibility.md) | `tina4_python/frond/__init__.py; tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | queued |
| 56 | [Frond auto-escaping](features/056-auto-escaping.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 57 | [Frond sandboxing](features/057-sandboxing.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 58 | [Frond template caching](features/058-template-caching.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |
| 59 | [Frond fragment caching](features/059-fragment-caching.md) | `tina4_python/frond/engine.py` | inventory pending | inventory pending | inventory pending | auditing |

## Frontend assets

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 60 | [SCSS compiler](features/060-scss-compiler.md) | `tina4_python/scss/; framework SCSS compiler surface` | inventory pending | inventory pending | inventory pending | queued |
| 61 | [Tina4 CSS](features/061-tina4-css.md) | `tina4_python/public/css/; tina4_python/scss/` | inventory pending | inventory pending | inventory pending | queued |
| 62 | [Frond and Tina4 browser helpers](features/062-frond-js-helper.md) | `tina4_python/public/js/` | inventory pending | inventory pending | inventory pending | queued |

## Authentication

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 63 | [JWT and request authentication](features/063-jwt-authentication.md) | `tina4_python/auth/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |

## Sessions and providers

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 64 | [Session lifecycle](features/064-session-handling.md) | `tina4_python/session/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 65 | [File session provider](features/065-session-file-provider.md) | `tina4_python/session/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 66 | [Redis session provider](features/066-session-redis-provider.md) | `tina4_python/session_handlers/redis_handler.py` | inventory pending | inventory pending | inventory pending | queued |
| 67 | [Valkey session provider](features/067-session-valkey-provider.md) | `tina4_python/session_handlers/valkey_handler.py` | inventory pending | inventory pending | inventory pending | queued |
| 68 | [MongoDB session provider](features/068-session-mongodb-provider.md) | `tina4_python/session_handlers/mongodb_handler.py` | inventory pending | inventory pending | inventory pending | queued |
| 69 | [Database session provider](features/069-session-database-provider.md) | `tina4_python/session/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 70 | [Memcached session provider](features/070-session-memcached-provider.md) | `tina4_python/session_handlers/memcached_handler.py` | inventory pending | inventory pending | inventory pending | queued |

## Cache and providers

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 71 | [Cache interface and provider selection](features/071-cache-interface.md) | `tina4_python/cache/__init__.py; tina4_python/core/cache.py` | inventory pending | inventory pending | inventory pending | auditing |
| 72 | [Memory cache provider](features/072-cache-memory-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 73 | [File cache provider](features/073-cache-file-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 74 | [Redis cache provider](features/074-cache-redis-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 75 | [Valkey cache provider](features/075-cache-valkey-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 76 | [Memcached cache provider](features/076-cache-memcached-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 77 | [MongoDB cache provider](features/077-cache-mongodb-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 78 | [Database cache provider](features/078-cache-database-provider.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 79 | [HTTP response cache](features/079-response-cache.md) | `tina4_python/cache/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## Integrations and storage

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 80 | [Standard-library HTTP API client](features/080-api-client.md) | `tina4_python/api/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 81 | [GraphQL](features/081-graphql.md) | `tina4_python/graphql/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 82 | [WebSocket protocol and server](features/082-websocket.md) | `tina4_python/websocket/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 83 | [Redis WebSocket backplane](features/083-websocket-redis-backplane.md) | `tina4_python/websocket/backplane.py` | inventory pending | inventory pending | inventory pending | queued |
| 84 | [NATS WebSocket backplane](features/084-websocket-nats-backplane.md) | `tina4_python/websocket/backplane.py` | inventory pending | inventory pending | inventory pending | queued |
| 85 | [WSDL and SOAP](features/085-wsdl-soap.md) | `tina4_python/wsdl/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 86 | [Localization and i18n](features/086-localization-i18n.md) | `tina4_python/i18n/__init__.py; tina4_python/translations/` | inventory pending | inventory pending | inventory pending | queued |
| 87 | [Email and messenger](features/087-email-messenger.md) | `tina4_python/messenger/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 88 | [Queue lifecycle](features/088-queue.md) | `tina4_python/queue/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 89 | [Lite queue provider](features/089-queue-lite-provider.md) | `tina4_python/queue/lite_backend.py` | inventory pending | inventory pending | inventory pending | queued |
| 90 | [RabbitMQ queue provider](features/090-queue-rabbitmq-provider.md) | `tina4_python/queue/rabbitmq_backend.py; tina4_python/queue_backends/rabbitmq_backend.py` | inventory pending | inventory pending | inventory pending | queued |
| 91 | [Kafka queue provider](features/091-queue-kafka-provider.md) | `tina4_python/queue/kafka_backend.py; tina4_python/queue_backends/kafka_backend.py` | inventory pending | inventory pending | inventory pending | queued |
| 92 | [MongoDB queue provider](features/092-queue-mongodb-provider.md) | `tina4_python/queue/mongo_backend.py; tina4_python/queue_backends/mongo_backend.py` | inventory pending | inventory pending | inventory pending | queued |
| 93 | [MQTT client](features/093-mqtt.md) | `tina4_python/mqtt/__init__.py; tina4_python/mqtt/message.py` | inventory pending | inventory pending | inventory pending | queued |
| 94 | [Document store interface](features/094-docstore.md) | `tina4_python/docstore/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 95 | [SQLite document store provider](features/095-docstore-sqlite-provider.md) | `tina4_python/docstore/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 96 | [MongoDB document store provider](features/096-docstore-mongodb-provider.md) | `tina4_python/docstore/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 97 | [Realtime collaboration](features/097-realtime-collaboration.md) | `tina4_python/realtime/__init__.py; tina4_python/realtime/models/` | inventory pending | inventory pending | inventory pending | queued |
| 98 | [Local realtime attachment storage](features/098-realtime-local-storage.md) | `tina4_python/realtime/storage.py` | inventory pending | inventory pending | inventory pending | queued |
| 99 | [S3 realtime attachment storage](features/099-realtime-s3-storage.md) | `tina4_python/realtime/storage.py` | inventory pending | inventory pending | inventory pending | queued |
| 100 | [Model Context Protocol server](features/100-mcp-server.md) | `tina4_python/mcp/__init__.py; tina4_python/mcp/protocol.py; tina4_python/mcp/tools.py` | inventory pending | inventory pending | inventory pending | queued |
| 101 | [Local source and documentation context index](features/101-context-index.md) | `tina4_python/context/__init__.py; tina4_python/context/chunker.py` | inventory pending | inventory pending | inventory pending | queued |
| 102 | [Live framework and application API index](features/102-live-api-index.md) | `tina4_python/docs.py` | inventory pending | inventory pending | inventory pending | queued |

## Application runtime

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 103 | [Event and listener system](features/103-events.md) | `tina4_python/core/events.py` | inventory pending | inventory pending | inventory pending | queued |
| 104 | [Dependency injection container](features/104-dependency-injection.md) | `tina4_python/container/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 105 | [Service runner](features/105-service-runner.md) | `tina4_python/service/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 106 | [HTML element builder](features/106-html-element.md) | `tina4_python/HtmlElement.py` | inventory pending | inventory pending | inventory pending | queued |
| 107 | [AI coding-tool integration](features/107-ai-tool-integration.md) | `tina4_python/ai/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 108 | [Lazy feature loading and preload manifest](features/108-feature-preload.md) | `tina4_python/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## CLI

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 109 | [CLI project initialization](features/109-cli-init.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 110 | [CLI development server](features/110-cli-serve.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 111 | [CLI migrations](features/111-cli-migrate.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 112 | [CLI seeding](features/112-cli-seed.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 113 | [CLI test runner](features/113-cli-test.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 114 | [CLI route inspection](features/114-cli-routes.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | auditing |
| 115 | [CLI interactive console](features/115-cli-console.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 116 | [CLI environment management](features/116-cli-env.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 117 | [CLI queue management](features/117-cli-queue.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 118 | [CLI container build](features/118-cli-build.md) | `tina4_python/cli/__init__.py; tina4_python/templates/docker/` | inventory pending | inventory pending | inventory pending | queued |
| 119 | [CLI code generation](features/119-cli-generate.md) | `tina4_python/cli/__init__.py; tina4_python/templates/` | inventory pending | inventory pending | inventory pending | queued |
| 120 | [CLI code metrics](features/120-cli-metrics.md) | `tina4_python/cli/__init__.py; tina4_python/dev_admin/metrics.py` | inventory pending | inventory pending | inventory pending | queued |
| 121 | [CLI command discovery and help](features/121-cli-commands.md) | `tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 122 | [CLI doctor](features/122-cli-doctor.md) | `delegated by tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 123 | [CLI guided setup](features/123-cli-setup.md) | `delegated by tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 124 | [CLI deployment](features/124-cli-deploy.md) | `delegated by tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## Developer runtime

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 125 | [Development error overlay](features/125-debug-overlay.md) | `tina4_python/debug/error_overlay.py` | inventory pending | inventory pending | inventory pending | queued |
| 126 | [Development admin dashboard](features/126-dev-admin.md) | `tina4_python/dev_admin/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 127 | [Dual development and test ports](features/127-dual-test-port.md) | `tina4_python/core/server.py` | inventory pending | inventory pending | inventory pending | queued |
| 128 | [Development port takeover](features/128-port-takeover.md) | `tina4_python/core/server.py; tina4_python/cli/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 129 | [Dynamic framework version](features/129-dynamic-version.md) | `tina4_python/__init__.py` | inventory pending | inventory pending | inventory pending | queued |

## Testing and verification tools

| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |
| ---: | --- | --- | --- | --- | --- | --- |
| 130 | [In-process HTTP test client](features/130-test-client.md) | `tina4_python/test_client/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 131 | [Inline testing API](features/131-inline-testing.md) | `tina4_python/Testing.py; tina4_python/test/__init__.py` | inventory pending | inventory pending | inventory pending | queued |
| 132 | [Carbonah benchmark contract](features/132-carbonah-benchmarks.md) | `benchmarks/ and plan/v3/CARBONAH.md` | inventory pending | inventory pending | inventory pending | queued |
