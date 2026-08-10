# Feature 082: GraphQL

## Identity and status

- Matrix identity: 82 - GraphQL
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the GraphQL engine in each repo) at Python
  `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No framework code changed.
- Dependencies: the ORM (for `from_orm` auto-schema), the router (for the HTTP endpoint, where mounted),
  the debug/log layer (error masking)
- Dependants: any app exposing a GraphQL API
- Existing ADRs: none specific to GraphQL; the depth-guard and error-masking follow the framework
  security posture (billion-laughs/DoS defence and no-internal-state-leak)
- Shared fixtures: NONE. `graphql_contract.json` is owed (no fixture, no CONTRACT-MAP row) - the
  engine is proven per-framework (Node has real no-mock depth/masking tests) but not by one oracle.
- Catalog phase: GraphQL

## Why this feature exists

An application needs a GraphQL API without a heavy dependency. Tina4 ships a hand-rolled,
ZERO-DEPENDENCY GraphQL engine (its own tokenizer + recursive-descent parser + executor) that builds a
schema from ORM models, executes queries and mutations with variables/fragments/aliases/directives,
guards against depth-based DoS, and never leaks internal state on a resolver error - the same way in
every language.

## Boundary

This feature owns the GraphQL ENGINE: the parser, the schema builder (`add_type`/`add_query`/
`add_mutation`/`from_orm`), the executor (variables, fragments, aliases, `@skip`/`@include`), the depth
guard, the resolver-error masking, and the ORM->GraphQL type mapping. The HTTP ENDPOINT (mounting a
`/graphql` route) is IN scope but is where the frameworks diverge (see the register/serve rows).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Hand-rolled zero-dep parser | yes | yes | yes | yes |
| Depth guard (over-deep + circular) | yes | yes | yes | yes (tested) |
| Resolver error masking (debug-gated) | yes | yes | yes | yes (tested) |
| Parse/outer error debug-gated | no | no | no | no |
| `from_orm` type + single + list + CRUD | yes | yes | yes | yes |
| Variables + defaults + `!` (arg-level) | yes | yes | yes | yes |
| Fragments named + inline; `@skip`/`@include` | yes | yes | yes | yes |
| ORM->GraphQL mapping source | field-object `.kind` | column-type string | field-type string | field-type string |
| Forces PK->ID on the object-type field | yes | yes | NO (keeps declared) | yes |
| JSON entry point | `execute_json` | absent (inline) | `handle_request` | absent (only `execute`) |
| Auto-mounts a `/graphql` route | NO (inert config) | yes (POST) | yes (POST+GET, GraphiQL) | NO (dead exports) |
| `TINA4_GRAPHQL_ENDPOINT`/`_AUTO_SCHEMA` wired | read but inert | wired | wired | DEAD (no runtime effect) |

The ENGINE and its SECURITY (depth guard, resolver masking) are at strong parity. The HTTP-serving
surface is a 2-2 split and the JSON-entry name is four-way divergent.

## Public surface contract

The engine: `add_type(name, fields)`, `add_query(name, args, return_type, resolver)`, `add_mutation(...)`,
`from_orm(model)` (builds a type, a single-by-ID query, a paginated list query, and create/update/
delete mutations), and `execute(query, variables, context) -> {data, errors}`. A JSON entry (execute a
JSON body to a JSON/string result) exists under three different names or not at all (GQL-02). The HTTP
endpoint (`/graphql`, `TINA4_GRAPHQL_ENDPOINT`) is auto-mounted in PHP/Ruby and absent in Python/Node
(GQL-01). Directives `@skip(if:)`/`@include(if:)` (plus bonus `@auth`/`@role`/`@guest`) gate selections.

## Inputs and outputs

- Input: a GraphQL query/mutation string, optional variables, optional context.
- Output: `{data, errors}` - `data` the resolved tree (aliases honoured), `errors` a list of
  `{message, path}`. A resolver error yields a masked message (the real cause only in debug) with the
  path preserved; a query exceeding `TINA4_GRAPHQL_MAX_DEPTH` (or a circular fragment) yields "Query
  exceeds maximum depth of N".
- `from_orm` input: an ORM model; output: the schema additions.

## Lifecycle and operation graph

1. PARSE: the hand-rolled tokenizer + recursive-descent parser turns the query into a document
   (operations, fragments, variables, directives).
2. VALIDATE/BIND: variables bind (with defaults); a required `!` argument is enforced at the argument
   layer.
3. EXECUTE: the executor walks the selection set, honouring `@skip`/`@include`, resolving fields (sync
   or async), recursing into nested objects/lists and fragments - incrementing the DEPTH counter at
   every selection/fragment-spread/inline hop.
4. GUARD: if the depth exceeds `TINA4_GRAPHQL_MAX_DEPTH`, the branch returns the depth error (this also
   terminates a circular fragment, since a cycle increments depth without bound).
5. MASK: a resolver exception is logged and returned as a masked error (real cause only in debug).

## Configuration and precedence

- `TINA4_GRAPHQL_MAX_DEPTH` (default 50; `<=0` disables) - WIRED and enforced in all four.
- `TINA4_DEBUG` - gates the resolver-error masking in all four.
- `TINA4_GRAPHQL_ENDPOINT` (default `/graphql`) and `TINA4_GRAPHQL_AUTO_SCHEMA` (default true) - WIRED in
  PHP/Ruby, but INERT in Python and DEAD in Node (read but never used, because those two do not mount a
  route). A documented env var that does nothing is a First-Principle violation (GQL-04).

## Failures, side effects and security

- DEPTH DoS is defended UNIFORMLY (the security core): a deeply-nested query or a circular fragment is
  rejected with "Query exceeds maximum depth of N" via a per-recursion depth counter (no visited-set,
  but the counter catches the cycle) - `TINA4_GRAPHQL_MAX_DEPTH` default 50. Node has real
  positive+negative tests (depth 51 rejected, circular fragment rejected, `<=0` disables).
- INTERNAL-STATE LEAK is defended UNIFORMLY: a resolver exception surfaces the real cause ONLY in debug
  (`TINA4_DEBUG`); production returns a generic "Internal server error" with the path preserved, and
  the real cause is logged. This holds in all four for RESOLVER errors.
- PARSE/OUTER ERRORS are NOT debug-gated in any framework (the tokenizer/executor catch returns the raw
  message). This is consistent across the four and defensible (a parser error is client-side syntax,
  not internal state), but a parse error can echo query fragments - worth a note (GQL-05).
- PUBLIC ENDPOINT: where mounted (PHP/Ruby), the `/graphql` route is deliberately public (`noAuth`/
  `auth:false`), with per-operation gating expected via the `@auth`/`@role`/`@guest` directives, not
  the router. Ruby's GraphiQL page loads React/GraphiQL from `unpkg.com` (an external CDN - an air-gap
  and supply-chain note).

## Wire and persistence contract

There is no persistence. The wire contract is the GraphQL request (query + variables) and the
`{data, errors}` response. Where an HTTP endpoint is mounted, it accepts a JSON body (PHP/Ruby POST,
Ruby also GET) at `TINA4_GRAPHQL_ENDPOINT`. The response shape (`data`, `errors` with `message`/`path`)
is uniform across the four engines.

## Providers and substitutability

The engine is self-contained (no external GraphQL library in any language). `from_orm` makes any ORM
model queryable; a resolver is a plain callable, so an app substitutes its own resolvers behind the
same schema surface.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| GQL-01 | The HTTP-serving surface is a 2-2 split: PHP (`register`, POST) and Ruby (`register_route`, POST+GET, GraphiQL) auto-mount a public `/graphql`; Python (`endpoint` inert config, manual wiring) and Node (`graphqlEndpoint`/`graphqlAutoSchemaEnabled` are DEAD exports, dev query path a stub) do NOT serve GraphQL over HTTP at all. | Pick ONE HTTP-serving model for all four: a `register()`/`register_route()` that mounts `/graphql`, wiring `TINA4_GRAPHQL_ENDPOINT`. Python and Node add it; PHP and Ruby align verbs and auth. |
| GQL-02 | The JSON entry point is four-way divergent: `execute_json` (Python), inline in `register` (PHP), `handle_request` (Ruby), absent (Node - only async `execute`). | Pin one name (`execute_json`, the documented cross-framework name); PHP/Node add it, Ruby renames `handle_request` (no alias). |
| GQL-03 | `TINA4_GRAPHQL_ENDPOINT` and `TINA4_GRAPHQL_AUTO_SCHEMA` are read but INERT in Python and DEAD in Node (no runtime effect), because neither mounts a route - documented env vars that do nothing. | Wire both in Python and Node (as part of GQL-01), or remove them (First-Principle: docs match code). |
| GQL-04 | Doc drift: the Python CLAUDE.md says the engine "serves HTTP at /graphql" (it does not - the endpoint is inert); the PHP docs imply GET/POST (POST only). | Fix the docs to match the code (once GQL-01 is settled, describe the real mounted surface). |
| GQL-05 | Ruby does NOT force PK->ID on the OBJECT-TYPE field (an already-typed `Int` PK stays `Int`); Python/PHP/Node force PK->ID. The mapping SOURCE also differs (Python field-object `.kind` vs the others' type string) - same result except the Ruby PK case. | Ruby forces PK->ID on the object-type field (match the three-majority); confirm the mapping source produces identical scalars. |
| GQL-06 | No `graphql_contract.json`; the engine is proven per-framework (Node has real depth/masking tests) but not by one shared oracle. Parse-error masking is ungated in all four (a note, not a break). | Add `graphql_contract.json` gating execution, the depth guard, error masking, directives, fragments and `from_orm`; decide whether parse errors are debug-gated. |

## Owner decisions

Proposed for owner ratification. The ENGINE and its security are settled parity; these are the open
calls, all on the HTTP-serving surface and the naming:

1. HTTP-SERVING MODEL (GQL-01, GQL-03): all four provide a `register()`/`register_route()` that mounts
   `/graphql`, wiring `TINA4_GRAPHQL_ENDPOINT`/`_AUTO_SCHEMA` (Python and Node add it; the dead exports
   become live). Recommend POST for mutations/queries and GET for queries (Ruby's model), and pin the
   auth default (public with `@auth` directives, or router-gated) uniformly.
2. JSON ENTRY NAME (GQL-02): pin `execute_json` in all four (PHP/Node add it; Ruby renames).
3. PK->ID (GQL-05): Ruby forces PK->ID on the object-type field, matching the three-majority.
4. DOCS (GQL-04): fix the "serves HTTP" claims once the model is unified.
5. FIXTURE (GQL-06): add `graphql_contract.json`; decide parse-error masking.

## Proposed conformance fixture

Add `graphql_contract.json` driving four runners against the engine (and the mounted endpoint once
unified): a query with variables/aliases/fragments returns the expected `{data}`; a depth-51 query and
a circular fragment both return "Query exceeds maximum depth of N"; a resolver throw returns a masked
"Internal server error" (real cause only under `TINA4_DEBUG`), path preserved; `@skip`/`@include` gate
a field; `from_orm` exposes a single query, a list query and the CRUD mutations; and (post-GQL-01) a
POST to `/graphql` executes and a GET serves a query. Node's existing real no-mock depth/masking tests
are the model - no doubles.

## Integration map

- `from_orm` reads ORM models; the executor calls resolvers; the depth guard and masking use the
  env/debug layer; the endpoint (once unified) uses the router.
- `graphql_contract.json` (owed) is the shared oracle.
- The GraphQL docs in each CLAUDE.md describe the surface; they must match the unified HTTP model
  (GQL-04).

## Breaking changes and migration

- GQL-01 adds a mounted `/graphql` to Python and Node (additive) and may change PHP's POST-only to
  POST+GET (additive) - no existing query breaks; a deployment gains the endpoint.
- GQL-02 renames Ruby's `handle_request` to `execute_json`: a Ruby app calling `handle_request` updates.
  `Breaking:` for Ruby.
- GQL-05 changes Ruby's object-type PK field from its declared scalar to `ID`: a client selecting the
  PK sees `ID` instead of `Int`. `Breaking:` for a Ruby GraphQL consumer.

## Implementation backlog

1. Add `graphql_contract.json` and wire four runners (GQL-06).
2. Unify the HTTP-serving model (GQL-01): Python/Node mount `/graphql` and wire the env vars; align
   PHP/Ruby verbs + auth.
3. Pin the JSON entry name (GQL-02) and force Ruby PK->ID (GQL-05); fix the docs (GQL-04).
4. Decide parse-error masking; run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a zero-dependency GraphQL engine: a hand-rolled tokenizer + recursive-descent parser
(operations, mutations, variables with defaults and `!`, named + inline fragments, aliases, directives,
list/non-null type refs); an executor that honours `@skip`/`@include`, resolves fields (sync or async),
recurses into objects/lists/fragments while incrementing a DEPTH counter, and rejects a query past
`TINA4_GRAPHQL_MAX_DEPTH` (default 50; also catching circular fragments); resolver-error masking that
logs the real cause and surfaces it only under `TINA4_DEBUG` (generic "Internal server error"
otherwise, path preserved); a `from_orm` that builds a type (PK->ID), a single-by-ID query, a paginated
list query, and create/update/delete mutations; an `execute_json` JSON entry; and a `register()` that
mounts `/graphql` (POST + GET), wiring `TINA4_GRAPHQL_ENDPOINT`/`_AUTO_SCHEMA`. Prove the port with the
fixture: execution, depth+circular rejection, masking, directives, fragments, `from_orm`, and the
mounted endpoint.

## Audit closure checklist

- [x] Boundary and public surface complete (engine + the HTTP endpoint divergence).
- [x] Lifecycle and every producer/consumer edge complete (parse/bind/execute/guard/mask).
- [x] Configuration, failure, side-effect and security rules complete (depth guard, masking, dead env vars).
- [x] Wire/storage and provider contracts complete (request/{data,errors}, endpoint where mounted).
- [x] Existing-language contradictions recorded (GQL-01..06; the engine is parity, the HTTP surface is split).
- [x] Owner ambiguities recorded (5 proposed; the HTTP-serving model and the JSON-entry name are key).
- [x] Proposed shared cases and mutation witnesses complete (`graphql_contract.json`, Node's tests the model).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
