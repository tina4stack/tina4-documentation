# Framework Comparisons

Tina4 is a lightweight toolkit for web development, available in Python, PHP, Ruby, Node.js, JavaScript (frontend), and Delphi (FMX). It prioritizes minimal code, zero boilerplate, and ships with routing, templating, ORM, and more out of the box.

This page compares Tina4 against popular frameworks in each language. The data includes performance benchmarks, feature matrices, code complexity, and honest assessments of trade-offs.

---

## Python

Tina4 Python is ASGI-compliant and async-focused. It targets APIs and full-stack apps with less code than traditional frameworks.

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
| **Hot-Reloading** | Jurigged (code hot-patch) | Uvicorn --reload | External tools | External tools | No | No |
| **GraphQL** | Built-in | No | No | No | No | No |

### Performance Benchmarks (Carbonah v3)

Benchmarks from the [Carbonah benchmark suite](https://github.com/tina4stack/carbonah). Hardware: Apple MacBook Pro (M-series), macOS. Subprocess-isolated, warm page cache, SQLite in-memory, 1,000 iterations per operation, 3 runs averaged. Python 3.13.5, tina4python v3.8.3.

| Framework | Import ms | Size | Routing/1k | Template/1k | JSON/1k |
|---|---|---|---|---|---|
| tina4python | 0.0ms | 11 MB | 26.5ms | 5.5ms | 83.2ms |
| plain | 4.4ms | 1 MB | 24.6ms | 5.2ms | 78.2ms |
| starlette | 0.3ms | 3 MB | 25.4ms | 5.2ms | 79.5ms |
| django | 88.5ms | 35 MB | 25.4ms | 5.1ms | 77.0ms |
| bottle | 32.1ms | 1 MB | 25.1ms | 5.2ms | 80.6ms |
| fastapi | 131.6ms | 13 MB | 26.4ms | 5.3ms | 79.5ms |
| flask | 75.8ms | 5 MB | 26.9ms | 5.5ms | 80.7ms |

**Key finding:** Runtime performance is nearly identical across all Python frameworks -- the framework adds negligible overhead. Cold-start (import) time and install size are where frameworks diverge most. tina4python loads instantly (0.0ms) because its import is deferred; Starlette is similarly lean at 0.3ms. 
To reproduce: clone [Carbonah](https://github.com/tina4stack/carbonah), run `setup.sh`, then the runner in `tests/python-benchmarks/`.

### Out-of-the-Box Features (38 features tested)

Features available without installing any plugins or extensions.

#### Web Server & Routing

| Feature | tina4python | FastAPI | Flask | Django | Starlette | Bottle |
|---|---|---|---|---|---|---|
| Built-in HTTP server | YES | YES* | YES* | YES | YES* | YES* |
| Route decorators | YES | YES | YES | YES | YES | YES |
| Path parameter types | YES | YES | partial | YES | YES | partial |
| WebSocket support | YES | YES | plugin | YES | YES | no |
| Auto CORS handling | YES | plugin | plugin | plugin | plugin | plugin |
| Static file serving | YES | YES | YES | YES | YES | YES |

#### Database & ORM

| Feature | tina4python | FastAPI | Flask | Django | Starlette | Bottle |
|---|---|---|---|---|---|---|
| Built-in DB abstraction | YES | no | no | YES | no | no |
| Built-in ORM | YES | no | no | YES | no | no |
| Built-in migrations | YES | no | no | YES | no | no |
| SQL-first API (raw SQL) | YES | no | no | partial | no | no |
| Multi-engine support | 6 engines | no | no | 4 engines | no | no |
| MongoDB with SQL syntax | YES | no | no | no | no | no |
| RETURNING emulation | YES | no | no | no | no | no |
| Built-in pagination | YES | no | no | YES | no | no |
| Built-in search | YES | no | no | no | no | no |
| CRUD scaffolding | YES | no | no | YES | no | no |

#### Templating & Frontend

| Feature | tina4python | FastAPI | Flask | Django | Starlette | Bottle |
|---|---|---|---|---|---|---|
| Built-in template engine | Twig | Jinja2 | Jinja2 | DTL | Jinja2 | built-in |
| Template inheritance | YES | YES | YES | YES | YES | partial |
| Custom filters/globals | YES | YES | YES | YES | YES | no |
| SCSS auto-compilation | YES | no | no | no | no | no |
| Live-reload / hot-patch | YES | YES | YES* | YES | no | no |
| Frontend JS helper lib | YES | no | no | no | no | no |

#### Auth & Security

| Feature | tina4python | FastAPI | Flask | Django | Starlette | Bottle |
|---|---|---|---|---|---|---|
| JWT auth built-in | YES | no | no | plugin | no | no |
| Session management | YES | no | YES | YES | plugin | plugin |
| Form CSRF tokens | YES | no | plugin | YES | no | no |
| Password hashing | YES | no | plugin | YES | no | no |
| Route-level auth decorators | YES | Depends | plugin | YES | no | no |

#### API & Integration

| Feature | tina4python | FastAPI | Flask | Django | Starlette | Bottle |
|---|---|---|---|---|---|---|
| Swagger/OpenAPI generation | YES | YES | plugin | plugin | no | no |
| Built-in HTTP client (Api) | YES | no | no | no | no | no |
| SOAP/WSDL support | YES | no | no | no | no | no |
| GraphQL (built-in) | YES | no | no | no | no | no |
| Queue system (multi-backend) | YES | no | no | plugin | no | no |
| CSV/JSON export from queries | YES | no | no | no | no | no |

#### Developer Experience

| Feature | tina4python | FastAPI | Flask | Django | Starlette | Bottle |
|---|---|---|---|---|---|---|
| Zero-config startup | YES | partial | partial | no | partial | YES |
| CLI scaffolding | YES | no | no | YES | no | no |
| Inline testing framework | YES | no | no | YES | no | no |
| i18n / localization | YES | no | plugin | YES | no | no |
| Error overlay (dev mode) | YES | YES | YES | YES | no | YES |
| HTML element builder | YES | no | no | no | no | no |

#### Feature Count Summary

| Framework | Built-in Features (out of 38) |
|---|---:|
| tina4_python | 38 (100%) |
| Django | 23 (61%) |
| FastAPI | 11 (29%) |
| Flask | 9 (24%) |
| Starlette | 8 (21%) |
| Bottle | 6 (16%) |

### Complexity — Lines of Code

| Task | tina4python | FastAPI | Flask | Django | Starlette | Bottle |
|---|---|---|---|---|---|---|
| Hello World API | 5 | 5 | 5 | 8+ | 8 | 5 |
| CRUD REST API | 25 | 60+ | 50+ | 80+ | 70+ | 50+ |
| DB + pagination endpoint | 8 | 30+ | 25+ | 15 | 35+ | 30+ |
| Auth-protected route | 3 | 15+ | 10+ | 5 | 20+ | 15+ |
| File upload handler | 8 | 12 | 10 | 15 | 15 | 10 |
| WebSocket endpoint | 10 | 10 | plugin | 15 | 10 | N/A |
| Background queue job | 5 | plugin | plugin | plugin | plugin | plugin |
| Config files needed | 0-1 | 1+ | 1+ | 3+ | 1+ | 0-1 |
| DB setup code | 1 line | 10+ | 10+ | 5+ + manage.py | 10+ | 10+ |

#### Code Examples

**tina4python (8 lines — complete CRUD):**
```python
from tina4_python import Database
db = Database("sqlite3:app.db")
db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")
db.insert("users", {"name": "Alice", "age": 30})
result = db.fetch("SELECT * FROM users WHERE age > ?", [25], limit=10, skip=0)
db.update("users", {"id": 1, "age": 31})
db.delete("users", {"id": 1})
db.close()
```

**FastAPI + SQLAlchemy (35+ lines):**
```python
from fastapi import FastAPI, Depends
from sqlalchemy import create_engine, Column, Integer, String, select
from sqlalchemy.orm import Session, DeclarativeBase, Mapped, mapped_column
from pydantic import BaseModel

engine = create_engine("sqlite:///app.db")
class Base(DeclarativeBase): pass
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    age: Mapped[int] = mapped_column(Integer)
Base.metadata.create_all(engine)
class UserCreate(BaseModel):
    name: str
    age: int

def get_db():
    with Session(engine) as session:
        yield session

app = FastAPI()
@app.get("/users")
def list_users(skip: int = 0, limit: int = 10, db: Session = Depends(get_db)):
    return list(db.execute(select(User).offset(skip).limit(limit)).scalars())
@app.post("/users")
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = User(**user.dict()); db.add(db_user); db.commit()
    return db_user
```

**Django (40+ lines across 4+ files):**
```python
# settings.py
DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": "app.db"}}
INSTALLED_APPS = ["myapp", "django.contrib.contenttypes"]
ROOT_URLCONF = "urls"

# models.py
from django.db import models
class User(models.Model):
    name = models.CharField(max_length=100)
    age = models.IntegerField()

# urls.py
from django.urls import path
urlpatterns = [path("users/", views.list_users), path("users/create/", views.create_user)]

# views.py
from django.http import JsonResponse
def list_users(request):
    skip = int(request.GET.get("skip", 0))
    limit = int(request.GET.get("limit", 10))
    users = list(User.objects.all()[skip:skip+limit].values())
    return JsonResponse(users, safe=False)
def create_user(request):
    data = json.loads(request.body)
    u = User.objects.create(name=data["name"], age=data["age"])
    return JsonResponse({"id": u.id}, status=201)
# + manage.py makemigrations && manage.py migrate
```

### Where Each Framework Excels

**FastAPI** — Strong type hints and Pydantic validation. Auto-generated OpenAPI docs. Mature async ecosystem. Best for high-performance typed APIs and microservices.

**Django** — Admin panel, ORM, migrations, and auth all built-in. The largest Python web community. Best for large enterprise apps, content-heavy sites, and teams needing strong conventions.

**Flask** — Simple, well-documented, huge extension ecosystem. Best for simple apps, learning Python web dev, and maximum third-party choice.

**Tina4 Python** — All 38 tested features ship built-in. Six database engines plus MongoDB with a single API. Built-in GraphQL, SOAP/WSDL, queues, JWT, and SCSS without plugins. Best for rapid development, SQL-first apps, and multi-database projects. The community is small and the framework is newer, so expect to read source code when you get stuck.

### When to Choose What

Choose Tina4 Python when you want working CRUD in a few lines, need multiple database engines with one API, or want GraphQL, REST, and SOAP in the same app without plugins.

Choose FastAPI or Django when you need the largest community and hiring pool, require specific third-party integrations, or prefer Pydantic validation (FastAPI) or Django admin panels.

---

## PHP

Tina4 PHP is a lightweight PHP toolkit for rapid API and web development. It ships with a rich set of built-in features while maintaining a small footprint.

### At a Glance

| Metric | Tina4 PHP | Laravel 12 | Symfony 7 | Slim 4 | CodeIgniter 4 |
|---|---|---|---|---|---|
| **Type** | Lightweight toolkit | Full-stack framework | Modular full-stack | Micro-framework | Lightweight MVC |
| **PHP Version** | 8.1+ | 8.2+ | 8.4+ | 7.4+ | 8.2+ |
| **License** | MIT | MIT | MIT | MIT | MIT |
| **GitHub Stars** | ~20 | ~84,000 | ~31,000 | ~12,200 | ~5,400* |
| **Packagist Installs** | ~8,600 | ~505M | ~86M | ~49M | ~3.6M |
| **StackOverflow Presence** | Emerging | ~200,000+ | ~70,000+ | ~5,000+ | ~70,000+ |
| **Ecosystem Packages** | 24 (official) | 300,000+ (community) | 4,000+ bundles | ~50 add-ons | ~200 (community) |

*CodeIgniter 4 repo has ~5,400 stars; the legacy CI3 repo has ~18,200 stars.*

### Performance Benchmarks (Carbonah v3)

Benchmarks from the [Carbonah benchmark suite](https://github.com/tina4stack/carbonah). Hardware: Apple MacBook Pro (M-series), macOS. Subprocess-isolated, warm page cache, SQLite in-memory, 1,000 iterations per operation, 3 runs averaged. PHP 8.5, tina4php v3.8.3. Note: tina4 PHP v3 uses its own built-in server rather than PHP's built-in dev server.

| Framework | Autoload ms | Size | Routing/1k | Template/1k | JSON/1k |
|---|---|---|---|---|---|
| tina4php | 1.1ms | 4 MB | 6.5ms | 2.9ms | 57.0ms |
| laravel | 15.1ms | 77 MB | 6.5ms | 2.9ms | 54.1ms |
| cakephp | 16.4ms | 0 MB | 6.6ms | 3.0ms | 56.7ms* |
| slim | 0.0ms | 49 MB | 7.0ms | 3.0ms | 56.2ms |
| symfony | 3.7ms | 10 MB | 6.9ms | 3.1ms | 57.3ms |
| plain | 0.0ms | 0 MB | 8.7ms | 5.4ms | 70.7ms |

**Key finding:** tina4php v3 cut autoload time from 11ms to 1.1ms and install size from 11 MB to 4 MB. Runtime performance is nearly identical across all PHP frameworks -- the framework adds negligible overhead. Autoload time and install size are where frameworks diverge most. 
To reproduce: clone [Carbonah](https://github.com/tina4stack/carbonah), run `setup.sh`, then the runner in `tests/php-benchmarks/`.

### Package Size and Dependencies

| Framework | Fresh Install Size (vendor) | Core Dependencies |
|---|---|---|
| **Tina4 PHP** | **4 MB** (v3, measured) | Zero external dependencies in v3 — tina4stack packages only |
| **Laravel 12** | 55.1 MB (measured) | 70+ packages (Symfony components, Monolog, Flysystem, etc.) |
| **Symfony 7** (skeleton) | 7.4 MB (measured) | Modular — depends on selected components |
| **Slim 4** | 691 KB (measured) | PSR-7 implementation + a few interfaces |
| **CodeIgniter 4** | ~25-30 MB | Self-contained with few external deps |

Tina4 PHP is close in size to Slim but ships with a full feature set that approaches Laravel. You do not need to find, evaluate, and wire together third-party packages for common needs.

### Learning Curve

| Scenario | Tina4 PHP | Laravel | Symfony | Slim | CodeIgniter |
|---|---|---|---|---|---|
| **Time to first route** | Minutes | Minutes (after install) | 15-30 min (config) | Minutes | Minutes |
| **Hello World (lines)** | 3 | 3 (route file) | 5-8 (controller+route) | 5-8 (with PSR-7 setup) | 5-8 (controller+route) |
| **Full CRUD API** | 1 line | 50-100+ (model, controller, resource, routes) | 80-150+ (entity, repository, controller, serializer) | 100+ (manual, no ORM) | 60-100+ (model, controller, routes) |
| **Concept overhead** | Minimal — routes, ORM, templates | Service container, facades, providers, middleware, policies | Bundles, services, DI, event dispatcher, voters | PSR-7, PSR-15, DI container | MVC, libraries, helpers |

#### Hello World — tina4php

```php
<?php
require_once "vendor/autoload.php";
\Tina4\Router::get("/hello", function(\Tina4\Request $request, \Tina4\Response $response) {
    return $response("Hello World!");
});
(new \Tina4\App())->run();
```

#### Zero-Config CRUD — tina4php

```php
\Tina4\Crud::route("/api/users", new User());
```

This single line generates a complete REST API with `GET /api/users` (list), `GET /api/users/{id}` (read), `POST /api/users` (create), `PUT /api/users/{id}` (update), and `DELETE /api/users/{id}` (delete) — with automatic OpenAPI/Swagger documentation.

To achieve the same in Laravel, you need a model, a migration, a controller with 5 methods, a form request, an API resource, and route registration. That is 5-7 files and 100+ lines.

### Feature Comparison

| Feature | Tina4 PHP | Laravel 12 | Symfony 7 | Slim 4 | CodeIgniter 4 |
|---|---|---|---|---|---|
| **Routing** | Get/Post/Put/Patch/Delete/Any/Crud | Full (named, grouped, model binding) | Full (annotations, YAML, XML, PHP) | PSR-7/PSR-15 | Full MVC routing |
| **ORM** | Built-in (MySQL, PostgreSQL, SQLite, Firebird, MSSQL, MongoDB, ODBC) | Eloquent (Active Record) | Doctrine (Data Mapper) | None | Query Builder (no full ORM) |
| **Templating** | Twig (built-in) | Blade | Twig | None | Basic PHP views |
| **SCSS Compilation** | Built-in | Via Mix/Vite (external) | Via Webpack Encore (external) | None | None |
| **API Documentation** | Auto-generated OpenAPI/Swagger | Via packages (Scribe, L5-Swagger) | Via packages (NelmioApiDoc) | Via packages | Via packages |
| **WSDL/SOAP** | Built-in | Via ext-soap (manual) | Via ext-soap (manual) | None | None |
| **GraphQL** | Built-in | Via Lighthouse (3rd party) | Via Overblog (3rd party) | Via 3rd party | Via 3rd party |
| **JWT Auth** | Built-in | Via Sanctum/Passport | Via LexikJWT (3rd party) | Via 3rd party | Via 3rd party |
| **Caching** | PhpFastCache (built-in) | Cache facade (Redis, Memcached, file) | Cache component | None | File, Redis, Memcached |
| **Queue System** | Built-in (LiteQueue, MongoDB, RabbitMQ, Kafka) | Built-in (Redis, SQS, DB, Beanstalkd) | Messenger component | None | None |
| **Sessions** | Built-in (DB, Redis, Memcached) | Built-in (file, DB, Redis, Memcached) | Built-in (various) | Via middleware | Built-in (file, DB, Redis) |
| **Database Migrations** | Built-in | Built-in (Artisan) | Doctrine Migrations | None | Built-in (Spark CLI) |
| **CLI Tools** | Built-in | Artisan (extensive) | Console component (extensive) | None | Spark CLI |
| **Testing** | 245 tests, 754 assertions (ecosystem) | PHPUnit + Pest integration | PHPUnit + functional testing | PHPUnit | PHPUnit |
| **Localization/i18n** | Built-in | Built-in | Built-in (Translation) | None | Built-in |
| **Reports** | Built-in | Via packages | Via packages | None | None |
| **Services/Threads** | Built-in | Via queues/jobs | Via Messenger | None | None |
| **Middleware** | Yes | Yes (extensive) | Yes (event listeners, voters) | Yes (PSR-15) | Yes (filters) |
| **WebSocket Support** | Via extensions | Via Reverb/Pusher | Via Mercure | Via Ratchet | None |
| **Admin Panel** | Via Tina4 CMS | Via Nova/Filament (3rd party) | Via EasyAdmin (3rd party) | None | None |

### Where Each Framework Excels

**Laravel** — The largest PHP ecosystem with 300,000+ community packages. Artisan CLI, tinker REPL, and first-party packages for payments, search, broadcasting, and more. The most in-demand PHP framework for hiring. Best for startups, SaaS products, and teams that value convention.

**Symfony** — Promotes SOLID principles and hexagonal architecture. Individual components power Laravel, Drupal, and thousands of other projects. Predictable LTS releases. Best for enterprise applications and teams with senior developers.

**Slim** — The smallest footprint at ~2 MB. No opinions — choose your own ORM, templating, everything. First-class PSR-7 and PSR-15 support. Best for microservices and API gateways.

**CodeIgniter** — Low barrier to entry with familiar MVC patterns. Good performance and clear documentation. Best for small to medium projects and shared hosting environments.

**Tina4 PHP** — One-line CRUD generates a full REST API with Swagger docs. ORM, Twig, SCSS, OpenAPI, WSDL/SOAP, GraphQL, JWT, queues, sessions, reports, and localization all ship built-in. Under 9 MB. Best for rapid API development, enterprise integrations requiring SOAP/GraphQL/REST in one app, and projects that need many features without heavy dependencies.

### Honest Assessment

| Area | Reality |
|---|---|
| **Community size** | Laravel and Symfony have orders of magnitude more community support, tutorials, and StackOverflow answers. If you get stuck with Tina4, you may need to read the source code or ask the maintainers directly. |
| **Job market** | Few job postings list Tina4. Laravel dominates PHP job listings. Choosing Tina4 for a team project means onboarding developers who have not used it before. |
| **Third-party packages** | Laravel's ecosystem of 300,000+ packages means there is a pre-built solution for most needs. Tina4's 24-package ecosystem covers the core well but lacks niche integrations. |
| **Enterprise adoption** | Symfony powers enterprise PHP at banks, governments, and large SaaS companies. Tina4 has not yet built that track record. |
| **Advanced features** | Laravel's queue monitoring (Horizon), full-text search (Scout), billing (Cashier), and admin panels (Nova, Filament) are mature products. Tina4's equivalents are simpler. |
| **Testing ecosystem** | Laravel and Symfony offer extensive testing utilities. Tina4's test suite covers the ecosystem but the testing DX is less polished. |

### When to Choose What

Choose Tina4 PHP when you need a working API in minutes with one-line CRUD and auto-generated Swagger docs, your project requires SOAP/WSDL alongside REST and GraphQL, or you want a full feature set without the bloat.

Choose Laravel or Symfony when you need the largest hiring pool and community, require battle-tested enterprise patterns at scale, or depend on specific third-party integrations from those ecosystems.

---

## Ruby

Tina4 Ruby is a lightweight Ruby web toolkit with built-in ORM, GraphQL, JWT auth, Twig templating, and more — all without external gems.

### At a Glance

| Feature | Tina4 Ruby | Sinatra | Rails | Sequel | Roda |
|---|---|---|---|---|---|
| **Type** | Lightweight toolkit | Micro-framework | Full-stack MVC | Database toolkit | Routing toolkit |
| **Ruby Version** | 3.1+ | 2.6+ | 3.2+ | 2.5+ | 2.5+ |
| **Routing** | DSL, auto-discovery | DSL | Convention + resources | N/A | Plugin-based |
| **Templating** | Built-in Twig | ERB (built-in) | ERB/HAML | None | None |
| **Database/ORM** | Built-in (5 engines) | None | ActiveRecord (3 engines) | Sequel (12+ engines) | None |
| **Auth/Security** | Built-in JWT + bcrypt | None | has_secure_password | None | None |
| **GraphQL** | Built-in | No | No | No | No |

### Performance Benchmarks (Carbonah v3)

Benchmarks from the [Carbonah benchmark suite](https://github.com/tina4stack/carbonah). Hardware: Apple MacBook Pro (M-series), macOS. Subprocess-isolated, warm page cache, SQLite in-memory, 1,000 iterations per operation, 3 runs averaged. Ruby 4.0.1, tina4ruby v3.2.1.

| Framework | Import ms | Size | Routing/1k | Template/1k | JSON/1k |
|---|---|---|---|---|---|
| rails | 166.3ms | 67 MB | 7.3ms | 10.9ms | 42.0ms |
| sinatra | 82.2ms | 3 MB | 7.5ms | 11.6ms | 43.4ms |
| hanami | 37.8ms | 27 MB | 7.6ms | 11.3ms | 42.8ms |
| roda | 26.6ms | 2 MB | 7.6ms | 11.8ms | 44.3ms |
| tina4ruby | 594.2ms | 14 MB | 8.0ms | 11.6ms | 45.1ms |
| plain | 2.8ms | 0 MB | 8.3ms | 12.4ms | 45.3ms |

**Key finding:** Runtime performance is nearly identical across all Ruby frameworks once loaded -- the framework adds negligible overhead. However, tina4ruby's 594ms cold start is significantly higher than competitors and is an area we are actively investigating for improvement. Once past the import phase, tina4ruby's routing and templating performance is competitive with the field. 
To reproduce: clone [Carbonah](https://github.com/tina4stack/carbonah), run `setup.sh`, then the runner in `tests/ruby-benchmarks/`.

### Out-of-the-Box Features (32 features tested)

| Framework | Built-in Features (out of 32) |
|---|---:|
| tina4_ruby | 32 (100%) |
| Rails | 17 (53%) |
| Sequel | 8 (25%) |
| Sinatra | 7 (22%) |
| Roda | 7 (22%) |

tina4_ruby includes everything Rails has — plus GraphQL, SOAP/WSDL, JWT auth, Swagger, queues, SCSS compilation, and REST API client — without any additional gems.

### Complexity — Lines of Code

| Task | tina4ruby | Sinatra | Rails | Sequel | Roda |
|---|---|---|---|---|---|
| Hello World API | 5 | 5 | 8+ | 5 | 5 |
| CRUD REST API | 25 | 40+ | 80+ | 30+ | 30+ |
| DB + pagination endpoint | 8 | 15+ | 15 | 10 | 10 |
| Auth-protected route | 3 | 10+ | 5 | 10+ | 10+ |
| Config files needed | 0-1 | 0-1 | 3+ | 0-1 | 0-1 |
| DB setup code | 1 line | N/A | 5+ | 3 | 3 |

#### Code Examples

**tina4_ruby (8 lines — complete CRUD):**
```ruby
require "tina4"
db = Tina4::Database.new("sqlite3:app.db")
db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")
db.insert("users", { name: "Alice", age: 30 })
result = db.fetch("SELECT * FROM users WHERE age > ?", [25], limit: 10, skip: 0)
db.update("users", { age: 31 }, { id: 1 })
db.delete("users", { id: 1 })
db.close
```

**Sinatra + Sequel (25+ lines):**
```ruby
require "sinatra"
require "sequel"
DB = Sequel.sqlite("app.db")
DB.create_table? :users do
  primary_key :id
  String :name; Integer :age
end
get "/users" do
  DB[:users].limit(params[:limit]&.to_i || 10)
            .offset(params[:skip]&.to_i || 0).all.to_json
end
post "/users" do
  data = JSON.parse(request.body.read)
  id = DB[:users].insert(name: data["name"], age: data["age"])
  { id: id }.to_json
end
```

**Rails (40+ lines across 4+ files):**
```ruby
# models/user.rb
class User < ApplicationRecord; end

# controllers/users_controller.rb
class UsersController < ApplicationController
  def index
    render json: User.limit(params[:limit]).offset(params[:skip])
  end
  def create
    user = User.create!(user_params)
    render json: user, status: :created
  end
  private
  def user_params; params.require(:user).permit(:name, :age); end
end
# + config/database.yml, routes.rb, Gemfile, rails db:migrate
```

### Where Each Framework Excels

**Rails** — Massive ecosystem, strong conventions, and the largest Ruby hiring pool. Admin, ORM, migrations, auth, mailers, and jobs all built-in. Best for large enterprise apps and teams needing conventions.

**Sinatra** — Simple DSL, large community, good documentation. Best for simple apps, microservices, and learning Ruby web dev.

**Sequel** — Supports 12+ database engines with a powerful query DSL. Best for database-heavy apps where you want SQL-level control.

**Tina4 Ruby** — All 32 tested features ship built-in. Fastest single-row operations in benchmarks. Built-in GraphQL, SOAP/WSDL, JWT, queues, Swagger, and SCSS without gems. Cross-platform consistency with Tina4 Python and PHP. Best for rapid development, SQL-first apps, and full-stack apps with minimal config. The community is small. Expect to read source code for edge cases.

### When to Choose What

Choose Tina4 Ruby when you want working CRUD in a few lines, need GraphQL, REST, and SOAP in the same app without gems, or want cross-platform consistency with Tina4 Python and PHP.

Choose Rails when you need the largest hiring pool and community, require specific gems from the Rails ecosystem, or prefer convention-over-configuration at enterprise scale.

---

## Node.js

Tina4 Node.js is the newest member of the Tina4 family. It runs on Node.js 22+ with zero runtime dependencies — the entire framework uses only the Node.js standard library. TypeScript-first. Under 5,000 lines of code.

### At a Glance

| Feature | Tina4 Node.js | Express | Fastify | Hapi | Koa |
|---|---|---|---|---|---|
| **Type** | Full-stack toolkit | Minimal framework | Performance-focused | Configuration-centric | Middleware framework |
| **Node.js Version** | 22+ | 18+ | 18+ | 14+ | 12+ |
| **Language** | TypeScript-first | JavaScript | TypeScript support | JavaScript | JavaScript |
| **Runtime Dependencies** | 0 | 30+ | 14+ | 20+ | 24+ |
| **Routing** | Decorator + file-based | Middleware chain | Schema-based | Configuration | Middleware chain |
| **Templating** | Built-in Frond (Twig-compatible) | None | None | None (use Vision) | None |
| **Database/ORM** | Built-in (5 engines) | None | None | None | None |
| **API Docs** | Auto-Swagger/OpenAPI | None | Via plugin | Via plugin | None |
| **Auth** | Built-in JWT + PBKDF2 | None | None | None | None |
| **WebSockets** | Built-in | Via ws/socket.io | Via plugin | Via nes | None |
| **GraphQL** | Built-in | Via apollo-server | Via mercurius | Via plugin | Via apollo-server |
| **Queues** | Built-in (file-based) | None | None | None | None |
| **Migrations** | Built-in | None | None | None | None |
| **Auto-CRUD** | Yes (from ORM models) | No | No | No | No |

### Performance Benchmarks (Carbonah v3)

Benchmarks from the [Carbonah benchmark suite](https://github.com/tina4stack/carbonah). Hardware: Apple MacBook Pro (M-series), macOS. Subprocess-isolated, warm page cache, SQLite in-memory, 1,000 iterations per operation, 3 runs averaged. Node.js v24.9.0, all v3 builds.

| Framework | Import ms | Size | Routing/1k | Template/1k | JSON/1k |
|---|---|---|---|---|---|
| tina4nodejs | 0.0ms | 1 MB | 3.3ms | 4.2ms | 42.7ms |
| plain | 2.3ms | 0 MB | 4.1ms | 4.2ms | 42.5ms |
| koa | 27.6ms | 2 MB | 3.2ms | 4.3ms | 43.3ms |
| nest | 108.4ms | 22 MB | 3.8ms | 4.3ms | 43.5ms |
| express | 41.3ms | 4 MB | 4.0ms | 5.0ms | 45.7ms |
| hapi | 67.0ms | 2 MB | 3.6ms | 4.5ms | 50.3ms |
| fastify | 56.4ms | 13 MB | 4.0ms | 5.3ms | 53.6ms |

**Key finding:** tina4-nodejs loads in 0.0ms with just 1 MB on disk -- zero runtime dependencies means zero import cost. Runtime performance is nearly identical across all Node.js frameworks -- the framework adds negligible overhead. NestJS v3 has improved substantially (import dropped from 600ms to 108ms). 
To reproduce: clone [Carbonah](https://github.com/tina4stack/carbonah), run `setup.sh`, then the runner in `tests/nodejs-benchmarks/`.

### Feature Comparison

| Feature | Tina4 Node.js | Express | Fastify | Hapi | Koa |
|---|---|---|---|---|---|
| Built-in HTTP server | YES | YES | YES | YES | YES |
| Route decorators | YES | no | no | no | no |
| File-based routing | YES | no | plugin | no | no |
| Built-in ORM | YES (5 engines) | no | no | no | no |
| Built-in migrations | YES | no | no | no | no |
| Auto-CRUD from models | YES | no | no | no | no |
| Template engine | Frond (Twig-compatible) | no | no | no | no |
| JWT auth | YES | no | no | no | no |
| Password hashing (PBKDF2) | YES | no | no | no | no |
| Swagger/OpenAPI | YES | no | plugin | plugin | no |
| WebSocket | YES | no | plugin | plugin | no |
| GraphQL | YES | no | plugin | plugin | no |
| Queue system | YES (file-based) | no | no | no | no |
| Session management | YES | no | plugin | plugin | no |
| CLI tools | YES | no | plugin | no | no |
| Zero runtime deps | YES | no | no | no | no |

### Complexity — Lines of Code

| Task | Tina4 Node.js | Express | Fastify | Hapi | Koa |
|---|---|---|---|---|---|
| Hello World API | 5 | 5 | 5 | 8 | 5 |
| CRUD REST API | 20 | 50+ | 40+ | 60+ | 50+ |
| DB + pagination | 8 | 25+ (with Knex) | 25+ (with Knex) | 25+ | 25+ |
| Auth-protected route | 3 | 15+ (with passport) | 15+ | 10+ | 15+ |
| WebSocket endpoint | 8 | 15+ (with ws) | 10+ (plugin) | 10+ (nes) | 15+ (with ws) |
| Config files needed | 0-1 | 1+ | 1+ | 1+ | 1+ |
| DB setup code | 1 line | N/A | N/A | N/A | N/A |

#### Code Examples

**tina4nodejs — Hello World + CRUD:**
```typescript
import { get, startServer, Database } from "tina4-nodejs";

const db = new Database("sqlite3:app.db");

get("/hello", async (req, res) => {
  return res.json({ message: "Hello World" });
});

get("/users", async (req, res) => {
  const result = await db.fetch("SELECT * FROM users", null, { limit: 10 });
  return res.json(result);
});

startServer({ port: 7148 });
```

**Express + Knex (30+ lines for comparable CRUD):**
```javascript
const express = require("express");
const knex = require("knex")({
  client: "sqlite3",
  connection: { filename: "app.db" }
});
const app = express();
app.use(express.json());

app.get("/users", async (req, res) => {
  const users = await knex("users")
    .limit(req.query.limit || 10)
    .offset(req.query.skip || 0);
  res.json(users);
});
app.post("/users", async (req, res) => {
  const [id] = await knex("users").insert(req.body);
  res.status(201).json({ id });
});
app.put("/users/:id", async (req, res) => {
  await knex("users").where({ id: req.params.id }).update(req.body);
  res.json({ success: true });
});
app.delete("/users/:id", async (req, res) => {
  await knex("users").where({ id: req.params.id }).del();
  res.json({ success: true });
});
app.listen(3000);
```

### Where Each Framework Excels

**Express** — The most widely used Node.js framework. Massive middleware ecosystem. Nearly every Node.js developer has used it. Best for teams that want maximum community support and middleware choice.

**Fastify** — Built for performance with schema-based validation and a plugin architecture. Faster than Express in most benchmarks. Best for high-throughput APIs where every millisecond counts.

**Hapi** — Configuration-driven with strong input validation (Joi). Best for teams that prefer declarative configuration over middleware chains.

**Koa** — Created by the Express team with async/await at its core. Minimal and modern. Best for developers who want a clean middleware API without legacy patterns.

**Tina4 Node.js** — Zero runtime dependencies. The entire framework runs on Node.js standard library. Built-in ORM with 5 database engines, auto-CRUD generation, JWT auth, Swagger, GraphQL, WebSockets, queues, and migrations in under 5,000 lines of code. Same project structure and CLI as Tina4 Python, PHP, and Ruby. Best for developers who want a full-stack toolkit without a dependency tree, or teams already using Tina4 in another language. The framework is new. The community is small. Express and Fastify have years of battle-testing that Tina4 Node.js does not.

### When to Choose What

Choose Tina4 Node.js when you want zero runtime dependencies, need a built-in ORM with multiple database engines, or already use Tina4 in another language and want the same project structure.

Choose Express or Fastify when you need the largest ecosystem and hiring pool, require specific npm middleware, or need a framework with years of production use behind it.

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

Choose Tina4 Delphi when you build native Delphi apps that consume REST APIs and want automatic dataset population, need to render HTML/CSS inside FMX forms, or want MCP integration for AI-assisted development.

Choose raw FMX when you need full control over HTTP communication with no additional dependencies.

Choose TMS Web Core when you want to build browser-based web applications entirely in Object Pascal.

---

## AI-Assisted Development

As AI coding assistants (GitHub Copilot, Claude Code, Cursor) become common, a framework's compatibility with these tools matters. Smaller, more predictable codebases tend to produce better AI-generated code.

### Factors That Help AI

| Factor | Tina4 | Large frameworks (Django, Laravel, Rails) | Micro-frameworks (Flask, Slim, Sinatra) |
|---|---|---|---|
| Ships with CLAUDE.md | Yes | No | No |
| Single-file app possible | Yes | No (Django, Rails) | Yes |
| Predictable file structure | Yes | Yes | No |
| Auto-discovery (routes/models) | Yes | Partial | No |
| Low boilerplate | Yes | No | Partial |
| Self-contained (few deps) | Yes | No | Partial |
| Consistent API patterns | Yes | Yes | Partial |
| Codebase fits in one context window | Yes | No | Yes |

Tina4 ships with CLAUDE.md files that give AI assistants built-in context for every feature. Its convention-over-configuration approach means routes go in `src/routes/`, models in `src/orm/`, templates in `src/templates/`. AI tools can predict file locations and generate correct code with fewer errors.

Large frameworks like Django and Laravel have strong conventions too, but their codebases are 10-100x larger. An AI assistant cannot read and understand the entire framework in a single context window. Micro-frameworks like Flask and Slim are small, but they lack conventions — the AI must guess where files go.

Tina4's SQL-first approach also helps. AI tools write real SQL instead of framework-specific query builder chains that vary between ORMs.

---

## Conclusion

Every framework in these comparisons has earned its place. Django, Laravel, and Rails are industry standards with unmatched communities. FastAPI leads async Python APIs. Express dominates Node.js. Symfony powers enterprise PHP.

Tina4 takes a different approach: ship everything a modern web project needs in the smallest possible package. It trades community size for built-in features, and ceremony for simplicity.

| Language | Tina4 Variant | Key Differentiators |
|---|---|---|
| **Python** | tina4_python | 38/38 features built-in, 6 database engines, GraphQL + SOAP + REST |
| **PHP** | Tina4 PHP | One-line CRUD, 4 MB with full feature set, multi-DB ORM, zero external deps |
| **Ruby** | tina4_ruby | 32/32 features built-in, low DB overhead, GraphQL + SOAP + JWT |
| **Node.js** | Tina4 Node.js | Zero runtime deps, 5 DB engines, auto-CRUD, under 5,000 lines |
| **JavaScript** | tina4js | Sub-3KB reactive framework, signals, Web Components, PWA |
| **Delphi** | Tina4 Delphi | FMX components, auto MemTable, HTML/CSS on canvas, MCP server |

The trade-off is real: Tina4 has a smaller community, fewer third-party packages, and less production history than established frameworks. For developers and teams who value getting things done with minimal code and want the same patterns across multiple languages, Tina4 is worth evaluating.

---

*Data sources: [Packagist](https://packagist.org), [GitHub](https://github.com), [Carbonah benchmark suite](https://github.com/tina4stack/carbonah) (Apple MacBook Pro M-series, macOS, 1,000 iterations, 3 runs averaged, SQLite in-memory), framework documentation sites. tina4js bundle sizes: macOS, Vite + Rollup with esbuild minification. Community statistics retrieved March 2026.*
