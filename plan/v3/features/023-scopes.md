# Feature 023: ORM scopes

## Identity and status

- Matrix identity: 23 - ORM scopes
- Audit state: decision-ready
- Audit note: measured 2026-07-28 (all four from source, Python/Ruby by execution); prose
  sections completed from that evidence 2026-08-10. No framework code changed.
- Dependencies: Feature 17 ORM base class (scopes live there), Feature 6 query builder (a
  scope composes a `where`)
- Dependants: any model exposing a named, reusable filter; AutoCrud
- Existing ADRs: the removed `QueryBuilder#get` `LIMIT 100`; this feature surfaces the
  SYSTEMIC row-cap finding (five read paths, four silent defaults) that needs one dedicated
  cross-cutting ADR spanning Features 5, 21, 22, 23 and 24
- Shared fixtures: `scopes_contract.json` is required; its cases MUST use more rows than the
  cap so truncation is observable

## Why this feature exists

A developer registers a named, reusable filter on a model (`Item.scope("active", "state =
?", ["on"])`) and calls it by name (`Item.active()`), so a common WHERE clause is defined
once and read everywhere instead of being retyped.

## Boundary

This feature owns scope registration (`scope(name, filter_sql, params)`), scope invocation
(`Model.name(limit, offset)`), and the unknown-scope error. It DELEGATES the actual read to
`where` (Feature 6) and the model to Feature 17. The default-row-cap it exposes is one of five
inconsistent caps across the ORM and is settled once, not here alone.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Registration signature | `scope(name, filter_sql, params=None)` | `scope($name, $filterSql, $params=[])` | `scope(name, filter_sql, params=[])` | `static scope(name, filterSql, params?)` |
| Filtering correct | yes (verified) | yes (source) | yes (verified) | yes (source) |
| `limit`/`offset` reach `where` | YES | YES | NO (declared, dropped -- D1 bug) | YES |
| Default row cap from a scope | 20 | 20 | unbounded | 20 |
| Invocation mechanism | class-attr closure | `__callStatic` registry | `define_singleton_method` | function on class |
| Unknown-scope error | bare missing-attr | NAMED (`BadMethodCallException`, best) | bare missing-method | bare missing-attr |
| Registration site | class method | instance method writing static state (odd) | class method | static method |

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

`scope(name, filter_sql, params=[])` registers a named filter on the model (a class/static
method in all four). Invoking `Model.name(limit, offset)` runs the filter and returns the
matching rows. An unknown scope raises a named error identifying the scope and the model. The
registration signature is already identical across the four (the operation graph below); this
is the first feature in the audit whose public surface needs no reconciliation.

## Inputs and outputs

- Input to registration: a scope name, a filter SQL fragment (`state = ?`), and its bound
  params. Input to invocation: optional `limit` and `offset`.
- Output: the list of matching rows; `limit` and `offset` are HONORED (Ruby currently drops
  them -- D1).
- A scope over an unknown column raises loudly (Python verified), never returns an empty list.
- An unknown scope raises a named error, not a bare missing-method error.

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

Operation graph: `scope()` records the name, filter and params on the class. Invoking the
scope composes `where(filter_sql, params, limit, offset)` and returns the rows. An unknown
scope name resolves to the named error rather than a bare attribute/method miss.

## Configuration and precedence

- An explicit `limit`/`offset` at invocation must reach `where` (Ruby's D1 bug drops them).
- The default row cap when no limit is given is the SYSTEMIC decision below; it must be one
  number across all five ORM read paths, not four.
- There is no environment variable; scopes are declared in model code.

## Failures, side effects and security

- Ruby's scope declares `limit:`/`offset:` and silently discards them (D1). A declared-and-
  ignored keyword is worse than a missing one: a missing keyword raises so the caller learns,
  while a silent no-op lets the caller believe the cap applied.
- An unknown scope must raise a NAMED error identifying the scope and the model (PHP's
  `BadMethodCallException` is the reference); a bare missing-method error tells the developer
  nothing about scopes.
- A scope over an unknown column raises loudly, never returns an empty list.
- The filter SQL is developer-written and its params are bound, so there is no injection
  through a scope; the filter fragment itself is trusted model code.

## Wire and persistence contract

There is no persistence; a scope is a named `where`. The contract is the returned row set and
the honored `limit`/`offset`. The same scope over the same rows returns the same set in all
four, once the default cap is unified.

## Providers and substitutability

A scope composes a standard `where` through Feature 6, so it is engine-agnostic; any provider
satisfies it identically.

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

Proposed for owner ratification:

1. Fix Ruby's scope to pass `limit:`/`offset:` through to `where` (D1). One line, the
   highest-value change here, and safe: passing a declared parameter through cannot regress.
   It should NOT wait for the cap decision.
2. THE SYSTEMIC ROW-CAP DECISION (the cross-cutting call): the ORM has FIVE read paths with
   FOUR silent default caps -- `scope` (20 / unbounded), `has_many` (100 / unbounded),
   `QueryBuilder#get` (unbounded, its `LIMIT 100` was deliberately removed), `Model.where`
   (20 / nil), `Model.all` (100). Choose ONE rule for the whole ORM: either every read is
   genuinely unbounded with explicit opt-in pagination (matching the `QueryBuilder#get` fix),
   or every read caps at the same stated number. This warrants a DEDICATED ADR spanning
   Features 5, 21, 22, 23 and 24; it is breaking whichever way it goes, and a silent cap is
   the one behaviour a caller cannot detect without counting rows they do not have.
3. Promote PHP's named unknown-scope error to Python, Ruby and Node.
4. `scope()` is a class/static method in all four; PHP's instance declaration that writes
   static state becomes a proper static method.
5. Keep the registration surface as-is: it is already identical across the four.

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

- Feature 17's base model hosts scope registration and invocation; each scope composes a
  `where` through Feature 6.
- The systemic row-cap decision spans `scope` (23), `has_many` (21/22), `QueryBuilder#get`
  and `where`/`all` (5), and pagination (24); it is one dedicated ADR, one fixture assertion.
- AutoCrud may expose scopes; the docs describe the register-then-call pattern.
- Central fixtures, four runners and the CI matrix update together; the truncation cases must
  use more rows than the cap.

## Breaking changes and migration

- The default-row-cap unification (decision 2) is breaking whichever way it is decided:
  capping Ruby changes what its scopes return, uncapping the others changes what theirs
  return. One `Breaking:` entry, decided once for the whole systemic table.
- Ruby's D1 fix (pass `limit`/`offset` through) is a correctness fix; a caller that passed a
  limit now gets it honored.
- Making PHP's `scope()` static is a signature tidy that already behaves statically.

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

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (D1-D3 plus the systemic cap table).
- [x] Owner ambiguities recorded (5 proposed; the systemic cap needs a dedicated ADR).
- [x] Proposed shared cases and mutation witnesses complete (truncation cases use >cap rows).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready. The registration surface is already uniform. The work is D1 (Ruby drops
`limit`/`offset` -- a real bug, fix early and independently) and the SYSTEMIC row-cap decision
(five read paths, four silent defaults) that must be taken ONCE across Features 5, 21, 22, 23,
24 in a dedicated ADR. The IMPLEMENTATION is the build phase and is NOT done. Decision-ready is
not built.
