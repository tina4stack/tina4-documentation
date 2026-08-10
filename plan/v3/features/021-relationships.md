# Feature 021: Declarative ORM relationships

## Identity and status

- Matrix identity: 21 - Declarative ORM relationships
- Audit state: decision-ready
- Audit note: measured 2026-07-28, both Outstanding items closed by execution 2026-07-30;
  prose sections completed from that evidence 2026-08-10. No framework code changed.
- Dependencies: Feature 17 ORM base class (relationships live there), Feature 6 query builder
  (eager loading composes the queries), Feature 22 imperative relationships (the method form)
- Dependants: any model graph an application navigates; AutoCrud; the Node CLAUDE.md doc that
  currently claims an auto-wire that does not happen
- Existing ADRs: the removed `QueryBuilder#get` `LIMIT 100` default (the same footgun D4 finds
  in `has_many`); this feature shares the 100-row cap question with Feature 5 and Feature 23
- Shared fixtures: `relationships_contract.json` is required; its N+1 case is the one no
  framework asserts today

## Why this feature exists

A developer declares a foreign key once and navigates both sides of the relationship
(`post.author` and `author.posts`) without wiring each direction by hand. Today only Python
and Ruby deliver that; PHP requires an imperative call and Node's documented auto-wire
produces no accessor at all.

## Boundary

This feature owns declarative relationships: a foreign-key declaration wiring `belongs_to` on
the declaring model and `has_many` on the referenced model as instance accessors, the
has-many naming default, and eager loading (the N+1 avoidance). It DELEGATES the model to
Feature 17, the queries to Feature 6, and the imperative `hasMany()`/`belongsTo()` method form
to Feature 22. The 100-row cap it exposes is shared with Feature 5 and Feature 23 and is
settled once, not here alone.

## Existing implementation evidence

| Evidence (verified by execution vs real SQLite) | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| One FK declaration wires accessors | YES (metaclass) | NO (imperative only) | YES (DSL) | NO (serialize-only) |
| `post.author` accessor | yes | via `belongsTo()` call | yes | MISSING |
| `author.posts` accessor | yes | via `hasMany()` call | yes | MISSING |
| How a relation is reached | auto-wired accessor | imperative method | auto-wired accessor | `find(id, include).toDict(include)` |
| Has-many default name | declaring class + s (correct) | n/a | correct | doc claims it, none wired |
| `has_many` silent 100-cap | YES (limit=100) | YES (limit=100) | no (no limit) | YES (100) |
| Eager-load structure | `_eager_load` (ok) | `eagerLoad` (CC 35) | one loader per kind (best) | eager inside find |

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 3. **Planning only.**

**Status: CLOSED.** All four verified by execution. The Node outstanding item is
resolved (2026-07-30): relations are reachable but serialize-only, and `hasMany`
silently truncates at 100. See Outstanding below.

### Files

Relationships live in the ORM base class; measurements are feature 16's. The
relevant offender:

| | worst relationship function | CC |
| --- | --- | --- |
| php | `eagerLoad` | **35** |
| python | `_eager_load` | (under threshold) |
| node | (eager path inside `find`/`all`) | - |
| ruby | `load_has_many` / `load_belongs_to` / `load_has_one` | (under threshold) |

Ruby is the only framework that splits eager loading into one named function per
relationship kind. PHP does all three in one 35-CC method. That split is the
structural answer and it already exists.

## Public surface contract

Declaring a foreign key (idiomatically per language: `ForeignKeyField(to=Author)`,
`foreign_key_field :author_id, references: Author`, `{type: "foreignKey", references:
"Author"}`) wires a `belongs_to` accessor on the declaring model (`post.author`) and a
`has_many` accessor on the referenced model (`author.posts`), both as INSTANCE accessors with
no further call. The has-many name defaults to the declaring class lowercased plus `s`,
overridable by one named option (`related_name`/`relatedName`). Eager loading takes the
relationship name: `find(id, include=["author"])`. Feature 22 owns the imperative
`hasMany()`/`belongsTo()` method form.

## Inputs and outputs

