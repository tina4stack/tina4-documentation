# Data, ORM & Database (Ruby)

## GIS and PostGIS

Use `PointField` for geographic points. Coordinates are always `[longitude, latitude]`, while
radius and returned distance use metres.

```ruby
site.location = Tina4::Point.new(18.4241, -33.9249)
site.save

nearby = ChargePoint.query
  .within_distance("location", [18.42, -33.92], 5_000)
  .select_distance("location", [18.42, -33.92])
  .order_by_distance("location", [18.42, -33.92])
  .get
```

PostGIS stores a `PointField` as `geography(Point,4326)` and creates a GiST index. Unsupported
engines fail instead of storing fake spatial text. `Tina4::Point.parse` accepts coordinate pairs,
WKT/EWKT, GeoJSON, or WKB/EWKB; `to_feature` returns map-ready GeoJSON.

## Defining Models

Drop a model file in `src/orm/` and it's auto-registered. A model is a class that inherits
`Tina4::ORM` and **declares its columns with field-type class methods**.

```ruby
# src/orm/user.rb
class User < Tina4::ORM
  table_name "users"                                   # method call — NOT self.table_name =

  integer_field :id, primary_key: true, auto_increment: true   # primary key via a field option
  string_field  :name
  string_field  :email
  text_field    :bio
  boolean_field :is_active, default: true
  integer_field :age, nullable: true
end
```

**Three things that are commonly gotten wrong — get them right:**

1. **`table_name "users"` is a class-method call, not an assignment.** `self.table_name = "users"`
   does not work. Calling `table_name` with no argument returns the current name (defaults to the
   lowercased class name). Set `TINA4_ORM_PLURAL_TABLE_NAMES=true` to auto-append `s`.

2. **The primary key is declared with `primary_key: true` on a field — there is no
   `self.primary_key = "id"`.** Write `integer_field :id, primary_key: true, auto_increment: true`.
   The framework reads the primary key from the field that carries `primary_key: true`.

3. **`attr_accessor :id, :name` registers NO database fields.** A bare `attr_accessor` gives you a
   getter/setter but the ORM's `field_definitions` stays empty, so `save`, `validate`, `to_h`,
   `create_table`, and querying all see zero columns. **Always use the field-type declarations**
   (`integer_field`, `string_field`, `boolean_field`, …) — they register the column AND define the
   accessor for you.

### Available field types

`integer_field`, `string_field` (`length:` default 255), `text_field`, `float_field`,
`decimal_field` (`precision:`, `scale:`), `numeric_field`, `boolean_field`, `date_field`,
`datetime_field`, `timestamp_field`, `blob_field`, `json_field`, and `foreign_key_field`
(`references:`, `related_name:`). Common options: `primary_key:`, `auto_increment:`, `nullable:`,
`default:` (a Proc default like `default: -> { Time.now }` is evaluated per row).

## CRUD Operations

> **Query methods are CLASS methods — call them on the class, never on an instance.**
> `User.find_by_id(1)`, `User.all`, `User.find(...)`, `User.where(...)`, `User.create(...)`.
> `User.new.find_by_id(1)` is wrong — `find_by_id` is not an instance method.

### Create

```ruby
# Build then save (save returns self on success, false on failure)
user = User.new(name: "Alice", email: "alice@example.com")
user.save

# Or the static factory (returns the saved instance, or false on failure)
user = User.create({ name: "Alice", email: "alice@example.com" })

# From a request body (a Hash with String keys) — both work
user = User.create(request.body)
```

On failure, `save` returns `false` (never raises) and records the cause: recover it with
`user.get_error` / `user.last_error` and inspect `user.errors`.

### Read — by primary key

```ruby
user = User.find_by_id(1)      # returns an instance or nil
user = User.find(1)            # find(id) also does a primary-key lookup
user = User.find_or_fail(1)    # raises if not found
```

### Read — filtered

```ruby
# find(filter_hash) or keyword args — equality match on each key
users = User.find(is_active: true)
users = User.find({ "email" => "alice@example.com" })

# where(sql_condition, params) — returns an Array of model instances
active = User.where("is_active = ?", [1])

# A single record: where(...).first   ← the idiomatic "find one by condition"
user  = User.where("email = ?", ["alice@example.com"]).first

# all(...) — every record, with optional pagination / ordering
everyone = User.all(limit: 50, offset: 0, order_by: "name ASC")

# select(full_sql, params) — run a full SELECT, get model instances back
recent = User.select("SELECT * FROM users WHERE created_at > ?", ["2026-01-01"])
```

