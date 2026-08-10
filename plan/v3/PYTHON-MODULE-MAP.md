# Python module-to-feature map

This table comes from the shipped `tina4_python` package. It proves that
every Python module has an owning feature packet. A module may support more
than one public capability; that does not turn each private source file into
a feature.

| Python module | Feature IDs | Ownership |
| --- | --- | --- |
| `tina4_python/HtmlElement.py` | 107 | HTML builder |
| `tina4_python/Testing.py` | 132 | inline testing |
| `tina4_python/__init__.py` | 31, 64, 83, 89, 109, 130 | exports, lazy loading and version |
| `tina4_python/ai/__init__.py` | 108 | AI coding-tool setup |
| `tina4_python/api/__init__.py` | 81 | HTTP API client |
| `tina4_python/auth/__init__.py` | 64 | authentication |
| `tina4_python/cache/__init__.py` | 72-80 | cache providers and response cache |
| `tina4_python/cli/__init__.py` | 110-125 | CLI |
| `tina4_python/container/__init__.py` | 105 | dependency injection |
| `tina4_python/context/__init__.py` | 102 | local context index |
| `tina4_python/context/chunker.py` | 102 | local context index |
| `tina4_python/core/__init__.py` | 29-47, 104 | HTTP/application core |
| `tina4_python/core/cache.py` | 25, 72 | ORM/general cache bridge |
| `tina4_python/core/constants.py` | 30 | HTTP response constants |
| `tina4_python/core/events.py` | 104 | event system |
| `tina4_python/core/middleware.py` | 33-37 | middleware and HTTP policies |
| `tina4_python/core/rate_limiter.py` | 35 | rate-limit engine |
| `tina4_python/core/request.py` | 29, 43, 44 | request, IDs and uploads |
| `tina4_python/core/response.py` | 30, 40 | response, compression and ETag |
| `tina4_python/core/router.py` | 31, 32 | routing and groups |
| `tina4_python/core/server.py` | 31, 38-47, 111, 128-129 | front controller and runtime |
| `tina4_python/crud/__init__.py` | 27 | automatic CRUD |
| `tina4_python/database/__init__.py` | 3-16 | database package |
| `tina4_python/database/adapter.py` | 3 | adapter interface |
| `tina4_python/database/connection.py` | 3 | connection lifecycle |
| `tina4_python/database/database_url.py` | 4 | database URL |
| `tina4_python/database/firebird.py` | 12 | Firebird provider |
| `tina4_python/database/mongodb.py` | 14 | MongoDB SQL provider |
| `tina4_python/database/mssql.py` | 11 | MSSQL provider |
| `tina4_python/database/mysql.py` | 10 | MySQL provider |
| `tina4_python/database/odbc.py` | 13 | ODBC provider |
| `tina4_python/database/postgres.py` | 9 | PostgreSQL provider |
| `tina4_python/database/sql_translator.py` | 7 | SQL dialect translation |
| `tina4_python/database/sqlite.py` | 8 | SQLite provider |
| `tina4_python/debug/__init__.py` | 2, 126 | logging and overlay |
| `tina4_python/debug/error_overlay.py` | 2, 126 | logging and overlay |
| `tina4_python/dev_admin/__init__.py` | 121, 127 | metrics and dev admin |
| `tina4_python/dev_admin/metrics.py` | 121, 127 | metrics and dev admin |
| `tina4_python/dev_admin/plan.py` | 121, 127 | metrics and dev admin |
| `tina4_python/dev_admin/project_index.py` | 121, 127 | metrics and dev admin |
| `tina4_python/docs.py` | 103 | live API index |
| `tina4_python/docstore/__init__.py` | 95-97 | document store |
| `tina4_python/dotenv/__init__.py` | 1 | DotEnv |
| `tina4_python/env.py` | 1, 117 | typed environment and CLI environment support |
| `tina4_python/frond/__init__.py` | 48-60 | Frond |
| `tina4_python/frond/compiler.py` | 48-60 | Frond |
| `tina4_python/frond/engine.py` | 48-60 | Frond |
| `tina4_python/frond/parser.py` | 48-60 | Frond |
| `tina4_python/gallery/auth/src/routes/api/gallery_auth.py` | — | example application; not a framework capability |
| `tina4_python/gallery/database/src/routes/api/gallery_db.py` | — | example application; not a framework capability |
| `tina4_python/gallery/error-overlay/src/routes/api/gallery_crash.py` | — | example application; not a framework capability |
| `tina4_python/gallery/orm/src/orm/Product.py` | — | example application; not a framework capability |
| `tina4_python/gallery/orm/src/routes/api/gallery_products.py` | — | example application; not a framework capability |
| `tina4_python/gallery/queue/src/routes/api/gallery_queue.py` | — | example application; not a framework capability |
| `tina4_python/gallery/rest-api/src/routes/api/gallery_hello.py` | — | example application; not a framework capability |
| `tina4_python/gallery/templates/src/routes/gallery_page.py` | — | example application; not a framework capability |
| `tina4_python/graphql/__init__.py` | 82 | GraphQL |
| `tina4_python/i18n/__init__.py` | 87 | localization |
| `tina4_python/mcp/__init__.py` | 101 | MCP |
| `tina4_python/mcp/protocol.py` | 101 | MCP |
| `tina4_python/mcp/tools.py` | 101 | MCP |
| `tina4_python/messenger/__init__.py` | 88 | messenger |
| `tina4_python/migration/__init__.py` | 15, 112 | migrations |
| `tina4_python/migration/runner.py` | 15, 112 | migrations |
| `tina4_python/mqtt/__init__.py` | 94 | MQTT |
| `tina4_python/mqtt/message.py` | 94 | MQTT |
| `tina4_python/orm/__init__.py` | 17-26 | ORM |
| `tina4_python/orm/fields.py` | 17-26 | ORM |
| `tina4_python/orm/model.py` | 17-26 | ORM |
| `tina4_python/query_builder/__init__.py` | 6 | query builder |
| `tina4_python/queue/__init__.py` | 89-93, 118 | queue |
| `tina4_python/queue/amqp_url.py` | 89-93, 118 | queue |
| `tina4_python/queue/job.py` | 89-93, 118 | queue |
| `tina4_python/queue/kafka_backend.py` | 92 | Kafka queue provider |
| `tina4_python/queue/lite_backend.py` | 90 | lite queue provider |
| `tina4_python/queue/mongo_backend.py` | 93 | MongoDB queue provider |
| `tina4_python/queue/rabbitmq_backend.py` | 91 | RabbitMQ queue provider |
| `tina4_python/queue_backends/__init__.py` | 91-93 | queue connectors |
| `tina4_python/queue_backends/kafka_backend.py` | 92 | Kafka wire connector |
| `tina4_python/queue_backends/mongo_backend.py` | 93 | MongoDB wire connector |
| `tina4_python/queue_backends/rabbitmq_backend.py` | 91 | RabbitMQ wire connector |
| `tina4_python/realtime/__init__.py` | 98-100 | realtime collaboration |
| `tina4_python/realtime/models/Attachment.py` | 98 | realtime persistence models |
| `tina4_python/realtime/models/Channel.py` | 98 | realtime persistence models |
| `tina4_python/realtime/models/ChannelMember.py` | 98 | realtime persistence models |
| `tina4_python/realtime/models/Message.py` | 98 | realtime persistence models |
| `tina4_python/realtime/models/Workspace.py` | 98 | realtime persistence models |
| `tina4_python/realtime/models/__init__.py` | 98 | realtime persistence models |
| `tina4_python/realtime/storage.py` | 98-100 | realtime collaboration |
| `tina4_python/seeder/__init__.py` | 28, 113 | seeding |
| `tina4_python/service/__init__.py` | 106 | service runner |
| `tina4_python/session/__init__.py` | 65-71 | sessions |
| `tina4_python/session_handlers/__init__.py` | 67-71 | session providers |
| `tina4_python/session_handlers/memcached_handler.py` | 71 | memcached session provider |
| `tina4_python/session_handlers/mongodb_handler.py` | 69 | MongoDB session provider |
| `tina4_python/session_handlers/redis_handler.py` | 67 | Redis session provider |
| `tina4_python/session_handlers/valkey_handler.py` | 68 | Valkey session provider |
| `tina4_python/swagger/__init__.py` | 45 | Swagger/OpenAPI |
| `tina4_python/test/__init__.py` | 114, 132 | testing API |
| `tina4_python/test_client/__init__.py` | 131 | test client |
| `tina4_python/validator/__init__.py` | 19 | validation |
| `tina4_python/websocket/__init__.py` | 83-85 | WebSocket |
| `tina4_python/websocket/backplane.py` | 84, 85 | WebSocket backplanes |
| `tina4_python/wsdl/__init__.py` | 86 | WSDL/SOAP |

## Deliberate non-features

| Path or artifact | Reason |
| --- | --- |
| `tina4_python/gallery/` | shipped examples; each example exercises catalog features |
| `tina4_python/realtime/models/` | data models owned by Feature 97 |
| `tina4_python/queue_backends/ connector files` | private provider layers owned by Features 90-92 |
| `compiled assets and translations` | artifacts owned by their source feature; not separate capabilities |
| `__pycache__, metadata and CLAUDE.md` | runtime/build residue or project guidance |

## Numbering rule

A capability gets its own number when an engineer can call it, configure
it, select it, replace it or observe it independently. A provider therefore
gets a whole number. A helper gets no number when removing it leaves the
public contract unchanged.

New capabilities append to the catalog. They never reuse a number and never
insert a decimal child below an existing number.
