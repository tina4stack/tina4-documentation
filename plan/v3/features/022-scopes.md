# Feature 022: ORM scopes

## Identity and status

- Matrix identity: 22 — ORM scopes
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: not yet extracted from the retained audit evidence
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: see retained evidence and the central decision index
- Shared fixtures: not yet confirmed

## Why this feature exists

The retained audit does not yet state the developer problem in one language-neutral sentence.

## Boundary

The retained audit does not yet separate what this feature owns, delegates, and excludes.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 4. **Planning only.**

**Status: CLOSED.** All four read from source; Python and Ruby verified by execution.

### Files

Scopes live in the ORM base class; measurements are feature 16's.

### Behaviour: Python and Ruby verified working

Three rows (`on`, `off`, `on`), a scope registered on `state = ?`:

| | registered as a callable? | scope call | rows | bad SQL |
| --- | --- | --- | --- | --- |
| python | yes | `Item.active()` | 2 (`a`, `c`) | raises `OperationalError` |
| ruby | yes | `Item.active` | 2 (`a`, `c`) | not probed |

Both filter correctly and Python fails loud on an unresolvable column.

## Public surface contract

The audit has not yet extracted a language-neutral public surface and its idiomatic spellings.

## Inputs and outputs

The audit has not yet fixed all native types, defaults, nullability, ordering, and serialized shapes.

## Lifecycle and operation graph

### The registration signature agrees in all four

| | signature |
| --- | --- |
| python | `scope(cls, name: str, filter_sql: str, params: list = None) -> None` |
| php | `scope(string $name, string $filterSql, array $params = []): void` |
| ruby | `scope(name, filter_sql, params = [])` |
| node | `static scope(name: string, filterSql: string, params?: unknown[]): void` |

Same name, same argument order, same return. This is the first row in the audit
where the surface needs no reconciliation at all.

## Configuration and precedence

The audit has not yet fixed argument, environment, project-file, default, and cache timing precedence.

## Failures, side effects and security

The audit has not yet closed every failure boundary, side effect, cleanup rule, and security concern.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

## Providers and substitutability

The audit has not yet proved provider substitution or recorded deliberate capability exceptions.

## Contradictions and defects

### What differs

**D1 (BUG, Ruby). A scope accepts `limit:` and `offset:` and silently discards
them.** Read from source:

```ruby
def scope(name, filter_sql, params = [])
  define_singleton_method(name) do |limit: 20, offset: 0|
    where(filter_sql, params)          # <- limit and offset are NEVER PASSED
  end
end
```

The block declares both keywords, defaults them to 20 and 0, and then calls
`where` with neither. Against the other three, which all pass them through:

```
python  cls.where(filter_sql, params, limit=limit, offset=offset)          passes both
php     ->where($scope['filter'], $scope['params'], $limit, $offset)        passes both
node    ModelClass.where.call(ModelClass, filterSql, params, limit, offset) passes both
ruby    where(filter_sql, params)                                          DROPS both
```

So `Item.active(limit: 5)` on Ruby accepts the argument, returns more than five
rows, and reports nothing. A silent no-op parameter is worse than a missing one: a
missing keyword raises, so the caller learns; a declared-and-ignored keyword lets
the caller believe the cap applied.

**D2. The default row cap differs, and Ruby's is unbounded.** Ruby's
`where(conditions, params = [], limit: nil, ...)` defaults `limit: nil`, meaning no
limit. Combined with D1, the observable behaviour is:

| | default rows from a scope |
| --- | --- |
| python | **20** |
| php | **20** |
| node | **20** |
| ruby | **unbounded** |

Three frameworks silently return the first 20 matching rows. Ruby returns all of
them. Both behaviours are defensible; having both is not. A developer who tests a
scope on Ruby against 50 rows and ships the same scope on Python gets 20.

**D3. The invocation mechanism differs, and one of them is category 3.**

| framework | mechanism |
| --- | --- |
| python | generates a closure and assigns it as a class attribute |
| ruby | `define_singleton_method` |
| node | assigns a function onto the class object |
| php | writes to `static::$_scopes`, dispatched by `__callStatic` |

The first three are the same idea in three idioms - category 3, absorbed. PHP's
registry-plus-magic-dispatch is different in kind, and it earns its difference:
`__callStatic` throws `BadMethodCallException("Scope 'x' is not defined on ...")`
for an unknown scope, which is a **better error than the other three give**. In
Python, Node and Ruby an unregistered scope is a plain missing-attribute or
missing-method error with no mention of scopes.

Also worth noting: PHP declares `scope()` as an **instance** method that writes
static state. It works (the static array is shared), but it reads as an accident -
registering a class-level filter through an instance.

### The systemic finding: three different silent row caps

This row plus feature 20 plus a prior fix make a pattern the audit should name.
"Give me some related or filtered rows" currently caps at:

| path | default cap |
| --- | --- |
| `scope()` | **20** (python, php, node) / unbounded (ruby) |
| `has_many()` | **100** (python, php) / unbounded (ruby DSL) |
| `QueryBuilder#get` | unbounded - the `LIMIT 100` was **deliberately removed** |
| `Model.where` | 20 (python/php/node) / nil (ruby) |
| `Model.all` | 100 (python) |