> **`find_one` DOES NOT EXIST.** The single-row method is **`select_one`**, and it takes a **FULL SQL
> statement** (not just a WHERE fragment): `User.select_one("SELECT * FROM users WHERE email = ?",
> ["a@b.c"])`. In practice, **prefer `User.where("email = ?", [...]).first`** — it's shorter and you
> don't hand-write the SELECT. Never call `User.select_one("email = ?", ...)` with a bare condition;
> that is not valid SQL.

### Update

```ruby
user = User.find_by_id(1)
user.name = "Alice Smith"
user.save
```

### Delete

```ruby
user = User.find_by_id(1)
user.delete          # hard delete (or soft delete if soft_delete is enabled)
```

`delete` raises if the instance has no primary-key value (deleting a keyless record is a programmer
error, not a quiet no-op).

### Existence

```ruby
User.exists(1)                                  # true if a row with PK 1 exists (class method, takes a PK)
User.where("email = ?", [email]).any?           # any matching row? (Array#any?)
```

## Serialisation

```ruby
user.to_h        # { id: 1, name: "Alice", ... }  (aliases: to_hash, to_dict, to_object)
user.to_h(case: "camel")   # { id: 1, firstName: "Alice", ... }
user.to_json     # '{"id":1,"name":"Alice",...}'
user.to_array    # [1, "Alice", ...]

# Serialise a collection for a JSON response:
User.all.map(&:to_h)
# ...or just hand the Array of models to response.json — it converts each one:
response.json(User.all)
```

## Relationships

Declare relationships as class methods; access them as instance methods. `foreign_key_field`
auto-wires both sides.

```ruby
class Post < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field  :title
  foreign_key_field :user_id, references: "User"   # wires post.user + user.posts
end

class User < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field  :name
  has_many :posts, class_name: "Post", foreign_key: "user_id"   # explicit form (optional here)
end

user   = User.find_by_id(1)
posts  = user.posts        # Array of this user's posts
post   = Post.find_by_id(1)
author = post.user         # the post's author (belongs_to)
```

`has_one`, `has_many`, and `belongs_to` are all available. Prevent N+1 with eager loading:
`User.all(include: ["posts"])` or `User.find(1, include: ["posts"])`.

## Soft Delete

```ruby
class Article < Tina4::ORM
  self.soft_delete = true        # uses the is_deleted column (INTEGER 0/1)
  integer_field :id, primary_key: true, auto_increment: true
  string_field  :title
  integer_field :is_deleted, default: 0    # REQUIRED — you must declare it yourself
end

article = Article.find_by_id(1)
article.delete          # sets is_deleted = 1 (soft)
article.restore         # sets is_deleted = 0
article.force_delete    # actually removes the row

Article.all                                   # excludes soft-deleted by default
Article.with_trashed("1=1", [], limit: 100)   # includes soft-deleted
```

> **You MUST declare `is_deleted` yourself.** `create_table` builds the table from your
> declared fields only — it does **not** inject an `is_deleted` column when `soft_delete = true`
> (`lib/tina4/orm.rb:380`). Omit the field and the column never exists, so `delete` (writes
> `is_deleted = 1`) and `all` / `find` / `where` (append `is_deleted IS NULL OR is_deleted = 0`)
> all fail with `no such column: is_deleted`. The soft-delete column name is `:is_deleted` by
> default; override it with `self.soft_delete_field = :archived_at` (declare that field instead).

## Pagination

`all` and `select` accept `limit:` and `offset:` (and `all` also takes `order_by:`). **`where`
does NOT** — its only keyword is `include:` (the signature is
`where(conditions, params = [], include: nil)`, `lib/tina4/orm.rb:305`). To page a *filtered*
set, use `select` with a full SQL statement, or `all`:

```ruby
users = User.all(limit: 20, offset: 40, order_by: "id DESC")   # page 3 at 20/page

# where has no limit:/offset:/order_by: — reach for select for a paged filtered query:
active = User.select("SELECT * FROM users WHERE is_active = ? ORDER BY id DESC",
                     [1], limit: 20, offset: 40)
```

## QueryBuilder — Fluent Queries with JOINs

Use `Tina4::QueryBuilder` for complex queries (JOINs, aggregates, GROUP BY) instead of raw SQL.
Prefer it over `db.fetch` for maintainability. Start with `from_table(table, db:)` (the `from`
method does not exist — it was renamed to `from_table` to avoid the Ruby keyword clash).

