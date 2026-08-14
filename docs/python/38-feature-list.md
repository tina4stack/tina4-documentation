# Feature Catalog

Tina4 3.14 has **135 numbered catalog entries**. The number describes the framework family's implementation and audit inventory. It does not mean that 135 features have reached four-language parity, and it does not mean that every entry lives inside each backend package.

This chapter is the map. The earlier chapters explain the public APIs available to Python applications. The numbered audit packets define the parity work and the clean-room formula for another language.

## Read the status correctly

A feature moves through four distinct states:

1. **Catalogued** means the feature has a stable number, name, owner, and audit packet.
2. **Shipped** means code exists in one or more released components.
3. **Audited** means the team has measured all relevant implementations and recorded contradictions and decisions.
4. **Contract-proven** means a shared fixture passes in every applicable implementation with real dependencies.

Do not collapse those states into one green tick. At version 3.13.101, the contract ledger reports **55 fixtures and 282 proven invariants, with 0 owed and 0 broken inside those fixture-covered contracts**. That result proves the named contracts. It does not certify the remaining catalog entries.

## Where the features live

| Range | Owner | Meaning |
|---|---|---|
| 1-109, 126-132, 135 | Backend frameworks | Runtime, developer, testing, and application-facing capabilities. Availability and maturity still require per-feature evidence. |
| 110-125 and 134 | Shared Rust CLI | One language-neutral client used with all four backends. These are not four separate backend implementations. |
| 133 | Verification contract | Carbonah benchmark and report shape, not an application runtime API. |
| Provider entries | Selected integration | Each selectable provider has its own number because another language must implement and test it separately. Providers can require an external service, driver, language extension, or extra package. |

Feature 63 includes browser helpers and the separate tina4-js frontend package. The backend books explain their integration, but tina4-js is not embedded four times.

## Current parity boundary

| Evidence | Python | PHP | Ruby | Node.js |
|---|---:|---:|---:|---:|
| Catalog membership | Inventory source | Audit in progress | Audit in progress | Audit in progress |
| Fixture-covered contracts | Proven | Proven | Proven | Proven |
| Entire 135-entry catalog | Not yet proven | Not yet proven | Not yet proven | Not yet proven |

The initial catalog followed the Python module inventory, but Python is not a permanent master. Tina4 promotes the best implementation after audit and captures that decision in an ADR and shared fixture.