Five read paths, four different defaults, and one of them was already fixed once by
removing its cap. Every one of these truncates silently. That is not four bugs; it
is a missing decision about what a default read returns, applied inconsistently
five times.

**Recommendation, and it needs the owner's call:** one rule for the whole ORM.
Either every unbounded-looking read is genuinely unbounded (and pagination is
explicit and opt-in), or every one caps at the same number and says so. The
`QueryBuilder#get` fix already chose unbounded for one path; the argument for
matching it everywhere is that a silent cap is the one behaviour a caller cannot
detect without counting rows they do not have.

### Verdict: SYNTHESISE

Decided on **correctness** for D1, then consistency for D2.

The registration surface is already uniform and needs nothing. Python, PHP and Node
have the correct pass-through; Ruby has the bug. PHP has the best unknown-scope
error and the oddest registration site. So: Python's pass-through, PHP's error
message, and one agreed default cap.

All category 4. Nothing here is runtime-forced.

### Risks

- **D2's decision is breaking whichever way it goes.** Capping Ruby changes what
  existing scopes return; uncapping the other three changes what theirs return. It
  needs a `Breaking:` entry and it should be decided once for the whole systemic
  table rather than per feature.
- **Ruby's D1 fix is safe and should not wait** for the cap decision. Passing a
  declared parameter through cannot be a regression.

## Owner decisions

No new owner decision is recorded in this migrated section. Retained decisions appear below when present.

## Proposed conformance fixture

### Tests to write

Real SQLite, more rows than the cap so truncation is observable - that is the point.

| pair | positive | negative |
| --- | --- | --- |
| filtering | `a_registered_scope_returns_only_matching_rows` | `a_scope_does_not_return_non_matching_rows` |
| limit pass-through | `a_scope_honours_an_explicit_limit` - 30 rows, `limit: 5`, expect 5 | `a_scope_does_not_ignore_the_limit_it_accepts` - the exact Ruby reproduction |
| offset pass-through | `a_scope_honours_an_explicit_offset` | `a_scope_does_not_ignore_the_offset_it_accepts` |
| default cap | `a_scope_with_no_limit_returns_the_agreed_default` - 30 rows, one asserted number in all four | `no_framework_returns_a_different_default_row_count` |
| unknown scope | `an_unknown_scope_raises_an_error_naming_the_scope_and_the_model` | `an_unknown_scope_does_not_raise_a_bare_missing_method_error` |
| bad SQL | `a_scope_over_an_unknown_column_raises` | `a_scope_over_an_unknown_column_does_not_return_an_empty_list` |
| registration site | `scope_is_callable_on_the_class_without_an_instance` | `scope_registration_does_not_require_constructing_a_model` - PHP reproduction |
| systemic | `every_orm_read_path_shares_one_default_row_cap` | `no_read_path_truncates_without_saying_so` |

The limit pass-through pair needs **more rows than the cap**. A scope test over
three rows passes on Ruby today despite the bug, which is exactly why nothing caught
it - my own first probe returned 2 rows and looked fine.

## Integration map

The audit has not yet mapped every export, startup path, request hook, CLI, scaffolder, status command, document, and generated consumer.

## Breaking changes and migration

The audit has not yet turned every parity break into an actionable pre-3.14 migration instruction.

## Implementation backlog

### Methodology

1. Write the tests below in all four. Expect red: Ruby on the limit pass-through,
   three frameworks on the unknown-scope error message, and all four on whichever
   default-cap decision is taken.
2. Fix Ruby's `define_singleton_method` body to pass `limit:` and `offset:`. One
   line, and the highest-value change in this row.
3. Promote PHP's unknown-scope error to the other three.
4. Make PHP's `scope()` static.
5. Apply the agreed default cap - and do it across every path in the systemic table,
   not just scopes, or the inconsistency simply moves.

## Porting capsule

### Pattern

1. **A scope's `limit` and `offset` reach `where`.** Ruby passes them.
2. **An unknown scope raises a named error naming the scope and the model**, in all
   four - PHP's message promoted.
3. **`scope()` is a class/static method in all four.** PHP's instance declaration
   becomes static; it already behaves statically.
4. **One default row cap across every ORM read path** (the systemic finding above),
   whatever the owner decides it is.

Surface table - unchanged, because it is already right:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| register | `Model.scope(name, filter_sql, params=None)` | `Model::scope($name, $filterSql, $params = [])` | `Model.scope(name, filter_sql, params = [])` | `Model.scope(name, filterSql, params?)` |
| invoke | `Model.name(limit=20, offset=0)` | `Model::name($limit, $offset)` | `Model.name(limit: 20, offset: 0)` | `Model.name(limit, offset)` |

## Audit closure checklist

- [ ] Boundary and public surface complete.
- [ ] Lifecycle and every producer/consumer edge complete.
- [ ] Configuration, failure, side-effect and security rules complete.
- [ ] Wire/storage and provider contracts complete.
- [ ] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.
- [ ] Proposed shared cases and mutation witnesses complete.
- [ ] Integration map and breaking migrations complete.
- [ ] Implementation backlog dependency-ordered.
- [ ] Porting capsule is clean-room sufficient.

### Parked

Not implemented. The Ruby one-line fix (D1) can go early and independently; the cap
decision (D2) blocks on the owner and should be taken once across every path in the
systemic table. Order: 6, 4, 5, 3, 13, 14, 15, 16, then 2, 1, 0.