```ruby
# Simple query
users = Tina4::QueryBuilder.from_table("users", db: db)
  .select("id", "name", "email")
  .where("is_active = ?", [1])
  .order_by("name ASC")
  .limit(10)
  .get                       # => Tina4::DatabaseResult

# JOINs
orders = Tina4::QueryBuilder.from_table("orders o", db: db)
  .select("o.*", "c.name AS customer_name")
  .join("customers c", "o.customer_id = c.id")
  .where("o.status = ?", ["pending"])
  .order_by("o.created_at DESC")
  .limit(20)
  .get

# LEFT JOIN
products = Tina4::QueryBuilder.from_table("products p", db: db)
  .select("p.*", "cat.name AS category_name")
  .left_join("categories cat", "p.category_id = cat.id")
  .where("p.is_active = ?", [1])
  .get

# Aggregate → single row
total = Tina4::QueryBuilder.from_table("orders", db: db)
  .select("COALESCE(SUM(total), 0) AS total")
  .where("status != ?", ["cancelled"])
  .first["total"]            # first → a single row Hash, or nil

# COUNT
count = Tina4::QueryBuilder.from_table("users", db: db)
  .where("is_active = ?", [1])
  .count                     # => Integer

# GROUP BY + HAVING
stats = Tina4::QueryBuilder.from_table("orders o", db: db)
  .select("c.name", "COUNT(*) AS order_count")
  .join("customers c", "o.customer_id = c.id")
  .group_by("c.name")
  .having("COUNT(*) > ?", [5])
  .get

# From an ORM model (inherits the model's DB connection)
adults = User.query.where("age > ?", [18]).order_by("name").get

# Existence — the method is exists? (with a question mark), returning a Boolean
any = Tina4::QueryBuilder.from_table("users", db: db)
  .where("email = ?", ["alice@example.com"])
  .exists?
```

### QueryBuilder Methods

| Method | Description |
|--------|-------------|
| `from_table(table, db:)` | Start a query |
| `select(*cols)` | Set columns to select |
| `where(cond, params)` | AND condition |
| `or_where(cond, params)` | OR condition |
| `join(table, on)` | INNER JOIN |
| `left_join(table, on)` | LEFT JOIN |
| `group_by(col)` | GROUP BY |
| `having(expr, params)` | HAVING clause |
| `order_by(expr)` | ORDER BY |
| `limit(n, offset = nil)` | LIMIT + optional OFFSET |
| `get` | Execute → `DatabaseResult` |
| `first` | Execute → single row Hash or nil |
| `count` | Execute → Integer |
| `exists?` | Execute → Boolean |
| `to_sql` | Build SQL string without executing |
| `to_mongo` | Convert to a MongoDB query document |

## DatabaseResult

`db.fetch(...)` and `QueryBuilder#get` return a `Tina4::DatabaseResult`, which is `Enumerable`:

```ruby
results = db.fetch("SELECT * FROM users")
results.size        # record count
results.first       # first row Hash
results.to_array    # [ {..}, {..} ]  (alias: to_a via Enumerable)
results.to_json     # JSON string
results.to_csv      # CSV string
results.map { |row| row["name"] }
```

> ORM query methods (`User.all`, `User.where`, `User.select`) return a **plain Ruby Array of model
> instances**, not a `DatabaseResult`. Serialise with `User.all.map(&:to_h)` (or hand the Array to
> `response.json`, which converts each model). `to_array` / `to_json` / `to_csv` are `DatabaseResult`
> methods, available on the result of `db.fetch` and `QueryBuilder#get`.

## Raw SQL

For queries that ORM or QueryBuilder can't express, use the database directly. Always parameterize:

```ruby
db = Tina4::Database.new("sqlite:data/app.db")
results = db.fetch("SELECT * FROM users WHERE id = ?", [1])   # DatabaseResult
one     = db.fetch_one("SELECT * FROM users WHERE id = ?", [1]) # single row Hash or nil
db.execute("UPDATE users SET is_active = ? WHERE id = ?", [0, 1])
```

## Database Connection

Set `TINA4_DATABASE_URL` in `.env`, then bind a connection in `app.rb`:

```ruby
db = Tina4::Database.new(ENV["TINA4_DATABASE_URL"])   # e.g. "sqlite:data/app.db"
Tina4.bind_database(db)

# Or from the env directly:
db = Tina4::Database.from_env    # reads TINA4_DATABASE_URL
```

Connection string formats (same across every Tina4 language):
```
sqlite:data/app.db
postgresql://user:password@localhost:5432/mydb
mysql://user:password@localhost:3306/mydb
mssql://user:password@localhost:1433/mydb
firebird://user:password@localhost:3050/mydb
```

## Migrations

