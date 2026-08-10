# Python module-to-feature map

This table comes from the shipped `tina4_python` package. It proves that
every Python module has an owning feature packet. A module may support more
than one public capability; that does not turn each private source file into
a feature.

| Python module | Feature IDs | Ownership |
| --- | --- | --- |
| `tina4_python/HtmlElement.py` | 106 | HTML builder |
| `tina4_python/Testing.py` | 131 | inline testing |
| `tina4_python/__init__.py` | 30, 63, 82, 88, 108, 129 | exports, lazy loading and version |
| `tina4_python/ai/__init__.py` | 107 | AI coding-tool setup |
| `tina4_python/api/__init__.py` | 80 | HTTP API client |
| `tina4_python/auth/__init__.py` | 63 | authentication |
| `tina4_python/cache/__init__.py` | 71-79 | cache providers and response cache |
| `tina4_python/cli/__init__.py` | 109-124 | CLI |
| `tina4_python/container/__init__.py` | 104 | dependency injection |
| `tina4_python/context/__init__.py` | 101 | local context index |
| `tina4_python/context/chunker.py` | 101 | local context index |
| `tina4_python/core/__init__.py` | 28-46, 103 | HTTP/application core |
| `tina4_python/core/cache.py` | 24, 71 | ORM/general cache bridge |
| `tina4_python/core/constants.py` | 29 | HTTP response constants |
| `tina4_python/core/events.py` | 103 | event system |
| `tina4_python/core/middleware.py` | 32-36 | middleware and HTTP policies |
| `tina4_python/core/rate_limiter.py` | 34 | rate-limit engine |
| `tina4_python/core/request.py` | 28, 42, 43 | request, IDs and uploads |
| `tina4_python/core/response.py` | 29, 39 | response, compression and ETag |
| `tina4_python/core/router.py` | 30, 31 | routing and groups |
| `tina4_python/core/server.py` | 30, 37-46, 110, 127-128 | front controller and runtime |
| `tina4_python/crud/__init__.py` | 26 | automatic CRUD |
| `tina4_python/database/__init__.py` | 3-15 | database package |
| `tina4_python/database/adapter.py` | 3 | adapter interface |
| `tina4_python/database/connection.py` | 3 | connection lifecycle |
| `tina4_python/database/database_url.py` | 4 | database URL |
| `tina4_python/database/firebird.py` | 11 | Firebird provider |
| `tina4_python/database/mongodb.py` | 13 | MongoDB SQL provider |
| `tina4_python/database/mssql.py` | 10 | MSSQL provider |
| `tina4_python/database/mysql.py` | 9 | MySQL provider |
| `tina4_python/database/odbc.py` | 12 | ODBC provider |
| `tina4_python/database/postgres.py` | 8 | PostgreSQL provider |
| `tina4_python/database/sql_translator.py` | 6, 13 | query and MongoDB SQL translation |
| `tina4_python/database/sqlite.py` | 7 | SQLite provider |
| `tina4_python/debug/__init__.py` | 2, 125 | logging and overlay |
| `tina4_python/debug/error_overlay.py` | 2, 125 | logging and overlay |
| `tina4_python/dev_admin/__init__.py` | 120, 126 | metrics and dev admin |
| `tina4_python/dev_admin/metrics.py` | 120, 126 | metrics and dev admin |
| `tina4_python/dev_admin/plan.py` | 120, 126 | metrics and dev admin |
| `tina4_python/dev_admin/project_index.py` | 120, 126 | metrics and dev admin |
| `tina4_python/docs.py` | 102 | live API index |
| `tina4_python/docstore/__init__.py` | 94-96 | document store |
| `tina4_python/dotenv/__init__.py` | 1 | DotEnv |
| `tina4_python/env.py` | 1, 116 | typed environment and CLI environment support |
| `tina4_python/frond/__init__.py` | 47-59 | Frond |
| `tina4_python/frond/compiler.py` | 47-59 | Frond |
| `tina4_python/frond/engine.py` | 47-59 | Frond |
| `tina4_python/frond/parser.py` | 47-59 | Frond |
| `tina4_python/gallery/auth/src/routes/api/gallery_auth.py` | — | example application; not a framework capability |
| `tina4_python/gallery/database/src/routes/api/gallery_db.py` | — | example application; not a framework capability |
| `tina4_python/gallery/error-overlay/src/routes/api/gallery_crash.py` | — | example application; not a framework capability |
| `tina4_python/gallery/orm/src/orm/Product.py` | — | example application; not a framework capability |
| `tina4_python/gallery/orm/src/routes/api/gallery_products.py` | — | example application; not a framework capability |
| `tina4_python/gallery/queue/src/routes/api/gallery_queue.py` | — | example application; not a framework capability |
| `tina4_python/gallery/rest-api/src/routes/api/gallery_hello.py` | — | example application; not a framework capability |
| `tina4_python/gallery/templates/src/routes/gallery_page.py` | — | example application; not a framework capability |
| `tina4_python/graphql/__init__.py` | 81 | GraphQL |
| `tina4_python/i18n/__init__.py` | 86 | localization |
| `tina4_python/mcp/__init__.py` | 100 | MCP |
| `tina4_python/mcp/protocol.py` | 100 | MCP |
| `tina4_python/mcp/tools.py` | 100 | MCP |
| `tina4_python/messenger/__init__.py` | 87 | messenger |
| `tina4_python/migration/__init__.py` | 14, 111 | migrations |
| `tina4_python/migration/runner.py` | 14, 111 | migrations |
| `tina4_python/mqtt/__init__.py` | 93 | MQTT |
| `tina4_python/mqtt/message.py` | 93 | MQTT |
| `tina4_python/orm/__init__.py` | 16-25 | ORM |
| `tina4_python/orm/fields.py` | 16-25 | ORM |
| `tina4_python/orm/model.py` | 16-25 | ORM |
| `tina4_python/query_builder/__init__.py` | 6 | query builder |
| `tina4_python/queue/__init__.py` | 88-92, 117 | queue |
| `tina4_python/queue/amqp_url.py` | 88-92, 117 | queue |
| `tina4_python/queue/job.py` | 88-92, 117 | queue |
| `tina4_python/queue/kafka_backend.py` | 91 | Kafka queue provider |
| `tina4_python/queue/lite_backend.py` | 89 | lite queue provider |
| `tina4_python/queue/mongo_backend.py` | 92 | MongoDB queue provider |
| `tina4_python/queue/rabbitmq_backend.py` | 90 | RabbitMQ queue provider |
| `tina4_python/queue_backends/__init__.py` | 90-92 | queue connectors |
| `tina4_python/queue_backends/kafka_backend.py` | 91 | Kafka wire connector |
| `tina4_python/queue_backends/mongo_backend.py` | 92 | MongoDB wire connector |
| `tina4_python/queue_backends/rabbitmq_backend.py` | 90 | RabbitMQ wire connector |
| `tina4_python/realtime/__init__.py` | 97-99 | realtime collaboration |
| `tina4_python/realtime/models/Attachment.py` | 97 | realtime persistence models |
| `tina4_python/realtime/models/Channel.py` | 97 | realtime persistence models |
| `tina4_python/realtime/models/ChannelMember.py` | 97 | realtime persistence models |
| `tina4_python/realtime/models/Message.py` | 97 | realtime persistence models |
| `tina4_python/realtime/models/Workspace.py` | 97 | realtime persistence models |
| `tina4_python/realtime/models/__init__.py` | 97 | realtime persistence models |
| `tina4_python/realtime/storage.py` | 97-99 | realtime collaboration |
| `tina4_python/seeder/__init__.py` | 27, 112 | seeding |
| `tina4_python/service/__init__.py` | 105 | service runner |
| `tina4_python/session/__init__.py` | 64-70 | sessions |
| `tina4_python/session_handlers/__init__.py` | 66-70 | session providers |
| `tina4_python/session_handlers/memcached_handler.py` | 70 | memcached session provider |
| `tina4_python/session_handlers/mongodb_handler.py` | 68 | MongoDB session provider |
| `tina4_python/session_handlers/redis_handler.py` | 66 | Redis session provider |
| `tina4_python/session_handlers/valkey_handler.py` | 67 | Valkey session provider |
| `tina4_python/swagger/__init__.py` | 44 | Swagger/OpenAPI |
| `tina4_python/test/__init__.py` | 113, 131 | testing API |
| `tina4_python/test_client/__init__.py` | 130 | test client |
| `tina4_python/validator/__init__.py` | 18 | validation |
| `tina4_python/websocket/__init__.py` | 82-84 | WebSocket |
| `tina4_python/websocket/backplane.py` | 83, 84 | WebSocket backplanes |
| `tina4_python/wsdl/__init__.py` | 85 | WSDL/SOAP |

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