- Input: one foreign-key declaration on the declaring model.
- Output: a `belongs_to` accessor and a `has_many` accessor, both on the instance; no
  wrong-direction accessor is created (`author.authors` must not exist).
- `has_many` returns ALL children, not a silently capped 100 (the D4 fix).
- Eager `include` populates the relation in a BOUNDED number of query sets, never one query
  per row (the N+1 the feature exists to prevent).
- The same declaration yields the same accessor names in all four.

## Lifecycle and operation graph

1. A foreign key is declared at class definition; both accessors are wired at declaration
   time (Python metaclass, Ruby DSL) so no registry step is required.
2. Accessing `post.author` or `author.posts` loads lazily, or eagerly when the read passed
   `include`.
3. Eager loading resolves each relationship kind through its own named loader
   (`load_belongs_to`/`load_has_many`/`load_has_one`), issuing one query set per relationship
   rather than one query per row.
4. Serialization includes an eager-loaded relation via `toDict(include)`.

## Configuration and precedence

- `related_name`/`relatedName` overrides the has-many accessor name; the default is the
  declaring class pluralized.
- The `has_many` limit is NOT a silent default 100; the 100-row cap is removed and the cap
  question is settled once across `has_many`, the query builder (Feature 5) and pagination
  (Feature 23).
- References are the class itself where the language allows (Python, Ruby, PHP); Node uses a
  string plus a registry, which must resolve automatically at first use.

## Failures, side effects and security

- `has_many` must NOT silently truncate at 100: an author with 150 posts returns 150, not
  100 with 50 dropped and no warning. Silent truncation is data loss by omission (the same
  footgun already removed from `QueryBuilder#get`).
- Eager loading must not degrade to N+1 queries; the fixture asserts a bounded query count,
  because a silent degradation to per-row queries is the production failure the feature
  prevents.
- A wrong-direction accessor is never created; navigation follows only the declared edge.
- Node's documented auto-wire claim is FALSE as written (no accessor is created); the doc
  changes even if the mechanism stays serialize-only.

## Wire and persistence contract

There is no new persistence; the foreign-key column is an ordinary column. The wire contract
is the accessor NAMES and the serialized shape: the same declaration exposes `post.author`
and `author.posts` (or the overridden name) in all four, and an eager-loaded relation appears
under the same key in `toDict(include)`.

## Providers and substitutability

Relationships and eager loading are engine-agnostic: the accessor names and the bounded
query behaviour are identical regardless of the provider. Eager loading composes standard
`WHERE ... IN (...)` reads through Feature 6, so any provider satisfies it.

## Contradictions and defects

### What differs

**D1. Python and Ruby auto-wire both sides from one declaration. Verified.**

Author plus Post with a foreign key, two posts saved, real SQLite:

| | belongs-to | has-many accessor | wrong-direction accessor | count | eager `include` |
| --- | --- | --- | --- | --- | --- |
| python | `post.author` -> `ann` | `author.posts` yes | `author.authors` no | 2 | `ann` |
| ruby | `post.author` -> `ann` | `author.posts` yes | `author.authors` no | 2 | not probed |
| php | `belongsTo()` -> `ann` | **imperative only** | n/a | 2 | not probed |

Both get the has-many default name right - the declaring class (`Post`) lowercased
plus `s`, not the referenced class - and neither leaks a wrong-direction accessor.
That is the contract working exactly as documented.

**D2. Node's documented auto-wire produced no accessors.**

`tina4-nodejs/CLAUDE.md` states: "Declare a field with `type: "foreignKey"` and
`references: "ModelName"` to auto-wire both `belongsTo` on the declaring model AND
`hasMany` on the referenced model... Models must be registered via
`BaseModel.registerModel(name, class)` for name-based resolution."

Followed exactly - both models registered, FK declared with `references: "Author"` -
and then:

```
belongs_to: post.author  -> MISSING
has_many:   author.posts -> MISSING  (instance keys: _relCache, lastError, id, name)
```

Calling `_processForeignKeys()` and `_applyFkRegistry()` explicitly on both classes
first made no difference. So it is not a missed wiring call.

