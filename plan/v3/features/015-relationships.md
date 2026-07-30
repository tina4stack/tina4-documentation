# Feature 15: Relationships (hasOne, hasMany, eager load)

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 3. **Planning only.**

**Status: CLOSED.** All four verified by execution. The Node outstanding item is
resolved (2026-07-30): relations are reachable but serialize-only, and `hasMany`
silently truncates at 100. See Outstanding below.

## Files

Relationships live in the ORM base class; measurements are feature 13's. The
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

## What differs

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

**D3. Four declaration styles for one concept** (carried from feature 13's D3):

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

## Outstanding: CLOSED by execution (2026-07-30)

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
same 100-row default cap as feature 4's open row-cap item and feature 18's page size,
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

## Verdict: PROVISIONAL - PROMOTE python/ruby on the wiring, ruby on the structure

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

## Pattern

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

## Methodology

1. Settle both Outstanding items. They decide whether this row is a two-framework
   port or a one-framework bug fix.
2. Write the tests below in all four; expect red on Node (both pairs) and unknown
   on PHP.
3. Split PHP's `eagerLoad` into the three named loaders, porting Ruby's shape.
   Behaviour-neutral, so it can land independently of the wiring question.
4. Fix Node's wiring to match the declaration-time contract, including automatic
   registration.
5. Re-measure: no relationship function above CC 12.

## Tests to write

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

## Risks

- **D2 may be a probe artifact.** Do not schedule Node work until Outstanding item 1
  is settled; the difference between "broken" and "different accessor" is the
  difference between a P1 and a rename.
- **The `eagerLoad` split is safe** and can proceed independently.
- **Making Node's registration automatic** may change model-load ordering. Register
  lazily at first relationship access rather than at class definition, which avoids
  the TypeScript static-ordering problem entirely.

## Parked

Not implemented. Sequenced after feature 13 (same file, same class) and behind its
Outstanding items. Order: 6, 4, 5, 3, 13, 14, 15, then 2, 1, 0.