```bash
tina4 migrate                              # run pending migrations
tina4 migrate:status                       # show migration status
tina4 migrate:rollback                     # roll back the last batch
tina4 migrate:create "add users table"     # scaffold a new migration file
tina4 generate migration create_users      # scaffold a new migration file (same envelope)
tina4 generate migration create_users --fields "name:string,email:string"
```

**Four surfaces, one envelope.** A new migration can be scaffolded from FOUR
places, and every one emits the SAME ADR-0063 `generate_v1_1` resolution
envelope — same `-- tina4:edit` markers baked into the UP + DOWN `.sql`,
same `edit_hints[]`, same `next[]`. The four paths are:

1. **CLI shortform** — `tina4ruby migrate:create <description>` — the shorter
   form for a human description (it slugifies "add users table" →
   `add_users_table` and preserves the raw prose in the file's `-- Migration:`
   header).
2. **CLI generator** — `tina4ruby generate migration <name>` — composes with
   `--fields "name:string,price:float"` for schema-aware `CREATE TABLE`
   scaffolding when the name starts with `create_X`.
3. **MCP tool** — `migration_create(description:)` — the same lambda a coding
   agent (Claude Code / Cursor / etc.) drives through `POST /__dev/mcp`. The
   tool delegates to the SAME shared resolution-aware helper the CLI uses, so
   the returned JSON carries `{ok, created, resolution, actions_taken}` where
   `resolution` is the full v1.1 envelope. Duplicate-slug guard: a second
   call for the same (or clearly equivalent) description returns
   `{ok: false, error, existing: [<path>]}` and writes nothing, so an agent
   edits the existing migration instead of spawning a second file for the
   same schema change (mirrors PHP + Python MCPs).
4. **Dev-admin HTTP** — `POST /__dev/api/scaffold/run` with
   `{kind: "migration", name: "..."}` — shells out to `exe/tina4ruby generate
   migration <name>` and returns `{ok, kind, name, output}` where `output` is
   the CLI subprocess's captured stdout + stderr, including the human
   "Edit these lines:" + "Next:" resolution block. The endpoint also handles
   `route`, `model`, and `middleware` the same way — mirroring PHP's
   `shell_exec 'php bin/tina4php generate ...'` and Node's `execFileSync
   'npx tina4nodejs generate ...'`.

One intentional difference: `generate migration create_X` co-emits a spec at
`spec/{table}_migration_spec.rb`; `migrate:create` never does (it passes
`emit_test: false` to the shared generator). The MCP tool follows
`migrate:create`'s behaviour (no co-emitted spec) — an agent creating a
migration is not asking for a test file. Nothing is deprecated (3.13.121
unified all four paths onto the same envelope).

**Twig templates (form, view) participate in `edit_hints[]` from 3.13.121;
the scanner matches `# tina4:edit`, `-- tina4:edit`, and `{# tina4:edit ... #}`
styles.** `tina4 generate form <Name>` (writes `src/templates/forms/<name>.twig`)
and `tina4 generate view <Name>` (writes `src/templates/pages/<plural>.twig` +
`src/templates/pages/<singular>.twig`) now emit the same `generate_v1_1`
envelope as model / migration / route / middleware — `--json --dry-run` returns
a `resolution.edit_hints[]` pointing at the twig `{# tina4:edit <label> #}`
markers baked into each generated template, with a clean label (the scanner
strips the closing `#}` before capture). Bare `generate form / view` prints
the same "Edit these lines:" and "Next:" block to STDERR. This is additive:
the envelope version is still `1.1`, and Ruby + SQL markers keep firing as
before.

Migration files are versioned SQL in **`migrations/`** at the project root — the canonical location
(matches the CLI + auto-migrate + the Python reference); a legacy `src/migrations/` is honoured only
as a fallback (`lib/tina4/migration.rb:160`; the boot
auto-migrate resolver checks the same two, `lib/tina4.rb:470`). Write standard SQL:
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

Alternatively, a model can create its own table from its field definitions with `User.create_table`
(engine-aware DDL; returns `false` if the DDL fails).

## Seeding

```bash
tina4 seed:create "initial users"   # create a seed file
tina4 seed                          # run all seeds in seeds/
```

Quick fake data:
```ruby
fake = Tina4::FakeData.new
fake.name     # "Alice Johnson"
fake.email    # "alice.johnson@example.com"

Tina4.seed_orm(User, count: 50)    # bulk-seed a model from its field types
```

## Auto-CRUD

Set `self.auto_crud = true` on a model — Tina4 auto-registers a full list/create/read/update/delete
route set for it, no handler to write:

```ruby
class User < Tina4::ORM
  self.auto_crud = true
  integer_field :id, primary_key: true, auto_increment: true
  string_field  :name
  string_field  :email
end
```