**Scope this claim carefully.** What is verified: with the documented declaration
and registration, `post.author` and `author.posts` are not present as instance
accessors, and passing `include` to `find()` did not populate them. What is NOT
verified: whether Node attaches relations somewhere else - into `toDict(include)`
output rather than onto the instance. Node's relationship surface is static data
(`static hasMany = [...]`), which is a genuinely different shape from the other
three, so a different retrieval path is plausible. That is Outstanding item 1, and
it decides whether this is a **bug** or a **surface divergence with a working
mechanism**.

**D3. Four declaration styles for one concept** (carried from feature 16's D3):

| framework | declaration |
| --- | --- |
| python | `author_id = ForeignKeyField(to=Author)` - wires at class creation via the metaclass |
| ruby | `foreign_key_field :author_id, references: Author` - wires at class definition via the DSL |
| php | `hasMany()` / `hasOne()` / `belongsTo()` methods |
| node | `author_id: {type: "foreignKey", references: "Author"}` in `static fields`, plus `static hasMany = [...]` arrays |

Python and Ruby wire **at declaration time**, which is why theirs work with no
further ceremony. Node defers to a registry that must be populated, and PHP is
imperative. The registry approach is the one that needs an extra step and is the
one that failed.

### Verdict: PROVISIONAL - PROMOTE python/ruby on the wiring, ruby on the structure

Decided on **correctness** for the wiring and **SOLID** for the eager-load split.

Python and Ruby both implement the contract correctly and identically, including the
has-many naming default. Either is a valid reference; Ruby additionally has the
better eager-load structure (one named function per relationship kind against PHP's
single 35-CC method).

Node is the framework that changes most, pending D2. PHP needs the `eagerLoad`
split regardless of what its behaviour turns out to be.

Wire-at-declaration beats wire-via-registry, and that is the design decision worth
recording: the registry exists to resolve a model by string name, which is only
necessary because Node references models as strings (`references: "Author"`) rather
than as the class. Python and Ruby pass the class itself and need no registry at all.

### Risks

- **D2 may be a probe artifact.** Do not schedule Node work until Outstanding item 1
  is settled; the difference between "broken" and "different accessor" is the
  difference between a P1 and a rename.
- **The `eagerLoad` split is safe** and can proceed independently.
- **Making Node's registration automatic** may change model-load ordering. Register
  lazily at first relationship access rather than at class definition, which avoids
  the TypeScript static-ordering problem entirely.

## Owner decisions

Proposed for owner ratification (the execution evidence forces each):

1. One foreign-key declaration wires BOTH accessors on the instance, at declaration time, in
   all four (PROMOTE Python/Ruby, which already do this correctly including the naming
   default). PHP gains auto-accessors; Node's wiring is fixed to match.
2. Node's CLAUDE.md claim is FALSE and must change regardless: declaring the FK creates no
   accessor. Fix the doc, and make the registry resolve automatically at FIRST relationship
   access (lazy), avoiding the TypeScript static-ordering problem.
3. Remove the silent `has_many` 100-row cap. This is the SAME 100-row footgun as Feature 5's
   query-builder cap and Feature 23's page size; settle it ONCE, in one decision, across all
   three surfaces rather than per feature. Ruby (no limit) is the reference.
4. Eager loading is one named function per relationship kind (Ruby's `load_belongs_to`/
   `load_has_many`/`load_has_one`), splitting PHP's CC-35 `eagerLoad`. Behaviour-neutral, can
   land independently.
5. Reference the class, not a string, where the language allows (Python/Ruby/PHP already);
   Node keeps the string only because TypeScript static ordering forces it, and only if the
   registry then works automatically.

### Outstanding: CLOSED by execution (2026-07-30)

Probed against real SQLite: one author, 120 posts, both models registered, the FK
declared exactly as `tina4-nodejs/CLAUDE.md` documents.

**D2: the relations are reachable, so this is a surface divergence, not a broken
feature - but it needs BOTH an include at fetch time AND an include at serialize
time, and it never creates an accessor.**

```
instance keys (author)                   : _relCache, lastError, id, name
author.posts as a property               : MISSING
post.author as a property                : MISSING
author.toDict(["posts"])                 : id, name          <- MISSING, fetched plain
Author.find(1, ["posts"]).posts          : MISSING            <- still no accessor
Author.find(1, ["posts"]).toDict(["posts"]) : id, name, posts  <- present
```

So the data is there, on exactly one path: `find(id, include)` **then**
`toDict(include)`. Either half alone yields nothing, and no accessor is ever created
on the instance.

That makes four different shapes for one row, not three:

| | how a relation is reached |
| --- | --- |
| python | auto-wired accessor (`author.posts`) |
| ruby | auto-wired accessor (`author.posts`) |
| php | imperative only (`$author->hasMany(Post::class, 'author_id')`) |
| node | **serialize-only, double opt-in**: `find(id, include).toDict(include)` |

**The documented claim is false as written.** `CLAUDE.md` says declaring the FK
"auto-wires both `belongsTo` on the declaring model AND `hasMany` on the referenced
model". No accessor is wired on either side. The doc has to change even if the
mechanism does not.

**D4: `hasMany` silently truncates at 100.** With 120 real rows:

```
author.hasMany(Post, "author_id") returned: 100 rows
```

No argument was passed, no warning was emitted, and 20 rows were dropped. This is the
same 100-row default cap as feature 5's open row-cap item and feature 23's page size,
reaching the caller through a third door. It should be settled once, in one decision,
across all three surfaces rather than per feature.

That also closes the open half of D4 below: it asked for Node's `has_many` limit to
be checked against Python's and PHP's silent 100. Node has the same 100. Three of
four truncate silently; only Ruby's DSL declares no limit.

**PHP: resolved.** With the correct model shape (non-nullable typed properties with
defaults, per `tina4-php/tests`), and using `load()` correctly - it returns `bool`
and loads into `$this`, it does not return the model:

```
belongsTo -> ann          (imperative call works)
hasMany   -> 2 rows       (imperative call works)
auto accessor $au->rposts? no
```

So **PHP is imperative-only**: the relationship methods work, but declaring a
foreign key creates no accessor. Python and Ruby auto-wire; PHP requires the
explicit call; Node's registry produced neither. That completes D3 with real data
and makes PHP the second framework needing accessor work.

**D4 (new). `has_many` carries a silent default `limit = 100` in Python and PHP.**

```
python  def has_many(self, related_class, foreign_key=None, limit: int = 100, offset: int = 0)
php     function hasMany(string $relatedClass, ?string $foreignKey = null, int $limit = 100, int $offset = 0)
ruby    def has_many(name, class_name: nil, foreign_key: nil)        <- no limit
```

So `author.posts` silently returns the first 100 children and no more, in two of
four. An author with 150 posts loses 50 with no error and no warning.

This is the same footgun that was already fixed once: `QueryBuilder#get` had its
default `LIMIT 100` removed deliberately. The ORM's `has_many` kept it. One fix
landed in one place and the identical hazard survived next door - which is an
argument for the audit doing the sweep rather than waiting for a report.

Ruby's DSL declares no limit; Node's was not matched by the probe and needs the
same check (folded into the Outstanding item).

## Proposed conformance fixture

### Tests to write

Real SQLite, Author plus Post, two child rows. No mocks.

| pair | positive | negative |
| --- | --- | --- |
| both sides wired | `declaring_a_foreign_key_creates_the_belongs_to_accessor`, `..._creates_the_has_many_accessor` | `neither_accessor_requires_an_extra_wiring_call` - the exact Node reproduction |
| naming default | `the_has_many_name_is_the_declaring_class_pluralised` | `the_has_many_name_is_not_the_referenced_class_pluralised` - `author.authors` must not exist |
| override | `related_name_overrides_the_has_many_accessor` | `the_default_accessor_is_absent_when_overridden` |
| eager load | `include_populates_a_belongs_to_in_one_query_set`, `include_populates_a_has_many` | `include_does_not_leave_the_relation_unpopulated` |
| N+1 | `eager_loading_n_children_issues_a_bounded_number_of_queries` | `eager_loading_does_not_issue_one_query_per_row` - the reason eager loading exists |
| structure | `each_relationship_kind_has_its_own_loader` | `no_eager_load_function_exceeds_complexity_twelve` - the PHP 35 reproduction |
| cross-framework | `all_four_expose_the_same_accessor_names_for_the_same_declaration` | `no_framework_exposes_an_accessor_the_others_lack` |

The N+1 pair is the one no framework currently asserts, and it is the entire point
of the feature - eager loading that silently degrades to per-row queries is the
failure mode that matters in production and the one nothing would catch today.

## Integration map

- Feature 17's base model hosts the accessors and the eager-load path; Feature 6 composes the
  eager `WHERE ... IN` queries; Feature 22 owns the imperative method form.
- The 100-row cap decision spans this feature, Feature 5 (query-builder cap) and Feature 23
  (pagination page size); they share one owner decision and one fixture assertion.
- Node's CLAUDE.md documents an auto-wire that does not happen; the docs update with the fix.
- Central fixtures, four runners and the CI matrix update together; the N+1 assertion is new
  and must run in CI.

## Breaking changes and migration

- Removing the silent `has_many` 100-cap changes result size: an author with 150 posts now
  returns 150, not 100. This is a correctness fix, but a caller that unknowingly relied on the
  cap sees more rows; note it and point at explicit `limit`/pagination for bounded reads.
- Node gains real accessors (or, at minimum, a corrected doc); PHP gains auto-accessors. A
  model relying on the imperative-only PHP path keeps working.
- The PHP `eagerLoad` split is internal and behaviour-neutral.

## Implementation backlog

### Methodology

1. Settle both Outstanding items. They decide whether this row is a two-framework
   port or a one-framework bug fix.
2. Write the tests below in all four; expect red on Node (both pairs) and unknown
   on PHP.
3. Split PHP's `eagerLoad` into the three named loaders, porting Ruby's shape.
   Behaviour-neutral, so it can land independently of the wiring question.
4. Fix Node's wiring to match the declaration-time contract, including automatic
   registration.
5. Re-measure: no relationship function above CC 12.

## Porting capsule

### Pattern

**One declaration wires both sides, at declaration time, with accessors on the
instance.**

1. Declaring a foreign key produces `belongs_to` on the declaring model and
   `has_many` on the referenced model, both as **instance accessors**, with no
   further call required.
2. The has-many name defaults to the **declaring** class lowercased plus `s`
   (`Post` -> `author.posts`), overridable by one named option (`related_name` /
   `relatedName`). Already correct in Python and Ruby; locked by the tests below.
3. **Reference the class, not a string,** where the language allows it. Python and
   Ruby already do; PHP can; Node's `references: "Author"` is a string because
   TypeScript's static-field ordering makes a class reference awkward - that is
   category 3 if and only if the registry then works, so keep the string but make
   registration automatic at first use rather than a documented manual step.
4. Eager loading takes the relationship name and returns the same shape in all
   four, and it is implemented as **one named function per relationship kind**
   (Ruby's `load_has_many` / `load_has_one` / `load_belongs_to`), not one method
   with a kind branch. That is the PHP `eagerLoad` 35 fix.

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| declare FK | `ForeignKeyField(to=Author, related_name=...)` | `foreignKeyField('author_id', Author::class)` | `foreign_key_field :author_id, references: Author` | `{type: "foreignKey", references: "Author", relatedName?}` |
| belongs-to accessor | `post.author` | `$post->author` | `post.author` | `post.author` |
| has-many accessor | `author.posts` | `$author->posts` | `author.posts` | `author.posts` |
| eager load | `find(id, include=["author"])` | `find($id, ["author"])` | `find(id, include: ["author"])` | `find(id, ["author"])` |

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (D1-D4, both Outstanding items closed).
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete (incl the N+1 assertion).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready; both Outstanding items closed by execution (2026-07-30). Corrected
picture: Python/Ruby auto-wire accessors correctly, PHP is imperative-only, Node is
serialize-only (`find(id, include).toDict(include)`) with a FALSE auto-wire doc, and
`has_many` silently caps at 100 in three of four. The IMPLEMENTATION is the build phase and
is NOT done. The 100-row cap must be settled jointly with Features 5 and 23, not here alone.
Decision-ready is not built.