Known missing feature surfaces remain tracked in [PHP issue 185](https://github.com/tina4stack/tina4-php/issues/185) and [Node.js issue 37](https://github.com/tina4stack/tina4-nodejs/issues/37). An empty issue list in another repository is not parity evidence. The fixture ledger is the evidence.

## Dependency boundary

The Python package declares no required third-party dependencies. Database, cache, queue, MongoDB, and S3 integrations use optional extras when selected.

"Core dependency" and "provider dependency" are different facts. A local SQLite application can stay small while PostgreSQL, RabbitMQ, Kafka, Redis, MongoDB, S3, or hosted AI still requires the driver or service that speaks that protocol.

## Numbered catalog

## Foundation

| # | Catalog entry |
|---:|---|
| 1 | DotEnv and typed environment |
| 2 | Structured logger |

## Database and providers

| # | Catalog entry |
|---:|---|
| 3 | Database adapter interface |
| 4 | Database URL parser |
| 5 | Database facade and safe writes |
| 6 | Query builder |
| 7 | SQL translator |
| 8 | SQLite provider |
| 9 | PostgreSQL provider |
| 10 | MySQL provider |
| 11 | MSSQL provider |
| 12 | Firebird provider |
| 13 | ODBC provider |
| 14 | MongoDB SQL-translation provider |
| 15 | Migrations |
| 16 | Race-safe database sequences |

## ORM and data layer

| # | Catalog entry |
|---:|---|
| 17 | ORM base class |
| 18 | ORM fields and column mapping |
| 19 | Input and request validation |
| 20 | Soft delete |
| 21 | Declarative ORM relationships |
| 22 | Imperative ORM relationships |
| 23 | ORM scopes |
| 24 | Paginated database and ORM results |
| 25 | ORM result caching |
| 26 | ORM instance loading |
| 27 | Automatic CRUD from models |
| 28 | Seeder and fake data |

## HTTP core

| # | Catalog entry |
|---:|---|
| 29 | HTTP request model |
| 30 | HTTP response model and representation types |
| 31 | Router and dispatch |
| 32 | Route groups |
| 33 | Middleware pipeline |

## HTTP policies

| # | Catalog entry |
|---:|---|
| 34 | CORS middleware |
| 35 | Rate limiting |
| 36 | Security headers middleware |
| 37 | CSRF protection |

## HTTP runtime

| # | Catalog entry |
|---:|---|
| 38 | Health and readiness endpoints |
| 39 | Graceful shutdown |
| 40 | HTTP compression and ETag |
| 41 | Static assets and cache revalidation |
| 42 | Configurable error pages |
| 43 | Request ID tracking |
| 44 | File upload contract |
| 45 | Swagger and OpenAPI |
| 46 | Default landing page |
| 47 | In-process background tasks |

## Frond template engine

| # | Catalog entry |
|---:|---|
| 48 | Frond lexer |
| 49 | Frond parser |
| 50 | Frond compiler |
| 51 | Frond runtime |
| 52 | Frond filters |
| 53 | Frond tags |
| 54 | Frond expression tests |
| 55 | Frond functions |
| 56 | Frond extensibility API |
| 57 | Frond auto-escaping |
| 58 | Frond sandboxing |
| 59 | Frond template caching |
| 60 | Frond fragment caching |

## Frontend assets

| # | Catalog entry |
|---:|---|
| 61 | SCSS compiler |
| 62 | Tina4 CSS |
| 63 | Frond and Tina4 browser helpers |

## Authentication

| # | Catalog entry |
|---:|---|
| 64 | JWT and request authentication |

## Sessions and providers

| # | Catalog entry |
|---:|---|
| 65 | Session lifecycle |
| 66 | File session provider |
| 67 | Redis session provider |
| 68 | Valkey session provider |
| 69 | MongoDB session provider |
| 70 | Database session provider |
| 71 | Memcached session provider |

## Cache and providers

| # | Catalog entry |
|---:|---|
| 72 | Cache interface and provider selection |
| 73 | Memory cache provider |
| 74 | File cache provider |
| 75 | Redis cache provider |
| 76 | Valkey cache provider |
| 77 | Memcached cache provider |
| 78 | MongoDB cache provider |
| 79 | Database cache provider |
| 80 | HTTP response cache |

## Integrations and storage

| # | Catalog entry |
|---:|---|
| 81 | Standard-library HTTP API client |
| 82 | GraphQL |
| 83 | WebSocket protocol and server |
| 84 | Redis WebSocket backplane |
| 85 | NATS WebSocket backplane |
| 86 | WSDL and SOAP |
| 87 | Localization and i18n |
| 88 | Email and messenger |
| 89 | Queue lifecycle |
| 90 | Lite queue provider |
| 91 | RabbitMQ queue provider |
| 92 | Kafka queue provider |
| 93 | MongoDB queue provider |
| 94 | MQTT client |
| 95 | Document store interface |
| 96 | SQLite document store provider |
| 97 | MongoDB document store provider |
| 98 | Realtime collaboration |
| 99 | Local realtime attachment storage |
| 100 | S3 realtime attachment storage |
| 101 | Model Context Protocol server |
| 102 | Local source and documentation context index |
| 103 | Live framework and application API index |
| 135 | App-facing LLM client |

## Application runtime

| # | Catalog entry |
|---:|---|
| 104 | Event and listener system |
| 105 | Dependency injection container |
| 106 | Service runner |
| 107 | HTML element builder |
| 108 | AI coding-tool integration |
| 109 | Lazy feature loading and preload manifest |

## CLI

| # | Catalog entry |
|---:|---|
| 110 | CLI project initialization |
| 111 | CLI development server |
| 112 | CLI migrations |
| 113 | CLI seeding |
| 114 | CLI test runner |
| 115 | CLI route inspection |
| 116 | CLI interactive console |
| 117 | CLI environment management |
| 118 | CLI queue management |
| 119 | CLI container build |
| 120 | CLI code generation |
| 121 | CLI code metrics |
| 122 | CLI command discovery and help |
| 123 | CLI doctor |
| 124 | CLI guided setup |
| 125 | CLI deployment |
| 134 | CLI AI-skills installation and refresh |

## Developer runtime

| # | Catalog entry |
|---:|---|
| 126 | Development error overlay |
| 127 | Development admin dashboard |
| 128 | Dual development and test ports |
| 129 | Development port takeover |
| 130 | Dynamic framework version |

## Testing and verification tools

| # | Catalog entry |
|---:|---|
| 131 | In-process HTTP test client |
| 132 | Inline testing API |
| 133 | Carbonah benchmark contract |

## What parity means

Parity applies to observable contracts: response shapes, status codes, environment keys, error messages, file formats, and security rules. Host-language code remains idiomatic. A Python method can use snake_case while PHP and Node.js use camelCase, but all three must return the same public data.

The catalog gives another language a checklist. The audit packet supplies the decisions. The fixture supplies the proof. A name alone proves nothing; a green contract earns the claim.
