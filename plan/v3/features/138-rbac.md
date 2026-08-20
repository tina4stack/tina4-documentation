# Feature 138: RBAC (role/permission guards)

## Identity and status

- Matrix identity: 138 - RBAC (role-based access control)
- Audit state: decision-ready (greenfield - no existing implementation to audit)
- Audit note: measured 2026-08-19. NONE of the four frameworks ship a role or
  permission guard. All four have JWT auth (`Auth`) and a binary secured/noauth
  gate; authorization beyond "is authenticated" is hand-rolled per app as
  `@middleware` that reads a role claim. This feature makes that first-class.
- Dependencies: Auth (token signing + validation, feature family), the request
  (29), the secured/noauth gate, middleware dispatch.
- Dependants: AutoCrud (may gate actions by permission later), dev admin,
  any app with more than one class of user.
- Existing ADRs: ADR-0058 (claim-first role/permission guard).
- Catalog phase: Routing and middleware / Auth family
- Contract fixture: `fixtures/rbac_contract.json` (8 invariants, 13 cases, OWED).

## Why this feature exists

Tina4 authenticates and secures writes, but every app past the trivial has more
than one kind of user - admin, editor, viewer - and today each one rebuilds the
same middleware that reads a role and returns 403. That is the DRY promise failing
at the ecosystem level, for exactly the audience Tina4 courts (admin panels,
internal tools, CRUD/business apps). First-class `role()` / `can()` guards close
that gap with two decorators and zero configuration.

The audit questions this feature answers: is authorization claim-first (no DB
required), does it read only the verified payload, is the 401-vs-403 split
correct, and do the OR/AND and wildcard semantics mean the same thing in all four.

## Existing implementation evidence

Measured, all four: NONE.

- Python: `@get`/`@post` + `@secured`/`@noauth` in `tina4_python/core/router.py`;
  `Auth.authenticate_request` returns the verified payload. No `role`/`can`.
- PHP: `Router::get(...)->secure()` / `@secured`; `Auth::authenticateRequest`.
  No `role`/`can`.
- Ruby: `Tina4.get`/secured route block; `Tina4::Auth`. No `role`/`can`.
- Node: `Router.get(...).secure()`; `Auth`. No `role`/`can`.

So this is greenfield. There is no reference language to promote; the neutral
contract in `fixtures/rbac_contract.json` is authored from ADR-0058 first, then
implemented into all four (PORTING-FORMULA.md flow).

## The contract in one paragraph

Two guards read the VERIFIED JWT payload: `role(*names)` checks the `roles` claim
(a legacy singular `role` string is coerced to a one-element list), `can(*perms)`
checks the `permissions` claim. Multiple arguments are OR; require several by
stacking guards (AND). Granted permissions may wildcard on the dot boundary
(`posts.*` satisfies `posts.delete`; bare `*` satisfies everything); the required
permission is always concrete. A guarded route implies auth: no/invalid token ->
401; valid token lacking the role/permission -> 403; authorised -> the handler
runs. Roles and permissions are independent claims - the core never expands a role
into permissions. Nothing outside the signed token is trusted.

## Methodology (how to implement, per PORTING-FORMULA.md)

1. Read ADR-0058 and this contract. Do not read another framework's future
   implementation - implement from the neutral packet.
2. Add `role(...)` and `can(...)` in each framework beside the existing
   secured/noauth surface, keeping the language's own casing and call style
   (Python decorators, PHP chainable + docblock, Ruby block DSL, Node chainable).
3. Resolve the subject from the framework's OWN token validator
   (`Auth.validToken` / `authenticate_request`), never from a raw header.
4. Implement the guard as: authenticate first (401 on miss), then check
   roles/permissions with OR-within semantics and dot-segment wildcard matching on
   the granted side (403 on miss).
5. Write `tests/test_rbac.py` / `tests/RbacTest.php` / `spec/rbac_spec.rb` /
   `test/rbac.test.ts` with the case names in `rbac_contract.json`, each exercising
   REAL HS256 tokens minted by `Auth`, a REAL request through dispatch, NO mocks.
6. Prove each negative can fail (mint a token missing the role; assert 403 - then
   mutate the guard to a bare pass and watch the case go red).
7. Flip the fixture `status` owed -> proven per framework, run
   `scripts/audit-contract-fixtures.py`, and update the CONTRACT-MAP row from the
   counts. Ship `feature/release<ver>` -> `v3` -> tag, lockstep across all four
   (this is a parity feature, so all four move to the same version together).

## Tests to write (the answer key)

From `fixtures/rbac_contract.json` - 8 invariants, 13 cases, identical names in all
four suites:

- `rbac-role-allows` - role claim allows the route
- `rbac-role-denies-403` - missing role is forbidden 403
- `rbac-unauthenticated-401` - unauthenticated guard is 401
- `rbac-role-or-and` - role list is any of; stacked guards are all of
- `rbac-can-permission` - permission grants the route; missing permission is
  forbidden 403; role alone does not satisfy a permission guard
- `rbac-wildcard-grant` - wildcard permission grants within scope; superuser star
  grants everything; wildcard does not cross scope
- `rbac-verified-payload-only` - spoofed role header is ignored
- `rbac-legacy-singular-role` - legacy singular role is coerced

## Out of scope (deferred)

Policy objects, resource ownership, ABAC attribute rules, role hierarchies, and
role-to-permission expansion in the core. All are reachable today with `@middleware`
and are revisited only on real demand. See ADR-0058 "Out of scope".
