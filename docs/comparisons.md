# Framework Comparisons

Tina4 ships in Python, PHP, Ruby, Node.js, JavaScript (frontend), and Delphi (FMX). Each variant targets a different language but follows the same project structure, the same routing conventions, and the same ORM API.

This page compares every Tina4 variant against popular frameworks in its language. The data covers performance benchmarks, a 44-feature matrix, deployment size, and honest trade-offs.

**Methodology.** All benchmarks ran on an Apple Silicon ARM64 MacBook Pro (8 cores). The tool: `hey` — 5,000 requests, 50 concurrency, three runs averaged. Two endpoints tested: a JSON object response and a 100-item list response. Benchmark scripts live at [github.com/tina4stack/tina4-documentation/benchmark/](https://github.com/tina4stack/tina4-documentation/benchmark/). Date: March 2026.

---

## Python

Tina4 Python runs ASGI on uvicorn. Async by default. Zero external dependencies.

### At a Glance

| Feature | Tina4 Python | FastAPI | Flask | Django | Starlette | Bottle |
|---|---|---|---|---|---|---|
| **Type** | Lightweight toolkit | Async API framework | Micro-framework (sync) | Full-stack framework | ASGI toolkit | Micro-framework |
| **Python Version** | 3.12+ | 3.8+ | 3.8+ | 3.10+ | 3.8+ | 3.x |
| **Routing** | Decorator-based, auto-discovery | Decorator + Pydantic | Blueprint-based | URL patterns, CBVs | Decorator-based | Decorator-based |
| **Templating** | Built-in Twig | None (use Jinja2) | Jinja2 | Django templates | None (use Jinja2) | Built-in simple |
| **Database/ORM** | Built-in (6 engines + MongoDB) | None (use SQLAlchemy) | None (use SQLAlchemy) | Built-in ORM (4 engines) | None | None |
| **API Docs** | Auto-Swagger at /swagger | Auto-Swagger/OpenAPI | Plugin required | Plugin required | None | None |
| **Auth/Security** | Built-in JWT, sessions, CSRF | Depends on deps | Extensions required | Built-in auth system | None | None |
| **WebSockets** | Built-in | Built-in | Plugin | Channels (plugin) | Built-in | No |
| **GraphQL** | Built-in | No | No | No | No | No |

### Performance (hey — req/s)

| Framework | JSON | List |
|---|---:|---:|
| Starlette | 15,664 | 9,302 |
| FastAPI | 11,523 | 2,709 |
| **Tina4** | **9,761** | **5,769** |
| Flask | 5,722 | 962 |
| Bottle | 3,165 | 1,105 |
| Django | 2,333 | 2,150 |

Starlette leads raw JSON throughput — it carries no middleware overhead. FastAPI sits on top of Starlette and adds Pydantic validation, which costs ~30% on JSON but drops list throughput to 2,709 req/s. Tina4 lands mid-pack on JSON and holds strong on list responses (5,769), where FastAPI and Flask fall off. Django handles both endpoints at a steady ~2,200 req/s with no dramatic drops. Bottle runs single-threaded, which limits its ceiling.

### Feature Comparison (44 features)

| # | Feature | Tina4 | Django | FastAPI | Flask | Starlette | Bottle |
|---|---|---|---|---|---|---|---|
| | **CORE WEB** | | | | | | |
| 1 | Routing (decorators) | Y | Y | Y | Y | Y | Y |
| 2 | Typed path parameters | Y | Y | Y | - | Y | - |
| 3 | Middleware system | Y | Y | Y | Y | Y | - |
| 4 | Static file serving | Y | Y | Y | Y | Y | Y |
| 5 | CORS built-in | Y | - | - | - | - | - |
| 6 | Rate limiting | Y | - | - | - | - | - |
| 7 | WebSocket | Y | - | Y | - | Y | - |
| | **DATA** | | | | | | |
| 8 | ORM | Y | Y | - | - | - | - |
| 9 | 5 database drivers | Y | Y | - | - | - | - |
| 10 | Migrations | Y | Y | - | - | - | - |
| 11 | Seeder / fake data | Y | - | - | - | - | - |
| 12 | Sessions | Y | Y | Y | - | - | - |
| 13 | Response caching | Y | Y | - | - | - | - |
| 14 | QueryBuilder | Y | Y | - | - | - | - |
| 15 | Input validation | Y | Y | Y | - | - | - |
| | **AUTH** | | | | | | |
| 16 | JWT built-in | Y | - | - | - | - | - |
| 17 | Password hashing | Y | Y | - | - | - | - |
| 18 | CSRF protection | Y | Y | - | - | - | - |
| | **FRONTEND** | | | | | | |
| 19 | Template engine | Y | Y | - | Y | - | Y |
| 20 | CSS framework | Y | - | - | - | - | - |
| 21 | SCSS compiler | Y | - | - | - | - | - |
| 22 | Frontend JS helpers | Y | - | - | - | - | - |
| | **API** | | | | | | |
| 23 | Swagger / OpenAPI | Y | - | Y | - | - | - |
| 24 | GraphQL | Y | - | - | - | - | - |
| 25 | SOAP / WSDL | Y | - | - | - | - | - |
| 26 | HTTP client | Y | - | - | - | - | - |
| 27 | Queue system | Y | - | - | - | - | - |
| 28 | MCP server | Y | - | - | - | - | - |
| | **DEV EXPERIENCE** | | | | | | |
| 29 | CLI scaffolding | Y | Y | - | - | - | - |
| 30 | Dev admin dashboard | Y | Y | - | - | - | - |
| 31 | Error overlay | Y | Y | Y | Y | - | Y |
| 32 | Live reload | Y | Y | Y | Y | - | - |
| 33 | Auto-CRUD generator | Y | Y | - | - | - | - |
| 34 | Gallery / examples | Y | - | - | - | - | - |
| 35 | AI assistant context | Y | - | - | - | - | - |
| 36 | Inline testing | Y | Y | - | - | - | - |
| 37 | TestClient | Y | Y | Y | Y | - | - |
| | **ARCHITECTURE** | | | | | | |
| 38 | Zero dependencies | Y | - | - | - | - | Y |
| 39 | Dependency injection | Y | - | Y | - | - | - |
| 40 | Event system | Y | Y | - | - | - | - |
| 41 | i18n / translations | Y | Y | - | - | - | - |
| 42 | Background services | Y | - | - | - | - | - |
| 43 | .env configuration | Y | - | - | - | - | - |
| 44 | HTML builder | Y | - | - | - | - | - |

### Feature Count

| Framework | Features (of 44) | Pct |
|---|---:|---:|
| **Tina4** | **44** | **100%** |
| Django | 24 | 55% |
| FastAPI | 10 | 23% |
| Flask | 7 | 16% |
| Starlette | 6 | 14% |
| Bottle | 5 | 11% |

### Deployment Size

| Framework | Dependencies | Install Size |
|---|---:|---:|
| Bottle | 0 | 0.3 MB |
| **Tina4** | **0** | **2.4 MB** |
| Starlette | 4 | 3.5 MB |
| Flask | 6 | 4.2 MB |
| FastAPI | 12 | 4.8 MB |
| Django | 20 | 25 MB |

Tina4 ships 44 features in 2.4 MB with zero dependencies. Django delivers 24 features in 25 MB with 20 dependencies. FastAPI ships 10 features in 4.8 MB. The size-to-feature ratio favors Tina4.

---

## PHP

Tina4 PHP runs its own built-in async server using `stream_select`. No Apache, no Nginx, no php-fpm required for development.

### At a Glance

| Feature | Tina4 PHP | Laravel 12 | Symfony 7 | CodeIgniter 4 | Slim 4 |
|---|---|---|---|---|---|
| **Type** | Lightweight toolkit | Full-stack framework | Modular full-stack | Lightweight MVC | Micro-framework |
| **PHP Version** | 8.1+ | 8.2+ | 8.4+ | 8.2+ | 7.4+ |
| **Routing** | Decorator-based | Named, grouped, model binding | Annotations, YAML, PHP | MVC routing | PSR-7/PSR-15 |
| **Templating** | Twig (built-in) | Blade | Twig | PHP views | None |
| **Database/ORM** | Built-in (7 engines) | Eloquent | Doctrine | Query Builder | None |
| **API Docs** | Auto-Swagger | Via packages | Via packages | Via packages | Via packages |
| **Auth/Security** | Built-in JWT, sessions, CSRF | Sanctum/Passport | LexikJWT (3rd party) | Via packages | Via packages |
| **GraphQL** | Built-in | Lighthouse (3rd party) | Overblog (3rd party) | Via packages | Via packages |

### Performance (hey — req/s)

| Framework | JSON | List |
|---|---:|---:|
| **Tina4** | **28,158** | **18,191** |
| Slim | 5,082 | 3,312 |
| Symfony | 1,589 | 1,305 |
| CodeIgniter | 1,311 | 1,288 |
| Laravel | 257 | 313 |

Tina4 PHP dominates. Its built-in async server (`stream_select`) handles requests without the overhead of php-fpm process spawning. It delivers 28,158 JSON req/s — 5.5x faster than Slim and 109x faster than Laravel. The gap narrows under production setups (Nginx + php-fpm + OPcache), but Tina4's zero-config server wins out of the box.

### Feature Comparison (44 features)

| # | Feature | Tina4 | Laravel | Symfony | CodeIgniter | Slim |
|---|---|---|---|---|---|---|
| | **CORE WEB** | | | | | |
| 1 | Routing (decorators) | Y | Y | Y | Y | Y |
| 2 | Typed path parameters | Y | Y | Y | Y | Y |
| 3 | Middleware system | Y | Y | Y | Y | Y |
| 4 | Static file serving | Y | Y | Y | Y | - |
| 5 | CORS built-in | Y | Y | - | - | - |
| 6 | Rate limiting | Y | Y | - | - | - |
| 7 | WebSocket | Y | - | - | - | - |
| | **DATA** | | | | | |
| 8 | ORM | Y | Y | Y | - | - |
| 9 | 5 database drivers | Y | Y | Y | Y | - |
| 10 | Migrations | Y | Y | Y | Y | - |
| 11 | Seeder / fake data | Y | Y | - | - | - |
| 12 | Sessions | Y | Y | Y | Y | - |
| 13 | Response caching | Y | Y | Y | Y | - |
| 14 | QueryBuilder | Y | Y | Y | Y | - |
| 15 | Input validation | Y | Y | Y | Y | - |
| | **AUTH** | | | | | |
| 16 | JWT built-in | Y | Y | - | - | - |
| 17 | Password hashing | Y | Y | Y | Y | - |
| 18 | CSRF protection | Y | Y | Y | Y | - |
| | **FRONTEND** | | | | | |
| 19 | Template engine | Y | Y | Y | Y | - |
| 20 | CSS framework | Y | - | - | - | - |
| 21 | SCSS compiler | Y | - | - | - | - |
| 22 | Frontend JS helpers | Y | - | - | - | - |
| | **API** | | | | | |
| 23 | Swagger / OpenAPI | Y | - | - | - | - |
| 24 | GraphQL | Y | - | - | - | - |
| 25 | SOAP / WSDL | Y | - | - | - | - |
| 26 | HTTP client | Y | Y | Y | - | - |
| 27 | Queue system | Y | Y | Y | - | - |
| 28 | MCP server | Y | - | - | - | - |
| | **DEV EXPERIENCE** | | | | | |
| 29 | CLI scaffolding | Y | Y | Y | Y | - |
| 30 | Dev admin dashboard | Y | - | - | - | - |
| 31 | Error overlay | Y | Y | Y | Y | - |
| 32 | Live reload | Y | Y | - | - | - |
| 33 | Auto-CRUD generator | Y | - | - | - | - |
| 34 | Gallery / examples | Y | - | - | - | - |
| 35 | AI assistant context | Y | - | - | - | - |
| 36 | Inline testing | Y | Y | Y | Y | - |
| 37 | TestClient | Y | Y | Y | - | - |
| | **ARCHITECTURE** | | | | | |
| 38 | Zero dependencies | Y | - | - | - | - |
| 39 | Dependency injection | Y | Y | Y | - | Y |
| 40 | Event system | Y | Y | Y | - | - |
| 41 | i18n / translations | Y | Y | Y | Y | - |
| 42 | Background services | Y | Y | - | - | - |
| 43 | .env configuration | Y | Y | - | - | - |
| 44 | HTML builder | Y | - | - | - | - |

### Feature Count

| Framework | Features (of 44) | Pct |
|---|---:|---:|
| **Tina4** | **44** | **100%** |
| Laravel | 29 | 66% |
| Symfony | 20 | 45% |
| CodeIgniter | 16 | 36% |
| Slim | 6 | 14% |

### Deployment Size

| Framework | Dependencies | Install Size |
|---|---:|---:|
| **Tina4** | **0** | **~1.5 MB** |
| Slim | 2 | ~3 MB |
| CodeIgniter | 15+ | ~12 MB |
| Symfony | 30+ | ~25 MB |
| Laravel | 70+ | ~50 MB |

Tina4 PHP packs 44 features into ~1.5 MB with zero external dependencies. Laravel needs 70+ packages and ~50 MB to reach 29 features. Slim stays small at ~3 MB but ships only 6 features.

---

## Ruby

Tina4 Ruby runs on Puma. Built-in ORM, JWT, GraphQL, Swagger, and SCSS — no gems required.

### At a Glance

| Feature | Tina4 Ruby | Rails | Sinatra | Roda |
|---|---|---|---|---|
| **Type** | Lightweight toolkit | Full-stack MVC | Micro-framework | Routing toolkit |
| **Ruby Version** | 3.1+ | 3.2+ | 2.6+ | 2.5+ |
| **Routing** | DSL, auto-discovery | Convention + resources | DSL | Plugin-based |
| **Templating** | Built-in Twig | ERB/HAML | ERB | None |
| **Database/ORM** | Built-in (5 engines) | ActiveRecord (3 engines) | None | None |
| **Auth/Security** | Built-in JWT + bcrypt | has_secure_password | None | None |
| **GraphQL** | Built-in | No | No | No |

### Performance (hey — req/s, all on Puma)

| Framework | JSON | List |
|---|---:|---:|
| **Tina4** | **17,637** | **11,303** |
| Roda | 8,159 | 6,232 |
| Sinatra | 7,348 | 5,796 |
| Rails | 4,918 | 4,007 |

All four frameworks ran on Puma, making this a fair comparison. Tina4 Ruby leads both endpoints — 17,637 JSON req/s and 11,303 list req/s. It doubles Roda on JSON and triples Sinatra on list throughput. Rails trails at 4,918 JSON req/s, weighed down by its middleware stack.

### Feature Comparison (44 features)

| # | Feature | Tina4 | Rails | Sinatra | Roda |
|---|---|---|---|---|---|
| | **CORE WEB** | | | | |
| 1 | Routing (decorators) | Y | Y | Y | Y |
| 2 | Typed path parameters | Y | Y | - | - |
| 3 | Middleware system | Y | Y | Y | Y |
| 4 | Static file serving | Y | Y | Y | - |
| 5 | CORS built-in | Y | - | - | - |
| 6 | Rate limiting | Y | - | - | - |
| 7 | WebSocket | Y | - | - | - |
| | **DATA** | | | | |
| 8 | ORM | Y | Y | - | - |
| 9 | 5 database drivers | Y | Y | - | - |
| 10 | Migrations | Y | Y | - | - |
| 11 | Seeder / fake data | Y | - | - | - |
| 12 | Sessions | Y | Y | - | - |
| 13 | Response caching | Y | Y | - | - |
| 14 | QueryBuilder | Y | Y | - | - |
| 15 | Input validation | Y | Y | - | - |
| | **AUTH** | | | | |
| 16 | JWT built-in | Y | - | - | - |
| 17 | Password hashing | Y | Y | - | - |
| 18 | CSRF protection | Y | Y | - | - |
| | **FRONTEND** | | | | |
| 19 | Template engine | Y | Y | Y | - |
| 20 | CSS framework | Y | - | - | - |
| 21 | SCSS compiler | Y | - | - | - |
| 22 | Frontend JS helpers | Y | - | - | - |
| | **API** | | | | |
| 23 | Swagger / OpenAPI | Y | - | - | - |
| 24 | GraphQL | Y | - | - | - |
| 25 | SOAP / WSDL | Y | - | - | - |
| 26 | HTTP client | Y | - | - | - |
| 27 | Queue system | Y | Y | - | - |
| 28 | MCP server | Y | - | - | - |
| | **DEV EXPERIENCE** | | | | |
| 29 | CLI scaffolding | Y | Y | - | - |
| 30 | Dev admin dashboard | Y | - | - | - |
| 31 | Error overlay | Y | Y | - | - |
| 32 | Live reload | Y | Y | - | - |
| 33 | Auto-CRUD generator | Y | Y | - | - |
| 34 | Gallery / examples | Y | - | - | - |
| 35 | AI assistant context | Y | - | - | - |
| 36 | Inline testing | Y | Y | - | - |
| 37 | TestClient | Y | Y | - | - |
| | **ARCHITECTURE** | | | | |
| 38 | Zero dependencies | Y | - | - | - |
| 39 | Dependency injection | Y | - | - | - |
| 40 | Event system | Y | Y | - | - |
| 41 | i18n / translations | Y | Y | - | - |
| 42 | Background services | Y | Y | - | - |
| 43 | .env configuration | Y | - | - | - |
| 44 | HTML builder | Y | - | - | - |

### Feature Count

| Framework | Features (of 44) | Pct |
|---|---:|---:|
| **Tina4** | **44** | **100%** |
| Rails | 24 | 55% |
| Sinatra | 4 | 9% |
| Roda | 3 | 7% |

### Deployment Size

| Framework | Dependencies | Install Size |
|---|---:|---:|
| **Tina4** | **0** | **~900 KB** |
| Roda | 1 | ~1 MB |
| Sinatra | 2 | ~5 MB |
| Rails | 40+ | 40+ MB |

Tina4 Ruby fits 44 features into ~900 KB. Rails needs 40+ gems and 40+ MB for 24 features. Roda stays lean at ~1 MB but ships only 3 built-in features.

---

## Node.js

Tina4 Node.js runs on Node.js 22+ with zero runtime dependencies. TypeScript-first. Production mode uses cluster with one worker per CPU core.

### At a Glance

| Feature | Tina4 Node.js | Fastify | Express | Koa | Hapi |
|---|---|---|---|---|---|
| **Type** | Full-stack toolkit | Performance-focused | Minimal framework | Middleware framework | Configuration-centric |
| **Node.js Version** | 22+ | 18+ | 18+ | 12+ | 14+ |
| **Language** | TypeScript-first | TypeScript support | JavaScript | JavaScript | JavaScript |
| **Runtime Dependencies** | 0 | 14+ | 30+ | 24+ | 20+ |
| **Routing** | Decorator + file-based | Schema-based | Middleware chain | Middleware chain | Configuration |
| **Templating** | Built-in Frond (Twig-compatible) | None | None | None | None (use Vision) |
| **Database/ORM** | Built-in (5 engines) | None | None | None | None |
| **API Docs** | Auto-Swagger/OpenAPI | Via plugin | None | None | Via plugin |
| **Auth** | Built-in JWT + PBKDF2 | None | None | None | None |
| **WebSockets** | Built-in | Via plugin | Via ws/socket.io | None | Via nes |
| **GraphQL** | Built-in | Via mercurius | Via apollo-server | Via apollo-server | Via plugin |

### Performance (hey — req/s)

**Production mode (cluster, 8 workers):**

| Framework | JSON | List |
|---|---:|---:|
| Fastify | 55,329 | 33,496 |
| Koa | 52,708 | 29,909 |
| Express | 43,662 | 28,161 |
| Hapi | 42,959 | 15,646 |
| **Tina4** | **34,343** | **50,001** |

**Dev mode (tsx, single process):**

| Framework | JSON | List |
|---|---:|---:|
| Tina4 | 11,872 | 12,347 |

Fastify leads JSON throughput at 55,329 req/s. Tina4 trails on JSON (34,343) but dominates list responses at 50,001 req/s — a 49% lead over the next-best framework (Fastify at 33,496). That list-response strength matters: real APIs return arrays of objects, not single JSON values. All competitors run single-process; Tina4 uses cluster mode with 8 workers. Dev mode (tsx, single process) shows 11,872 JSON req/s — suitable for local development.

### Feature Comparison (44 features)

| # | Feature | Tina4 | Hapi | Fastify | Express | Koa |
|---|---|---|---|---|---|---|
| | **CORE WEB** | | | | | |
| 1 | Routing (decorators) | Y | Y | Y | Y | Y |
| 2 | Typed path parameters | Y | Y | Y | Y | - |
| 3 | Middleware system | Y | Y | Y | Y | Y |
| 4 | Static file serving | Y | Y | - | - | - |
| 5 | CORS built-in | Y | Y | - | - | - |
| 6 | Rate limiting | Y | - | - | - | - |
| 7 | WebSocket | Y | Y | - | - | - |
| | **DATA** | | | | | |
| 8 | ORM | Y | - | - | - | - |
| 9 | 5 database drivers | Y | - | - | - | - |
| 10 | Migrations | Y | - | - | - | - |
| 11 | Seeder / fake data | Y | - | - | - | - |
| 12 | Sessions | Y | Y | - | - | - |
| 13 | Response caching | Y | Y | - | - | - |
| 14 | QueryBuilder | Y | - | - | - | - |
| 15 | Input validation | Y | Y | Y | - | - |
| | **AUTH** | | | | | |
| 16 | JWT built-in | Y | - | - | - | - |
| 17 | Password hashing | Y | - | - | - | - |
| 18 | CSRF protection | Y | - | - | - | - |
| | **FRONTEND** | | | | | |
| 19 | Template engine | Y | - | - | - | - |
| 20 | CSS framework | Y | - | - | - | - |
| 21 | SCSS compiler | Y | - | - | - | - |
| 22 | Frontend JS helpers | Y | - | - | - | - |
| | **API** | | | | | |
| 23 | Swagger / OpenAPI | Y | Y | Y | - | - |
| 24 | GraphQL | Y | - | - | - | - |
| 25 | SOAP / WSDL | Y | - | - | - | - |
| 26 | HTTP client | Y | - | - | - | - |
| 27 | Queue system | Y | - | - | - | - |
| 28 | MCP server | Y | - | - | - | - |
| | **DEV EXPERIENCE** | | | | | |
| 29 | CLI scaffolding | Y | - | - | - | - |
| 30 | Dev admin dashboard | Y | - | - | - | - |
| 31 | Error overlay | Y | Y | Y | - | - |
| 32 | Live reload | Y | - | - | - | - |
| 33 | Auto-CRUD generator | Y | - | - | - | - |
| 34 | Gallery / examples | Y | - | - | - | - |
| 35 | AI assistant context | Y | - | - | - | - |
| 36 | Inline testing | Y | Y | - | Y | - |
| 37 | TestClient | Y | - | - | - | - |
| | **ARCHITECTURE** | | | | | |
| 38 | Zero dependencies | Y | - | - | - | - |
| 39 | Dependency injection | Y | Y | Y | - | Y |
| 40 | Event system | Y | Y | - | - | - |
| 41 | i18n / translations | Y | - | - | - | - |
| 42 | Background services | Y | - | - | - | - |
| 43 | .env configuration | Y | - | - | - | - |
| 44 | HTML builder | Y | - | - | - | - |

### Feature Count

| Framework | Features (of 44) | Pct |
|---|---:|---:|
| **Tina4** | **44** | **100%** |
| Hapi | 14 | 32% |
| Fastify | 7 | 16% |
| Express | 4 | 9% |
| Koa | 3 | 7% |

### Deployment Size

| Framework | Dependencies | Install Size |
|---|---:|---:|
| **Tina4** | **0** | **~1.8 MB** |
| Koa | 2 | ~2 MB |
| Express | 1 | ~2.5 MB |
| Fastify | 1 | ~3 MB |
| Hapi | 1 | ~3.5 MB |

Tina4 Node.js runs on the standard library alone. No `node_modules` tree to audit. Express, Fastify, Koa, and Hapi each pull in transitive dependencies that inflate the install beyond their listed direct dependency count.

---

## Cross-Language Summary

All four Tina4 back-end variants share the same 44-feature set, the same project structure, and the same ORM API.

| | Python | PHP | Ruby | Node.js |
|---|---|---|---|---|
| **JSON req/s** | 9,761 | 28,158 | 17,637 | 34,343 |
| **List req/s** | 5,769 | 18,191 | 11,303 | 50,001 |
| **Features** | 44/44 | 44/44 | 44/44 | 44/44 |
| **Dependencies** | 0 | 0 | 0 | 0 |
| **Install Size** | 2.4 MB | ~1.5 MB | ~900 KB | ~1.8 MB |
| **Server** | uvicorn (ASGI) | stream_select (built-in) | Puma (threaded) | cluster (8 workers) |
| **Language Version** | 3.12+ | 8.1+ | 3.1+ | 22+ |

Node.js leads raw throughput — V8's JIT compiler and cluster mode push list responses to 50,001 req/s. PHP's built-in async server reaches 28,158 JSON req/s without external processes. Ruby on Puma delivers 17,637 JSON req/s. Python on uvicorn sits at 9,761 JSON req/s, constrained by the GIL. All four variants ship zero dependencies and keep install sizes under 2.5 MB.

---

## JavaScript (Frontend)

Tina4 JavaScript (tina4js) is a sub-3KB reactive framework using signals, tagged template literals, and native Web Components. No virtual DOM, no build step required.

### Bundle Size (macOS, Vite + Rollup, gzipped)

| Module | Raw | Gzipped | Budget |
|---|---:|---:|---:|
| **Core** (signals + html + component) | 4,510 B | 1,497 B (1.46 KB) | < 3 KB |
| **Router** | 142 B | 122 B (0.12 KB) | < 2 KB |
| **API** (fetch wrapper) | 2,201 B | 970 B (0.95 KB) | < 1.5 KB |
| **PWA** (service worker + manifest) | 3,039 B | 1,155 B (1.13 KB) | < 2 KB |
| Re-export barrel | 537 B | 256 B (0.25 KB) | < 0.5 KB |

### How Does It Compare?

| Framework | Gzipped Size | Virtual DOM | Components | Reactivity | Router | HTTP Client | PWA | Backend Integration |
|---|---:|---|---|---|---|---|---|---|
| **tina4js** | ~3.7 KB | No | Web Components | Signals | Built-in | Built-in | Built-in | tina4-php/python |
| Preact | ~3 KB | Yes | Custom | Hooks | No | No | No | None |
| Svelte | ~18 KB | No | Custom | Compiler | No | No | No | None |
| Vue | ~33 KB | Yes | Custom | Proxy | No | No | No | None |
| React | ~42 KB | Yes | Custom | Hooks | No | No | No | None |

::: info Apples to oranges
React, Vue, and Svelte sizes are for the core runtime only — they don't include a router, HTTP client, or PWA support. Adding those pushes their real-world size to 50-100+ KB gzipped. tina4js includes all of those in 3.7 KB.
:::

### Performance Characteristics

- **No virtual DOM** — Signals track exactly which DOM nodes need updating
- **Surgical DOM updates** — Only the exact text nodes/attributes that changed are touched
- **No reconciliation overhead** — A list of 1,000 items does not re-diff when one changes
- **Tree-shakeable** — Import only what you need; unused modules are stripped at build time
- **Works without a build step** — ESM imports work directly in browsers

### 231 Tests Passing

The tina4js test suite covers signals, HTML templates, components, routing, fetch API, PWA, WebSocket, integration, and edge cases.

---

## Delphi (FMX)

Tina4 Delphi is not a web framework. It is a design-time FMX component library that adds REST client capabilities, HTML/CSS rendering, and template support to native Delphi applications.

### At a Glance

| Feature | Tina4 Delphi | Raw FMX (TRESTClient) | TMS Web Core |
|---|---|---|---|
| **Type** | FMX component library | Built-in REST classes | Web app framework |
| **Target** | Native desktop/mobile apps | Native desktop/mobile apps | Browser-based apps |
| **Approach** | Design-time components | Manual code | Visual designer + Pas2JS |
| **REST Client** | TTina4REST (auto MemTable population) | TRESTClient + TRESTRequest + TRESTResponse | TWebHttpRequest |
| **HTML Rendering** | TTina4HTMLRender (CSS on FMX canvas) | Not available | Full browser rendering |
| **Template Engine** | TTina4Twig | Not available | Not available |
| **WebSocket** | TTina4WebSocketClient | Manual implementation | TWebSocketClient |
| **JSON Handling** | TTina4JSONAdapter (auto-mapping) | Manual TJSONObject parsing | Automatic via JS interop |
| **MCP Server** | Built-in (Claude Code integration) | Not available | Not available |
| **License** | Open source | Included with Delphi | Commercial |

### Components

| Component | Purpose |
|---|---|
| **TTina4REST** | REST client with auto MemTable population |
| **TTina4RESTRequest** | Individual request configuration |
| **TTina4JSONAdapter** | Maps JSON responses to Delphi datasets |
| **TTina4HTMLRender** | Renders HTML/CSS on the FMX canvas with native form controls |
| **TTina4HTMLPages** | Multi-page HTML container |
| **TTina4Twig** | Twig template engine for generating HTML |
| **TTina4WebSocketClient** | WebSocket client for real-time communication |

### Code Example: REST Client

**Tina4 Delphi (design-time + minimal code):**
```pascal
// Drop TTina4REST and TTina4JSONAdapter on form
// Set properties in Object Inspector:
//   Tina4REST1.BaseURL := 'https://api.example.com';
//   Tina4JSONAdapter1.REST := Tina4REST1;

// Fetch data and populate a grid
procedure TForm1.Button1Click(Sender: TObject);
begin
  Tina4REST1.Get('/users');
  // TTina4JSONAdapter auto-populates a TFDMemTable
  // Bind the MemTable to a TGrid and the data appears
end;
```

**Raw FMX (manual wiring):**
```pascal
procedure TForm1.Button1Click(Sender: TObject);
var
  Client: TRESTClient;
  Request: TRESTRequest;
  Response: TRESTResponse;
  JSONArray: TJSONArray;
  I: Integer;
begin
  Client := TRESTClient.Create('https://api.example.com');
  Response := TRESTResponse.Create(nil);
  Request := TRESTRequest.Create(nil);
  try
    Request.Client := Client;
    Request.Response := Response;
    Request.Resource := '/users';
    Request.Execute;
    // Manual JSON parsing
    JSONArray := Response.JSONValue as TJSONArray;
    for I := 0 to JSONArray.Count - 1 do
    begin
      // Manually extract each field and populate UI
    end;
  finally
    Request.Free;
    Response.Free;
    Client.Free;
  end;
end;
```

### Feature Comparison

| Capability | Tina4 Delphi | Raw FMX | TMS Web Core |
|---|---|---|---|
| REST calls | Design-time component | Manual code (3 objects) | TWebHttpRequest |
| JSON to dataset | Automatic (TTina4JSONAdapter) | Manual parsing | Automatic via JS |
| HTML/CSS in native app | TTina4HTMLRender on canvas | Not possible | Full browser (Chromium) |
| Template generation | Twig templates | Not available | Not available |
| WebSocket | Drop-in component | Manual implementation | Component available |
| MCP / AI integration | Built-in MCP server | Not available | Not available |
| Learning curve | Low (design-time) | Medium (manual wiring) | Medium (Pas2JS) |
| Cost | Free | Included with Delphi | Commercial license |

### Where Each Approach Excels

**Raw FMX (TRESTClient)** — Ships with Delphi, no additional dependencies. Full control over every HTTP header and response. Best when you need precise control over REST communication and do not mind manual JSON parsing.

**TMS Web Core** — Generates full browser-based web applications from Delphi code using Pas2JS. Visual designer. Best for teams that want to build web UIs in Delphi/Object Pascal instead of JavaScript.

**Tina4 Delphi** — Reduces REST client boilerplate with auto MemTable population. Renders HTML/CSS inside native FMX forms. Twig templates for generating dynamic content. Built-in MCP server for Claude Code integration. Best for native Delphi apps that consume REST APIs, need to display HTML content on the FMX canvas, or want AI-assisted development with Claude Code.

### When to Choose What

Choose Tina4 Delphi when you build native Delphi apps. It populates datasets from REST APIs, renders HTML/CSS inside FMX forms, and offers MCP integration for AI-assisted development.

Choose raw FMX when you need full control over HTTP communication with no additional dependencies.

Choose TMS Web Core when you want to build browser-based web applications entirely in Object Pascal.

---

## AI-Assisted Development

AI coding assistants work better when they understand a project's structure, conventions, and API surface. Tina4 ships context files for seven AI tools — more than any other framework.

### AI Context Files

| File | Tool | Purpose |
|---|---|---|
| `CLAUDE.md` | Claude Code | Project structure, conventions, API reference |
| `.cursorrules` | Cursor | Editor-specific rules and code generation hints |
| `copilot-instructions.md` | GitHub Copilot | Completion guidance and framework patterns |
| `llms.txt` | Web-crawling AI tools | Machine-readable project summary at tina4.com/llms.txt |
| `CONVENTIONS.md` | General AI tools | Coding standards and naming conventions |
| `.clinerules` | Cline | Autonomous agent rules and project context |
| `AGENTS.md` | Multi-agent systems | Agent coordination and task delegation context |

### Why This Matters

| Factor | Tina4 | Large frameworks (Django, Laravel, Rails) | Micro-frameworks (Flask, Slim, Sinatra) |
|---|---|---|---|
| Ships AI context files | 7 tools | 0 | 0 |
| Single-file app possible | Yes | No (Django, Rails) | Yes |
| Predictable file structure | Yes | Yes | No |
| Auto-discovery (routes/models) | Yes | Partial | No |
| Low boilerplate | Yes | No | Partial |
| Self-contained (few deps) | Yes | No | Partial |
| Codebase fits in one context window | Yes | No | Yes |

Tina4's entire codebase fits inside a single AI context window. Large frameworks like Django (250K+ lines) and Laravel (400K+ lines) overflow that window. The AI sees fragments, not the whole picture. Micro-frameworks like Flask and Slim fit in the window but lack conventions — the AI guesses where files belong.

Tina4's convention-over-configuration approach means routes go in `src/routes/`, models in `src/orm/`, templates in `src/templates/`. AI tools predict file locations and generate correct code with fewer hallucinations. The SQL-first ORM helps too — AI writes real SQL instead of framework-specific query builder chains that vary between ORMs.

---

## Conclusion

Every framework in these comparisons earned its place. Django, Laravel, and Rails set industry standards with unmatched communities. FastAPI leads async Python APIs. Express dominates Node.js middleware. Symfony powers enterprise PHP.

Tina4 takes a different path: ship everything a modern web project needs in the smallest package possible.

| Language | Tina4 Variant | JSON req/s | List req/s | Features | Size |
|---|---|---:|---:|---:|---:|
| **Python** | tina4_python | 9,761 | 5,769 | 44/44 | 2.4 MB |
| **PHP** | Tina4 PHP | 28,158 | 18,191 | 44/44 | ~1.5 MB |
| **Ruby** | tina4_ruby | 17,637 | 11,303 | 44/44 | ~900 KB |
| **Node.js** | Tina4 Node.js | 34,343 | 50,001 | 44/44 | ~1.8 MB |
| **JavaScript** | tina4js | — | — | Sub-3KB | 3.7 KB gz |
| **Delphi** | Tina4 Delphi | — | — | FMX components | Open source |

The trade-off is real. Tina4 has a smaller community, fewer third-party packages, and less production history than established frameworks. No StackOverflow tag with 200,000 questions. No registry of 300,000 community packages. When you hit an edge case, you read source code — not a blog post.

For developers who want working CRUD in a few lines, the same patterns across four languages, 44 features with zero dependencies, and AI context files for seven tools — Tina4 is worth evaluating. Build something. Break something. File an issue. The framework grows with its users.

---

*Data sources: [GitHub](https://github.com), framework documentation sites, [hey](https://github.com/rakyll/hey) benchmarks (Apple Silicon ARM64, 8 cores, 5,000 requests, 50 concurrent, 3 runs averaged). tina4js bundle sizes: macOS, Vite + Rollup with esbuild minification. Statistics retrieved March 2026.*