## ORM Lifecycle & Footguns

The write path has a deliberate but **asymmetric** failure contract: `save` fails *soft*
(returns `false`), while `delete` / `restore` and raw `db.execute` fail *loud* (raise). Getting
this wrong is the biggest source of wasted debugging. Each item is **what bites → the safe idiom
→ what breaks**, verified against `lib/tina4/orm.rb` and `lib/tina4/database.rb`. Where Ruby
behaves **differently from the Python master**, that is called out — do not port the Python idiom
blind.

### `save` fails *soft* — it returns `false`, never raises

`save` returns `self` on success (fluent) and **`false`** on *any* failure — validation OR a
driver error. It **never raises** and never returns `nil`. The cause is recorded on
`model.last_error` / `model.get_error` (mirroring `db.get_error`) and `model.errors`, and logged,
so a swallowed failure is always recoverable. `create` = `new` + `save`; when the save fails it
returns `false` (never a half-saved instance).

```ruby
# SAFE — check the return, surface the cause
user = User.new(name: "Alice", email: "a@x.com")
unless user.save                       # false on failure — NOT an exception
  next response.json({ error: user.get_error }, 422)   # e.g. "name cannot be null"
end
```

* **Breaks:** `begin; user.save; rescue; ...` — the `rescue` never fires, so a failed write looks
  like success. Testing `if user.save.nil?` is also wrong (it's `false`, not `nil`).
  `orm.rb:697` (`save`), `orm.rb:362` (`create`).

### No auto table-create — `save` into a missing table returns `false` (with a hint)

Defining a model does **not** create its table. The first `save` into a table that doesn't exist
hits `no such table` in the driver, which `save` catches → returns `false` with the cause on
`last_error`. As of the parity pass the cause is augmented with an actionable hint
(`… — table 'users' does not exist; call User.create_table or run a migration`), but nothing
*aborts* — no row lands.

```ruby
# SAFE — create the table (dev) or run a migration (prod) before the first write
User.create_table          # idempotent: CREATE TABLE IF NOT EXISTS from the declared fields
User.new(name: "Alice").save
```

* **Breaks:** relying on `save` to bootstrap the schema — it returns `false` silently and no row
  lands. `create_table` builds DDL from **declared fields only** (it injects nothing — see
  soft-delete's `is_deleted`) and itself returns `false` (never raises) if the DDL fails.
  `orm.rb:380`.

### Ruby's constructor does NOT validate — build from `request.body` freely

**This DIFFERS from Python.** The Python constructor validates on the read path and *raises* on a
bad value, so `Model(request.body)` can 500. **Ruby's constructor does not validate at all** — the
field setters are plain `attr_accessor` (`field_types.rb:191`) and `initialize` only assigns +
applies defaults (`orm.rb:618`). So `User.new(request.body)` with a missing/bad field is **safe**;
the failure surfaces later at `save` as `false`. The only things that raise out of `new` are a
**non-Hash positional arg**: an **Array** (`ArgumentError` — a model is one record) and a
**String that isn't valid JSON** (`JSON::ParserError`, because a String arg is parsed as a JSON
object).

```ruby
# SAFE in Ruby — construct straight from the body, then check save()
user = User.new(request.body)          # a Hash with String keys — never raises on bad field values
next response.json({ error: user.get_error }, 422) unless user.save
```

* **Breaks:** `User.new(request.body["items"])` when `items` is an Array → `ArgumentError`; feeding
  a non-JSON String to `.new`. (Do NOT copy Python's "build empty, assign, then save" defensive
  dance — it's unnecessary in Ruby.)

### No read-path validation — N/A in Ruby (unlike Python)

**DROP this Python footgun.** In Python, `field.validate` runs when hydrating rows, so tightening a
constraint can make *reads* of existing rows raise. **Ruby's `from_hash` only assigns via setters,
with no validation** (`orm.rb:506`) — `validate` runs *only* inside `save` (`orm.rb:703`). Reading
a row that violates a current constraint never raises in Ruby; validation is a save-time concern
only.

### `delete` / `restore` / `force_delete` DO raise — the asymmetry

Unlike `save`, the delete family fails **loud**: `delete` and `force_delete` **raise** when there's
no primary-key value (`"Cannot delete: no primary key value"`); `restore` raises
`"Model does not support soft delete"` on a model without `soft_delete` (and on a nil PK). Same
framework, opposite contract.

```ruby
# SAFE — guard the preconditions; wrap in begin/rescue if the row may be gone
user = User.find_by_id(uid)
user.delete if user            # raises if user's PK is nil or the DB write fails
```

* **Breaks:** `User.new(...).delete` on an unsaved instance (PK is `nil`) → raises, not `false`.
  `orm.rb:791` (`delete`), `:811` (`force_delete`), `:823` (`restore`).

### `db.execute` raises — it does not return `false`

Raw writes via `db.execute` fail **loud**: a driver error **raises** (and sets `db.get_error`); it
does **not** return `false`. A successful non-`SELECT`/`RETURNING` write returns `true`. (The ORM's
`save` wraps this and converts the raise to `false` — but a *direct* `db.execute` propagates.)

```ruby
# SAFE — rescue writes you expect might fail; don't test the return value for falsiness
begin
  db.execute("INSERT INTO audit (msg) VALUES (?)", ["ok"])
rescue => e
  next response.json({ error: db.get_error || e.message }, 500)
end
```

* **Breaks:** `if !db.execute(sql); ...` — a successful simple write returns `true`, and a *failed*
  one raises rather than returning a falsy value, so the branch never runs. `database.rb:625`.

### A database must be bound before any ORM / QueryBuilder call

Every ORM query resolves a connection via `db` (`orm.rb:63`): a per-model `self.db =` →
`Tina4.database` (set by `Tina4.bind_database`) → env auto-discovery (`TINA4_DATABASE_URL`). A
**named** connection that was never registered (`self.db = :analytics`) raises a **clear** error
(`"named database connection 'analytics' is not registered…"`). An entirely **unbound** model with
no global and no `TINA4_DATABASE_URL` resolves `db` to `nil`, so the first query raises a
**`NoMethodError` on `nil`** — a less obvious message, so bind up front.

```ruby
# SAFE — bind at boot (app.rb), or set TINA4_DATABASE_URL in .env for auto-discovery
Tina4.bind_database(Tina4::Database.new(ENV["TINA4_DATABASE_URL"]))   # sqlite:data/app.db
```

* **Breaks:** an ORM query in a script/worker that never bound a DB or set the env var →
  `NoMethodError` (nil has no `fetch`). `orm.rb:579` (`auto_discover_db`).

### Auto-migrate is fail-soft and boot-time; the CLI is fail-fast

`Tina4.initialize!` runs `auto_migrate_on_startup!` (`lib/tina4.rb:219`): when a `migrations/`
(or legacy `src/migrations/`) folder holds at least one `.sql` file, pending migrations are applied at boot so
the schema is current. It is **fail-soft** — a bad migration is logged loud and **the service still
starts** (`lib/tina4.rb:470`). The explicit **`tina4 migrate` CLI stays fail-fast** (non-zero exit
for CI). Disable boot migration with `TINA4_AUTO_MIGRATE=false` (also `0`/`no`/`off`) —
recommended for multi-instance prod where concurrent first-apply can race.

* **Breaks:** assuming a green server boot means migrations applied — check the logs, or gate
  deploys on `tina4 migrate` (which exits non-zero).

### No default ordering — paginate with a unique tiebreaker

`all` / `select` apply **no `ORDER BY` unless you pass one**; without it row order is engine-defined
(SQLite rowid, unspecified on Postgres), and `limit`/`offset` pages can repeat or skip rows.
Ordering by a non-unique column (e.g. `created_at`) has the same problem on ties.

```ruby
# SAFE — always order by a UNIQUE tiebreaker for stable pagination
page = User.all(limit: 20, offset: 40, order_by: "created_at DESC, id DESC")
# (remember `where` takes no order_by/limit/offset — use `select` with a full ORDER BY for a
#  paged filtered query)
```

* **Breaks:** `User.all(limit: 20, offset: 20)` with no `order_by`, or `order_by: "created_at DESC"`
  alone — two rows with the same timestamp can land on two different pages (or neither).
  `orm.rb:318`.

### Framework gotchas (auth, routing, templates, background work)

These bite outside the ORM but hit the same build loop. Verified against source.

* **Auth / unexpected 401 (security).** An unexpected 401 on a write means **the caller needs a
  token**, not that the route should be opened. `.no_auth` / `auth: false` are a **last resort** for
  genuinely public endpoints only. See **`auth-and-services.md` → "Auth footguns"** for the full
  treatment (both write gates, and the `swagger_meta` docs-only trap).

* **Routes are blocks, not decorators — there is no decorator stack.** Ruby registers routes with
  `Tina4.get`/`Tina4.post` (`… do |request, response| … end`); public writes chain `.no_auth`
  and/or pass `auth: false`. Python's "route decorator innermost, meta on top" ordering rule does
  **not** apply here. (`router.rb:39`.)

* **Postgres / manual transactions need a commit.** A **standalone** `db.execute` write
  auto-commits when `TINA4_AUTOCOMMIT=true` (the default). But a write made **inside
  `db.transaction`** is committed by the block, and a write with `TINA4_AUTOCOMMIT=false` — or
  inside a manual `db.start_transaction` — needs an explicit `db.commit` or it rolls back and the
  row never lands. (The ORM's `save` already wraps transaction + commit.) `database.rb:262`,
  `:1205`.

* **Frond templates (`src/templates/`, engine is Frond, not real Jinja2/Twig).** Unescape with
  `{{ x|raw }}` **or** `{{ x|safe }}` (both work). Concatenate with `~`, **not `+`**:
  `{{ "hi " ~ name }}` — `+` is arithmetic and coerces both sides to numbers, so `{{ "hi " + name }}`
  renders **`0`**, not the string (`frond.rb:1186`, `:1423`). `{{ x|e }}` / `{{ x|escape }}`
  HTML-escape and **ignore** any extra args (they do not raise), and Frond accepts **both**
  `{% elif %}` and `{% elseif %}` — so pure-Jinja2 advice does not apply. Live regions raise at
  render if malformed: `{% live "x" poll 5 %}` (poll needs seconds), `{% live "x" ws "/ws/x" %}`
  (ws needs a path), an unknown transport raises, and a `src "…"` must be a **same-origin path** (an
  absolute `http(s)://` or `//` URL raises). `frond.rb:1841`. (Full syntax in
  `templates-and-frontend.md`.)

* **`db.fetch` returns a `DatabaseResult`, not an Array.** Rows live on **`.records`**; `.first`
  is a single row Hash accessed by key (`result.first["name"]`). It is `Enumerable`
  (iterable/indexable/`size`), and carries `.to_array` / `.to_json` / `.to_csv`. But an ORM query
  (`User.all` / `User.where` / `User.select`) returns a **plain Array of model instances** — an
  Array has **no** `.to_array` / `.to_json` / `.to_csv`; serialise with `User.all.map(&:to_h)` (or
  hand the Array to `response.json`, which converts each model). `database_result.rb`.

* **Periodic work uses `Tina4::Background`, not a raw `Thread`.** Register recurring work with
  `Tina4::Background.register(callback, interval: 60)` (or a block) — it owns the thread lifecycle,
  clean shutdown (`stop_all`), and logs callback errors so one failure never kills the loop. Don't
  hand-roll `Thread.new`. `background.rb:22`.

  ```ruby
  Tina4::Background.register(interval: 60) { sync_inbox }   # every 60s
  ```

* **Route param types are a fixed set.** A typed brace param (`/users/{id:int}`) must use a known
  type, or route registration **raises `ArgumentError`** — it never silently falls through to a
  match-anything matcher (a `{id:inetger}` typo would be a security footgun). Valid types:
  **`string`, `int`, `integer`, `float`, `number`, `alpha`, `alnum`, `slug`, `uuid`, `path`**
  (`int`/`integer` cast to Integer, `float`/`number` to Float; the rest stay String). Note the
  syntax is `{id:int}` — **not** `:id`. `router.rb:160`.

## When to reach for `tina4_context`

`tina4_context(instruction, language: "ruby")` (server `tina4-coder`) retrieves the authoritative,
version-current Tina4 API + real examples from the live corpus. It is a **grounding** tool, not a
code generator — write the Ruby yourself from what it returns. Use it as a ladder, not a reflex:

1. **Skill covers it → write from the skill.** These reference files are the source of truth for the
   common surface (models, routes, CRUD, templates, auth, queues). Don't spend a call on something
   documented here.
2. **Uncovered / current-tree API / a surprise → then call `tina4_context`.** Reach for it when the
   skill doesn't cover the case, you need an API the installed version added recently, or the
   framework did something the doc didn't predict. Pass `language: "ruby"` explicitly —
   auto-detection mis-fires on ambiguous text.
3. **Write it yourself, then verify against the live API.** Confirm any method / field / route shape
   against the running project's MCP index — `api_method("Tina4::ORM", "find_by_id")`,
   `api_class("Tina4::ORM")`, `api_search("…")` (needs `tina4 serve` + `TINA4_DEBUG=true`). **The
   framework code is the final authority.** Do **not** use `tina4_code` / `tina4_review` (the
   self-hosted generator) — the value is the retrieval, not a small model. It failed a boot-and-verify gate that Claude grounded with `tina4_context` passed.

## Batteries included — near-zero dependencies

Tina4 Ruby is **batteries-included**: 140 cataloged features, and the handful of runtime gems it
*does* pull are Rack-stack + deployment essentials, not framework bloat. Its `tina4ruby.gemspec`
runtime dependencies are **`rack`, `rackup`, `puma`** (the HTTP server stack), **`jwt`** (auth),
**`net-smtp` / `net-imap`** (the Messenger), **`json`, `rexml`, `webrick`**, and **`sqlite3`** (so
`tina4 init && tina4 serve` runs with a working DB out of the box). Everything else — Postgres/MySQL/
MSSQL drivers, Mongo, Redis/Valkey, Kafka, RabbitMQ — is **optional** and required lazily; the
backend degrades gracefully when the gem is absent. This is a genuine difference from Python (which
hand-rolls JWT and ships a truly empty `dependencies = []`) — state it honestly: *near-zero-dep,
batteries-included*, not *zero-dependency*.

Before you add a gem, check whether it's already in the box. **Need → Tina4 built-in (verified
against `lib/tina4/`) — don't add the dep:**

| Need | Tina4 built-in — don't add the gem |
|------|------------------------------------|
| Auth / JWT / password hashing | `Tina4::Auth` — `hash_password`/`check_password`/`get_token`/`valid_token`/`authenticate_request` *(`auth.rb`)* |
| ORM / models | `Tina4::ORM` + the `*_field` declarations, `Tina4.bind_database` *(don't add ActiveRecord/Sequel — `orm.rb`)* |
| Fluent queries / JOINs | `Tina4::QueryBuilder.from_table(t, db: db)` *(`query_builder.rb`)* |
| DB drivers (multi-engine) | `Tina4::Database` — sqlite built in; postgres/mysql/mssql/firebird/mongo lazy-loaded *(`database.rb`, `drivers/`)* |
| Migrations | `tina4 migrate` CLI / `Tina4::Migration` *(`migration.rb`)* |
| Templating | `Tina4::Frond` + `response.render("page.twig", {...})`; templates in `src/templates/` *(`frond.rb`)* |
| SCSS → CSS | drop `.scss` in `src/scss/` — compiled on `tina4 serve` *(`scss_compiler.rb`)* |
| Input validation | `Tina4::Validator` *(`validator.rb`)* |
| Response / JSON | return a Hash/Array → JSON; `response.json(model_or_array)` serialises ORM objects *(`response.rb`)* |
| Background queue | `Tina4::Queue.new(topic:).push(...)` / `.consume` *(don't add Sidekiq/Resque — `queue.rb`)* |
| Email | `Tina4::Messenger.new.send(to:, subject:, body:, html:)` *(`messenger.rb`)* |
| Sessions | `request.session` (backends file/redis/valkey/mongodb/memcached/database via `TINA4_SESSION_BACKEND`) *(`session.rb`)* |
| Caching | `Tina4::QueryCache` / `Tina4::ResponseCache` / `Tina4.cache_*` module API + `{% cache %}` blocks *(`cache.rb`, `response_cache.rb`, `cache_backends/`)* |
| OpenAPI / Swagger | `Tina4::Swagger` — served at `/swagger` *(`swagger.rb`)* |
| WebSockets | `Tina4.websocket "/ws/…"`; live regions via Frond `{% live %}` *(`websocket.rb`)* |
| Real-time (WebRTC signalling, presence) | `Tina4::Realtime.mount` *(`realtime.rb`, `realtime/`)* |
| GraphQL from models | `Tina4::GraphQL.new.auto_register(...)` → `/graphql` *(don't add graphql-ruby — `graphql.rb`)* |
| SOAP / WSDL | `Tina4::WSDL` *(`wsdl.rb`)* |
| i18n / localization | `Tina4.t(key, **kwargs)`; JSON in `src/locales/` *(`localization.rb`)* |
| Document store (Mongo-style on SQLite) | `Tina4::DocStore` *(`docstore.rb`)* |
| Dependency injection | `Tina4::Container` *(`container.rb`)* |
| Fake data / seeding | `Tina4::FakeData`, `Tina4.seed_orm(Model, count:)` *(don't add faker — `seeder.rb`)* |
| In-process HTTP test client | `Tina4::TestClient` — drives routes without a live server *(`test_client.rb`)* |
| Events | `Tina4::Events.on/emit` *(`events.rb`)* |
| **Outbound HTTP calls** | `Tina4::API.new(base_url).get/.post` *(don't add HTTParty/Faraday — `api.rb`)* |
| Periodic background work | `Tina4::Background.register(cb, interval:)` *(don't hand-roll `Thread.new` — `background.rb`)* |
