# Feature 103: Live framework and application API index

## Identity and status

- Matrix identity: 103 - Live framework and application API index (the reflection/structural index behind
  the `api_search` / `api_class` / `api_method` dev tools)
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-11 at Python `docs.py` (907), PHP
  `Tina4/Docs.php` (1324), Ruby `lib/tina4/docs.rb` (699), Node `packages/core/src/docs.ts` (1298). The
  security finding API-01 was self-verified against the Python dispatch and gate code (the five
  `_api_docs_*` handlers call no authorization gate; every `_api_mcp_*` handler calls
  `_mcp_request_allowed`). Suites are reported, not re-run.
- Dependencies: the dev MCP server + its two-layer gate (feature 101); the dev-admin HTTP surface
  (`/__dev/api/docs/*`). Sibling of the Context FTS index (feature 102).
- Dependants: the `api_search` / `api_class` / `api_method` MCP tools; the `/__dev/api/docs/*` REST
  mirror; the `.well-known.json` discovery document; the drift/sync doc helpers.
- Existing ADRs: none. Spec doc: `plan/v3/22-LIVE-API-RAG.md`.
- Shared fixtures: NONE. `docs_contract.json` is owed (API-07). Each language has a real, no-mock suite
  (Python 20, PHP 19, Ruby 20, Node 20) whose headers state explicit parity intent ("mirrors
  DocsTest.php", same test names), yet the return shapes demonstrably drift (API-02) and no shared
  oracle enforces them.

- Catalog phase: Developer integrations

## Why this feature exists

The live API index answers "what does the code actually expose right now?" with an authoritative,
structural reply. It walks the running framework and the user's `src/` tree, extracts every class,
method, and function with its signature, file, and line, and serves ranked lookups through the
`api_search` / `api_class` / `api_method` dev tools. An AI assistant or a developer verifies a
signature against code reality instead of guessing it, which is the runtime counterpart to the static
doc-drift guard.

It is the EXACT/structural half of a pair. Context (feature 102) is the fuzzy FTS half: `code_search`
answers "where is X done in this codebase?"; `api_*` answers "what is the exact signature of X?". The
two share no code and different storage, and every language documents the split in a docblock next to
the tool registration.

## Boundary

This packet owns the `Docs` class in each language: the source/reflection index build, the
`search` / `class_spec` / `method_spec` / `index` query surface, the static MCP mirrors, and the
drift/sync markdown helpers. It owns the `api_search` / `api_class` / `api_method` MCP tools and the
`/__dev/api/docs/*` REST mirror that wrap it.

It does NOT own: the Context FTS index or `code_search` (feature 102); the dev MCP server, its
transport, or its authorization gate (feature 101); the `docs_search` / `docs_list` / `docs_section`
tools, which grep bundled prose markdown and never touch the `Docs` index (see API-06). `Docs` is a
callee of the MCP and dev-admin layers.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | `docs.py:559` class `Docs` | `Tina4/Docs.php:33` class `Docs` | `lib/tina4/docs.rb:20` class `Tina4::Docs` | `packages/core/src/docs.ts:875` class `Docs` |
| Index mechanism | framework via `inspect` reflection + `pkgutil` walk; user via `ast` parse (no import) | `token_get_all` + hand walk (both halves) | regex line-scan "AST-lite" (both halves) | hand-rolled regex/char scanner `parseTypeScript` (both halves) |
| Reflects framework + user | tina4_python.* + src/{orm,routes,app,services} | Tina4/ + vendor/tina4stack/* + src/{orm,routes,app,services} | lib/tina4/ + src/{orm,routes,app,services} | packages/{core,orm,swagger,frond}/src + src/{orm,routes,app,services,models} |
| MCP tools | `api_search`/`api_class`/`api_method` (tools.py) | same (MCP.php:1990-2005) | same (mcp.rb:1341-1353) | same (mcp.ts:2094-2156) |
| REST mirror | `/__dev/api/docs/*` (dev_admin:528-532) | `/__dev/api/docs/*` (DevAdmin.php:2497-2543) | `/__dev/api/docs/*` (dev_admin.rb:717-726) | `/__dev/api/docs/*` (devAdmin.ts:614-618) |
| Focused tests | `tests/test_docs.py` 20 real | `tests/DocsTest.php` 19 real | `spec/docs_spec.rb` 20 real | `test/docs.test.ts` 20 real |

## Public surface contract

Same surface across all four, spelled idiomatically:

- Constructor `Docs(project_root)`.
- `search(query, k = 5, source = "all", include_private = false)` - ranked hits; `source` is one of
  `all` / `framework` / `user` (all excludes vendor).
- `class_spec(fqn)` (`classSpec`) - a class plus its public methods, or null.
- `method_spec(class_fqn, method)` (`methodSpec`) - one method, or null.
- `index()` - a flat list of every entity.
- Static MCP mirrors `mcp_search` / `mcp_method` / `mcp_class` (route through a per-root instance cache),
  and drift helpers `check_docs` / `sync_docs` (not exposed as MCP tools).

The three MCP tools are `api_search(query, k, source, include_private)`, `api_class(name)`, and
`api_method(class, method)`. The REST mirror exposes the same four queries plus a `.well-known.json`
discovery document.

## Inputs and outputs

- `search` input: a query string, `k`, a source filter, and an `include_private` flag. Output: a ranked
  list of hits.
- `class_spec` / `method_spec` input: a class FQN (and method name). Output: a spec object or null.
- The hit and spec shapes DIFFER across the four languages (API-02). The common core of a hit is
  `fqn, kind, name, signature, summary, file, line, version, source, score, visibility`. Python stops
  there; Node adds optional `class` / `static`; Ruby adds `class` / `static`; PHP adds `docblock` plus
  `class` / `static`. `method_spec` diverges the same way: Python returns a lean object using
  `docstring` and omitting `class` / `params` / `return`, while PHP, Ruby, and Node return `class`,
  `docblock`, and permanently-empty `params: []` / `return: ""`. `class_spec` includes a `properties`
  key in PHP / Ruby / Node (always empty) and omits it in Python.
- Ordering is identical everywhere: score descending, FQN ascending as the tie-break, zero-score entries
  dropped, top-k returned.

## Lifecycle and operation graph

1. A query constructs or reuses a `Docs` for the project root.
2. `ensure_index` builds two maps: a framework index and a user index. The framework index is built once
   (Python/PHP/Node refresh it on a max-mtime change; Ruby never invalidates it for the instance's
   life). The user index is rebuilt whenever the max mtime under the user dirs changes.
3. Framework discovery differs by language: Python imports each `tina4_python.*` module and reflects it
   with `inspect`; PHP tokenizes each `.php` file; Ruby regex-scans each `.rb`; Node regex-scans each
   `.ts`. User discovery never imports the user's code in any language (Python uses `ast`, the rest
   parse source) so an unresolved user import cannot break the index.
4. `search` tokenizes the query, scores every entity, sorts, and returns the top k.
5. The index is served through two surfaces: the gated MCP tools and the ungated REST mirror.

The reflection index is never refreshed by the dev-reload hook in any language (API-05); only the
Context FTS index is kept live on save. Freshness of `api_*` relies purely on the per-query mtime check.

## Configuration and precedence

The `Docs` module reads NO environment variables in any language. User dirs, framework roots, chunk
knobs, and ranking weights are all constants. Version comes from the framework version constant.

Exposure is gated entirely by the surrounding layers: `TINA4_DEBUG` (mounts the whole dev surface and is
the default for MCP capability), `TINA4_MCP` (explicit MCP on/off), `TINA4_MCP_REMOTE` (allow a remote
MCP caller), and `TINA4_MCP_TOKEN` (fallback `TINA4_API_KEY`) for the remote token. These gate the MCP
tools. They do NOT gate the REST mirror (API-01).

## Failures, side effects and security

- API-01 (security, self-verified): the `/__dev/api/docs/{search,class,method,index}` REST routes reach
  `Docs` with NO authorization gate in all four languages - only `TINA4_DEBUG` mounts them - while the
  identical MCP `api_*` tools require the two-layer gate. On a `TINA4_DEBUG=true` server bound to a
  routable interface, a remote unauthenticated caller reads the entire reflected framework and
  application index (class and method signatures, file and line, docstrings), can pass
  `include_private=true` to surface private members, and sees any secret hard-coded as a default
  argument. This is the same class of gap as MCP-02, read-only rather than tool-execution.
- Default-argument leakage: signatures render literal default values in all four; a secret in a default
  argument under `src/` is emitted verbatim. Not redacted anywhere. Folds into the API-01 disclosure.
- Unknown class or method: clean null in all four, wrapped to a 404 or an `{error}` object; no stack
  traces.
- Query strings are safe: the query is only tokenized and substring-matched; it never reaches SQL, a
  shell, `eval`, or a compiled regex, so there is no injection or ReDoS surface.
- Import-time failures are swallowed per module (Python), and unreadable or oversized files are skipped
  (PHP and Node cap at 1 MB), so a broken file drops from the index rather than erroring.

## Wire and persistence contract

There is NO persistence. The index lives only in memory (Python `_Entity` objects, PHP/Node maps and
arrays, Ruby arrays). There is no file and no SQLite - the deliberate contrast with Context (feature
102), which persists to `.tina4/context.db`. A per-root instance cache keeps one `Docs` warm per project
root (Ruby and Node reuse it for MCP calls; Python and PHP construct a fresh `Docs` on every MCP `api_*`
call, re-walking the framework each time - API-04).

The wire shape is the JSON returned by the MCP tools and the REST mirror, and it is NOT identical across
the four languages (API-02). The `.well-known.json` document advertises the tool names.

## Providers and substitutability

There is no external provider. The index is built from the language's own source-reading or reflection
primitives, all first-party. The mechanism is the substitution axis, and it is NOT uniform: Python uses
runtime `inspect` reflection for the framework half; PHP, Ruby, and Node parse source. All four converge
on "do not import user code", which is why even the reflection-capable languages parse the user tree
rather than loading it. No dependency is added in any language.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| API-01 | SECURITY (self-verified, all four). The `/__dev/api/docs/{search,class,method,index}` REST routes expose the full reflected framework + application index with NO authorization gate - only `TINA4_DEBUG` - while the identical MCP `api_*` tools require the two-layer gate. Remote unauthenticated read (incl. private members via `include_private`, and default-argument secrets) on a `TINA4_DEBUG=true` server bound to `0.0.0.0`. Same class as MCP-02, read-only. | OWNER DECISION (API-DEC-01). Recommendation: gate the REST routes with the same `_mcp_request_allowed` check the MCP endpoints use (cheapest, closes the hole, keeps the local-dashboard convenience), OR remove the REST mirror entirely since the MCP tools cover the surface. Add a red-before-green regression in all four: a non-loopback peer with no token gets 404 from `/__dev/api/docs/search`. Analogous to the MCP-02 fix. |
| API-02 | Return-shape drift + overstated contract. The `search` hit, `class_spec`, and `method_spec` shapes are NOT identical across the four (Python is lean and uses `docstring`; PHP/Ruby/Node add `class` / `static` / `docblock` and permanently-empty `params: []` / `return: ""` / `properties: []`). No language populates structured params, return type, or properties, yet the tool description and the CLAUDE.md contract promise "signature, params, return type". | OWNER DECISION (API-DEC-02). Recommendation: define one canonical hit / class_spec / method_spec shape in `docs_contract.json` and normalize all four to it. Remove the vestigial `params` / `return` / `properties` stubs (the `signature` string already carries params and return) and correct the tool description + CLAUDE.md, rather than build 4x structured extraction for marginal value. |
| API-03 | Comment drift + dead code. Ruby's header claims "class introspection where safe" but the implementation is 100% regex; PHP's header claims "reflection-backed / Stdlib reflection only" but the live path is `token_get_all` with a full ReflectionClass helper chain that is DEAD (unreachable); Python's tool description overstates params/return; Python has dead `_path_source_tag` / `_safe_signature`; the `vendor` source tag is produced by NO language. | Correct the three headers/descriptions to say "source parse" where that is the truth, and DELETE the dead reflection chain (PHP), the dead helpers (Python), and the never-produced `vendor` branch. Zero dead code. |
| API-04 | Mechanism and caching divergence. Mechanism: Python `inspect` + `ast`, PHP `token_get_all`, Ruby regex, Node regex scanner. Caching: Ruby never invalidates the framework index; Ruby and Node keep a warm per-root instance, but Python and PHP construct a fresh `Docs` on every MCP `api_*` call, re-walking the whole framework each time (cold, and the sub-50ms test warms the instance first so it hides this). | OWNER DECISION (API-DEC-03). Recommendation: standardize on a warm per-root cache for the MCP path in all four (fix the Python/PHP cold-per-call), and pick one framework-index invalidation policy (mtime, matching Python/PHP/Node; fix Ruby's build-once). The mechanism difference is acceptable if the output shape is normalized (API-02). |
| API-05 | The dev-reload hook refreshes the Context FTS index but never the reflection index, in any language. After editing a framework file, `api_*` is stale until a cache reset, a new process, or a user-dir mtime bump. | Low priority. Either wire the reload hook to also invalidate the `Docs` framework cache, or document that `api_*` framework freshness is mtime-lazy. Record the decision in the ADR. |
| API-06 | Naming/boundary: the tool named `docs_search` is a case-insensitive substring scan over bundled prose markdown (`CLAUDE.md`, `AGENTS.md`, `CONVENTIONS.md`, `README.md`), NOT the reflection index and NOT tina4.com. Consistent across all four. | No action beyond documentation. Note the three-way split clearly in the docs page: `api_*` = reflection, `code_search` = project FTS (feature 102), `docs_search` = bundled-prose grep. It is arguably its own small feature bundled under the dev tools. |
| API-07 | No `docs_contract.json`, no CONTRACT-MAP row, no ADR. Four real suites with explicit parity intent ("mirrors DocsTest.php") but demonstrable shape drift and no shared oracle; no test asserts the (never-populated) params/return. | Add `docs_contract.json` (below) and the first Docs ADR ratifying the canonical shape, the source-parse mechanism, and the gate decision. |
| API-08 | `USER_DIRS` drift: Python, PHP, and Ruby index `src/{orm,routes,app,services}`; Node also indexes `src/models`. | Low priority. Add `models` to the other three for symmetry (harmless when the dir is absent), or confirm Node-only. Fold into API-DEC-02's normalization. |

## Owner decisions

- API-DEC-01 (proposed, SECURITY): gate `/__dev/api/docs/*` with the same request-authorization check as
  the MCP endpoints, OR remove the REST mirror. Recommendation: gate. Ship with a red-before-green
  regression in all four (remote peer, no token, gets 404). This is the API-01 fix and it is the same
  pattern as the shipped MCP-02 fix.
- API-DEC-02 (proposed): ratify one canonical hit / class_spec / method_spec shape; remove the vestigial
  `params` / `return` / `properties` stubs and correct the tool description + CLAUDE.md; unify
  `USER_DIRS` (API-08).
- API-DEC-03 (proposed): standardize the MCP-path cache (warm per-root everywhere) and the framework
  invalidation policy (mtime); decide the dev-reload refresh question (API-05).
- API-DEC-04 (proposed): delete the dead code (PHP reflection chain, Python helpers, the never-produced
  `vendor` branch) and correct the headers (API-03).

## Proposed conformance fixture

`docs_contract.json` - the same fixture project (a known framework class plus a user model with a public
and a private method) drives a runner in each language against a real build (no mocks). Cases:

- Positive: `search` for a framework symbol returns it with the canonical hit shape; every hit has
  exactly the ratified key set.
- Positive: `class_spec` for a known class returns its public methods, each with signature / file /
  line; unknown class returns null.
- Positive: `method_spec` returns the canonical method shape; assert whether `params` / `return` are
  populated or absent per API-DEC-02 (this case is the missing test today).
- Shape identity: the key set of a hit, a class_spec, and a method_spec is byte-identical across all
  four languages.
- Ranking: a definition out-ranks a mention; a `Class.method` query ranks the owning method first.
- Freshness: add a method to a user file, bump mtime, assert it appears on the next query.
- Private: excluded by default; surfaced only with `include_private=true`.
- API-01 witness: a request to `/__dev/api/docs/search` from a non-loopback peer with no token returns
  404 (fails on all four today until API-DEC-01 ships).
- Safety: a query with FTS-style metacharacters or a path returns without error and touches no file.
- Mutation witnesses: dropping the private filter surfaces `_private`; removing the gate (once added)
  re-serves remotely.

## Integration map

- Exports: each language exports `Docs` (Node also the TS types). The MCP tools `api_search` /
  `api_class` / `api_method` are registered in the same `register_dev_tools` call as `code_search` and
  `docs_search`.
- MCP surface: gated by the two-layer MCP gate (feature 101), mounted at `/__dev/mcp`.
- REST surface: `/__dev/api/docs/{search,class,method,index,.well-known.json}`, gated by `TINA4_DEBUG`
  only (API-01).
- Startup / request lifecycle / CLI: no caller. The index is built lazily on the first query.
- Dev-reload: refreshes Context, not `Docs` (API-05).
- Documentation: `docs/{python,php,ruby,nodejs}/28-mcp-dev-tools.md` and `29-custom-mcp-servers.md`
  describe the tools; the params/return claim there and in CLAUDE.md needs the API-DEC-02 correction.

## Breaking changes and migration

- API-DEC-01 (gate the REST routes): a remote caller currently reading `/__dev/api/docs/*` without a
  token would start getting 404. That is the point; the dev surface is debug-only, so no production
  consumer breaks. Ship with the regression.
- API-DEC-02 (normalize shapes, drop `params`/`return`/`properties`): a consumer reading the empty
  `params: []` / `return: ""` keys would lose them. They carry no information today, so the migration is
  "read params/return from the `signature` string" - document it. The added/renamed keys (aligning
  `docstring` vs `docblock`, `class`, `static`) are the normalization; pick one spelling and note it as
  a breaking contract change with a migration line.
- No persistence exists, so there is no stored-format migration.

## Implementation backlog

Dependency-ordered:

1. API-DEC-01: gate `/__dev/api/docs/*` in all four (or remove it), with a red-before-green regression.
   This is the security fix and comes first.
2. Write the first Docs ADR (canonical shape, source-parse mechanism, gate decision, dead-code removal).
3. API-DEC-02 + API-08: normalize the hit / class_spec / method_spec shapes and `USER_DIRS`; remove the
   vestigial stubs; correct the tool description, `28-mcp-dev-tools.md`, and CLAUDE.md.
4. Author `docs_contract.json` and a runner per language; flip owed to proven; add the CONTRACT-MAP row.
5. API-DEC-03: standardize the MCP-path cache and the framework invalidation policy.
6. API-DEC-04: delete the dead reflection/helper code and fix the headers.

## Porting capsule

A clean-room implementation needs: the `Docs` surface above; a framework walk (reflection or source
parse) restricted to the framework packages; a user walk over `src/{orm,routes,app,services}` (plus
`models`) that NEVER imports user code; per-entity capture of fqn / kind / name / signature (params and
return rendered into one string) / summary / docstring / file / line / visibility / static / source; the
additive ranking (exact name +5, name prefix +3, summary +2, docstring +1, `Class.method` +6,
owning-class +2.5, fqn-segment +1, substring fallback, user-source x1.2; score desc, fqn asc; drop
zero); a two-tier in-memory cache (framework once/mtime, user mtime) keyed per project root; the MCP
tools and the REST mirror BOTH behind the two-layer gate; and null-not-throw on unknown lookups. The
canonical return shape is defined by `docs_contract.json`. This packet is sufficient for a clean-room
implementation.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
