# tina4-go: a scoping and feasibility study

> Status: scoping + feasibility spike COMPLETE, 2026-10-01. This is NOT a build. It
> is the honest verdict on whether a fifth Tina4 framework in Go is tractable, the
> real forks it introduces, and a phased roadmap with measured estimates. The five
> load-bearing decisions (ADR-0089 through ADR-0092, plus the PBKDF2 call) are now
> SETTLED - all Accepted - so Phase 0 is unblocked. See "Decisions (settled)" at the
> end; the roadmap below is ready to execute on the maintainer's go-ahead to build.

## The verdict

A Go port is feasible, and the reason it is feasible is the thing most ports never
have: an executable specification that already exists. Tina4's behaviour doesn't
live in prose that a new language would have to interpret. It lives in 72 contract
fixtures under `plan/v3/fixtures/*_contract.json`, each one a set of invariants that
a named test proves in Python, PHP, Ruby and Node. The auditor
`scripts/audit-contract-fixtures.py` reads those fixtures and, for every invariant,
walks each language's `suites` map and checks the named test still carries the named
case. Add a fifth key to that map - `go` - and the same auditor will hold a Go
framework to the same contract it holds the other four to, with no new checker to
write.

So the question a Go port has to answer is narrow and testable. Not "is this like
Tina4?" but "does the `go` column go green?" A fixture is the oracle, red before
green is the proof, and the spike below shows a Go program reading the real fixtures
and running one invariant against a Go stub today.

The honest caveat sits next to the verdict. Feasible isn't cheap. The four
frameworks are the work of months, and a fifth is a fresh framework, not a
translation - the contract tells you what to build, never how to build it in Go.
Three forks are genuinely new and the biggest one, the compiled server, touches the
developer's daily loop. Those forks are the real content of this document.

## What stays byte-identical, and what becomes Go

The parity mandate is the spine. Everything a developer or a client SEES stays
literally identical across the five frameworks; only the code a developer writes
changes. A developer who learns Tina4 in Python should feel at home in the Go
version without reading new docs.

What ports UNCHANGED, gated by the existing fixtures:

- **Environment variables** - the whole `TINA4_*` surface, same keys, same values.
- **Connection strings** - `sqlite:app.db`, `postgresql://user:pass@host:port/db`,
  and the SQLite slash-count rule that trips everyone once.
- **JSON shapes** - the paginate envelope is the seven snake_case keys of ADR-0043
  (`records, total, page, per_page, total_pages, limit, offset`), the CRUD shapes,
  the `DatabaseResult`, the health and Swagger bodies.
- **Log format** - the same JSON in production, the same human-readable line in dev.
- **Error messages** - same wording, same status codes, same JSON structure.
- **CLI commands** - same flags, same output, language-prefixed (`tina4go`).
- **Wire contracts** - the `tina4:ws` backplane envelope, the `tina4_migration` and
  `tina4_sequences` table schemas, the JWT algorithm family (HMAC HS256/384/512
  zero-dependency, RS256 opt-in).

What becomes idiomatic Go is only the code: a struct where Python has a field
object, a tag where Ruby has a DSL call, an `error` return where PHP raises. A JSON
key is data and keeps its snake_case spelling no matter that the Go field beside it
is PascalCase (ADR-0008). The method name follows Go; the payload never does.

### Naming conventions, with the Go row added

| Aspect | Python | PHP | Ruby | Node.js/TS | Go |
|--------|--------|-----|------|------------|-----|
| Classes / types | PascalCase | PascalCase | PascalCase | PascalCase | PascalCase |
| Methods | snake_case | camelCase | snake_case | camelCase | exported PascalCase / unexported camelCase |
| Constants | UPPER_SNAKE | UPPER_SNAKE | UPPER_SNAKE | UPPER_SNAKE | exported PascalCase (env-var string keys stay UPPER_SNAKE) |
| Files | snake_case.py | PascalCase.php | snake_case.rb | camelCase.ts | lowercase.go / snake_case.go |
| Test files | test_*.py | *Test.php | *_spec.rb | *.test.ts | *_test.go |

Go has no public/private keyword; the case of the first letter IS the visibility, so
the exported method `Find` and the unexported helper `buildQuery` carry the rule in
their own spelling. Inside a Frond template, every filter name stays snake_case
regardless - that is a template-language convention, not a host-language one, and it
does not change for Go.

## The forks Go introduces

These are decisions, not foregone conclusions. Each load-bearing one is drafted as an
ADR stub in `plan/v3/decisions/` and listed again under "Open decisions" at the end.

### 1. Compiled, not interpreted - the serve loop (ADR-0089, the biggest fork)

This is the fork that changes the developer's day. The four frameworks hot-reload in
place: when `tina4 serve` sees a file change it POSTs `/__dev/api/reload`, the
framework re-imports the changed modules inside the running process, and then pushes
a browser refresh over the `/__dev_reload` WebSocket. The child process never dies;
only its module table moves.

A running Go binary cannot re-import a changed `.go` file into itself, so for Go that
road is closed and the edit must travel a different one. When the watcher sees a
change it will first run `go build`. If the build fails it will keep the old child
serving and paint the compiler error into the terminal and the browser overlay - a
red build never takes the site down. If the build passes it will bounce the child:
kill the old process group, start the fresh binary on the same port, wait for it to
bind, then push the same browser reload over the same WebSocket. The developer still
saves a file and watches the browser refresh. Only the machinery under it turns from
re-import into rebuild-and-bounce.

The CLI already holds every part this needs. The Node arm of `start_language_server`
already prefers a built `dist/app.js` over the run-at-source path, so "run the
compiled artifact" is not a new idea in the CLI. The respawn loop in `handle_serve`
sits dormant, kept for crash detection, and it is exactly a kill-the-group then
start-again machine. And the supervisor already makes every child its own process
group leader with `setpgid` and kills the whole tree with `killpg` on a signal, so
the bounce is clean. The open question is only the socket: inherit the listener so no
connection drops, or accept a sub-second refusal on localhost and let the browser's
reload retry cover it. The second is far less code and almost invisible.

### 2. Static typing - the ORM (ADR-0090)

The dynamic field-object ORM has four shapes already (Python field objects, Ruby DSL
calls, PHP array properties, Node's `static fields` object), and ADR-0004 lets this
surface be idiomatic per language. Go's natural shape is a struct with tags, the same
mechanism `encoding/json` reads:

```go
type User struct {
    tina4.Model
    ID    int    `tina4:"primary_key,auto_increment"`
    Name  string `tina4:"required,max=120"`
    Email string `tina4:"unique"`
}
```

Reflection reads those tags once at registration and builds the same column map the
others build from their own declarations; generics can give `Find`, `Where` and `All`
a typed return. The developer API is fresh - it mirrors no sibling verbatim - but the
WIRE contract ports unchanged: the ADR-0043 envelope, the `ModelCollection` with its
true-COUNT total and `ToPaginate()` (ADR-0064), the migration table schemas, fail-loud
operations that return an `error` rather than a silent zero, and a write with no
filter is an error. The one place the zero-dependency core cannot reach the standard
library is SQLite, which has no `database/sql` driver in stdlib - that is called out
below and in the ADR.

### 3. Templating - Frond (ADR-0091)

Go ships `html/template`, and the temptation is to wrap it. It's the wrong move.
`html/template` is its own small language and it doesn't speak Twig's `{% for %}`,
its `{{ value|filter }}` pipes, template inheritance, or Frond's cache and nonce
tags. The first template that uses `{% extends %}` or a Frond filter with no
`html/template` twin would break the contract. So tina4-go will port Frond the way
the other four ported it - tokenizer, parser, evaluator, the shared snake_case filter
set, `SafeString`, fragment cache, `csp_nonce()` - and a template will render
byte-identical to the Python reference, gated by `frondtags_contract.json` and
friends. Where Frond needs HTML, attribute, URL or JavaScript escaping it will reuse
Go's own vetted context-aware escaper, because escaping is security-critical and is
the one rung where a stdlib primitive is both the lean and the safe choice.

### 4. Zero-dependency core - the stdlib map

Tina4's core carries zero runtime dependencies on purpose, and Go's standard library
covers almost all of it. The mapping:

| Subsystem | Go standard library | Note |
|-----------|---------------------|------|
| HTTP server | `net/http` | no Gin, no Echo, no Fiber |
| Routing | `net/http` + own discovery | file-based discovery over `src/routes/` |
| Database access | `database/sql` | driver is the app's dependency (ADR-0067) |
| JSON | `encoding/json` | struct tags also drive the ORM column map |
| Templating | own Frond + `html/template` escaper | engine is ours; escaping is stdlib |
| Crypto / JWT HMAC | `crypto/hmac`, `crypto/sha256` | HS256/384/512 zero-dependency |
| JWT RS256 (opt-in) | `crypto/rsa`, `crypto/x509` | opt-in, in stdlib, no third party |
| Password hashing | `golang.org/x/crypto/pbkdf2` | see the flag below |
| WebSocket | `net/http` Hijack + own RFC 6455 | no gorilla, no nhooyr |
| Sessions, cache, queue (file) | `os`, `encoding/json`, `sync` | file backend is stdlib; brokers are app deps |

Two things have NO clean stdlib answer, and both are flagged honestly rather than
waved past:

- **SQLite.** `database/sql` has no stdlib SQLite driver. The two real options are
  `mattn/go-sqlite3` (needs cgo) and `modernc.org/sqlite` (pure Go, third party).
  The default dev database for the other four is SQLite, so this is a decision, not a
  detail - ADR-0090 and ADR-0067 own it.
- **PBKDF2.** Go's PBKDF2 lives in `golang.org/x/crypto`, the semi-standard extended
  library, not the core tree. It is Go-team maintained and low risk, but it is
  technically a module outside stdlib, so the 260000-iteration password contract
  either pulls `x/crypto` or is hand-written on `crypto/hmac` (a small, well-understood
  loop). The hand-written loop keeps the zero-dependency promise literally true.

### 5. CLI and metrics tooling (ADR-0092)

`tina4 init go` adds a `scaffold_go` next to the five that exist, and `tina4 serve`
gains a Go detection marker (`go.mod`), the next free default port after Node's 7148,
and the compile-and-bounce path of ADR-0089. `tina4 metrics` gains a `tree-sitter-go`
grammar and a `Go` arm through the `Lang` enum, which the Rust compiler then forces
through every per-language match. The grammar ships only if it clears the same bar
Pascal failed: the Go corpus must parse at 95% health or better. Pascal was declined
because `tree-sitter-pascal` left 51.5% of the Delphi corpus in parser error regions;
Go has a mature, actively maintained grammar, so clearing the bar is expected - but it
is proven by a test on the real tina4-go source, never assumed. The binary cost of one
grammar crate is about 0.5 to 1 MB, measured against `tree-sitter-rust`, which cost
+1.07 MB when it was added.

## The spike - fixtures as spec, proven in Go

A scoping document can claim the fixtures are an executable spec. The spike shows it.
A tiny Go module in a scratch directory (not committed to any Tina4 repo) reads three
real fixtures - `pagination_contract.json`, `securityheaders_contract.json`,
`cors_contract.json` - straight off disk, parses their invariants, and runs ONE
invariant against a minimal Go stub.

The invariant is ADR-0043's `paginate-key-set-is-identical-in-all-four`: the envelope
must be exactly the seven snake_case keys. The runner pulls those seven keys out of
the fixture's own rule text, so the expectation comes from the spec, not from the
test. Then it feeds the keys a wrong stub emits (the pre-ADR-0043 divergence, with
`data`, `count`, `perPage` and `totalPages` aliases) and the keys a correct stub
emits.

```
RUN 1: STUB=wrong
loaded pagination_contract.json      8 invariants  (adr ADR-0043)  suite langs: [nodejs php python ruby]
loaded securityheaders_contract.json 5 invariants  (adr SECHDR-DEC-01)  suite langs: [nodejs php python ruby]
loaded cors_contract.json            9 invariants  (adr ADR-0018)  suite langs: [nodejs php python ruby]
expected keys parsed FROM the fixture rule: [records total page per_page total_pages limit offset]
stub emitted keys: [count data limit offset page perPage per_page records total totalPages total_pages]
RED   paginate-key-set-is-identical-in-all-four: key-set violation: missing=[] extra=[count data perPage totalPages]
exit=1

RUN 2: STUB=right
expected keys parsed FROM the fixture rule: [records total page per_page total_pages limit offset]
stub emitted keys: [limit offset page per_page records total total_pages]
GREEN paginate-key-set-is-identical-in-all-four: envelope is exactly the seven snake_case keys
exit=0
```

Red before green, on the real bytes. The `suite langs` line shows the four columns a
fixture carries today; the whole port is the work of turning that into five. Toolchain:
`go version go1.27.1 darwin/arm64`, the module compiles clean under `go vet` and
`go build`.

## The phased roadmap

The estimates follow the ETA discipline: they are built from MEASURED agent durations,
given as ranges, and the critical path is named. The reference points (Opus workers,
measured 2026-09-24) are a large subsystem build such as a fresh HTTP server at 90 to
120 minutes in one language, a real-engine parity-test pass at 45 to 90 minutes, one
full framework suite on the lab at 15 to 25 minutes, and a CI run at 8 to 20 minutes.
A Go port is a single-language build, so the subsystem-build figure is the unit that
dominates; the parity-test figure applies per fixture as each invariant is driven red
to green and mutation-proven.

These are agent-duration ranges for focused build sessions, NOT wall-clock calendar
time. The biggest real driver is not any single estimate - it is the serial
dependency between phases (http before orm before crud) and the two open decisions
that gate Phase 2 and Phase 3.

**Phase 0 - contract runner.** Extend the spike into the real harness: load all 72
fixtures, add the `go` key to the `suites` maps as each invariant is claimed, and wire
`TINA4_GO_REPO` into `scripts/audit-contract-fixtures.py` so the auditor reports a
fifth column. Estimate: 1 subsystem unit, roughly 1.5 to 2.5 hours. Satisfies: none of
the behavioural invariants yet; it is the gate every later phase reports through.

**Phase 1 - core: http, router, response.** `net/http` server, file-based route
discovery, the response auto-serialisation convention (object to JSON, string to HTML),
request parsing, security headers and CORS secure-by-default. Estimate: 3 to 4
subsystem units plus per-fixture parity tests, roughly 8 to 14 hours. Critical path:
the server, then the router on top of it, then the response convention - each waits on
the one before. Satisfies: `request_contract`, `dispatch_contract`,
`route_groups_contract`, `cors_contract`, `securityheaders_contract`,
`http_hardening_contract`, `error_pages_contract`, `static_contract`,
`requestid_contract`, `health_contract`, `version_contract`,
`compression_etag_contract`, `landing_page_contract`.

**Phase 2 - ORM and database.** `database/sql` abstraction, struct-tag field mapping by
reflection, `ModelCollection`, the ADR-0043 pagination, soft-delete, migrations,
seeder, relationships, AutoCrud and the SQL translator. The largest phase, and the one
the SQLite decision gates. Estimate: 6 to 9 subsystem units plus heavy real-engine
parity tests on the lab, roughly 18 to 30 hours. Critical path: the `database/sql`
adapter and the SQLite driver decision come first; everything else stacks on the model
layer. Satisfies: `ormbase_contract`, `ormfields_contract`, `ormcache_contract`,
`pagination_contract`, `relationships_contract`, `imperative_relationships_contract`,
`softdelete_contract`, `nextid_contract`, `migrations_contract`, `seeder_contract`,
`autocrud_contract`, `sqltranslator_contract`, `statement_semantics_contract`,
`sqlite_path_contract`, `adapter_contract`, and the provider fixtures
(`pgprovider`, `mysqlprovider`, `mssqlprovider`, `firebirdprovider`, `odbcprovider`,
`mongosql`) as each driver is added.

**Phase 3 - templating (Frond).** Port the engine per ADR-0091. Frond is a large,
multi-part subsystem - the other four split it into tokenizer, parser, evaluator and
filters - so it is more than one unit on its own. Estimate: 3 to 5 subsystem units,
roughly 9 to 15 hours. Critical path: the parser gates the evaluator gates the
filters. Satisfies: `frondtags_contract`, `frond_extensibility_contract`,
`tina4css_contract`, `overlay_contract`.

**Phase 4 - auth and session.** JWT (HMAC default, RS256 opt-in), PBKDF2 password
hashing, sessions with the file backend, CSRF, RBAC, scopes, SSO. Estimate: 3 to 5
subsystem units, roughly 9 to 16 hours. Critical path: JWT and the password contract
first, then sessions, then the authorisation layers on top. Satisfies:
`session_contract`, `csrf_contract`, `rbac_contract`, `scopes_contract`,
`sso_contract`, `security_boundaries_contract`, `identifier_allowlist_contract`,
`ssrf_guard_contract`, `write_path_faillloud_contract`.

**Phase 5 - the long tail.** Queue, WebSocket, GraphQL, Swagger, messenger, mail,
web push, GIS, graph, docstore, background tasks, inline testing, logger, metrics,
dual-port, port takeover, instance loading, pool isolation, test client, API stream,
file upload. Many independent subsystems, so this phase parallelises where Phases 1
to 4 could not. Estimate: 12 to 20 subsystem units, roughly 30 to 55 hours of focused
build, finishing with its slowest parallel track rather than the sum. Satisfies the
remaining fixtures: `queue`, `messenger`, `mail_redirect`, `web_push`, `gis`,
`graph`, `graphql_transport`, `swagger`, `docstore`, `backgroundtasks`,
`inlinetesting`, `logger`, `metrics`, `dual_port`, `porttakeover`,
`instance_loading`, `pool_isolation`, `test_client`, `api_stream`, `fileupload`,
`browser_open`, `devadmin`, `validation`, `security_boundaries` tails, and the CLI
work of ADR-0092.

A whole-port single number would be false precision, so this document does not give
one. The shape is clear: Phases 1 through 4 are a serial spine of roughly 44 to 75
focused agent-build-hours, Phase 5 is a wide parallel fan on top, and the lab
contention between workers and the two gating decisions move the real finish more than
any estimate inside a phase. Re-estimate after Phase 0 lands with its real duration.

## Decisions (settled 2026-10-01)

All five load-bearing decisions are settled; the four ADRs are Accepted.

1. **ADR-0089 - serve socket handoff: ACCEPT THE SUB-SECOND REFUSAL.** No listener-fd
   inheritance. On a passing `go build` the loop kills the old child, starts the fresh
   binary on the same port, and pushes the browser reload; a <1s refusal on localhost
   is covered by the browser's reload retry. Builds are debounced; `tina4 serve` owns
   the `go build`. Far less code, no platform-specific fd plumbing.
2. **ADR-0090 - ORM shape and SQLite: TAGS+REFLECTION AND GENERICS; modernc.org/sqlite.**
   Reflection reads the `tina4` struct tags for the column map, generics give typed
   `Find`/`Where`/`All`. The default dev SQLite driver is `modernc.org/sqlite` (pure
   Go) - it keeps `CGO_ENABLED=0`, static binaries and cross-compilation, where cgo
   (`mattn/go-sqlite3`) would break all three; it is an app dependency (ADR-0067), never
   in the framework core.
3. **ADR-0091 - PORT Frond over wrap-`html/template`.** Confirmed; wrapping cannot hold
   the inheritance + filter contract. The Python master leads the decomposition
   (tokenizer / parser / evaluator / filters); `html/template`'s escaper is reused for
   escaping only.
4. **ADR-0092 - CLI LATE, Go default port 7149.** The port runs on plain `go build` +
   `go test` + the Phase 0 contract runner until the core exists; `tina4 init go`, the
   `tina4 serve` Go arm and the `tina4 metrics` grammar (gated at >= 95% parse health)
   are wired in Phase 5. Default port 7149 confirmed.
5. **PBKDF2: HAND-WRITE on `crypto/hmac`.** The 260000-iteration PBKDF2-SHA256 loop is
   written directly on `crypto/hmac` + `crypto/sha256` (both core stdlib), not pulled
   from `golang.org/x/crypto` - a small, auditable loop that keeps the zero-dependency
   CORE promise literally true.

The engine turns the key by itself now that these five are settled - the fixtures
already know what "correct" means, and the `go` column is waiting for its first green.
Phase 0 (the contract runner + the `go` suites column + the auditor's fifth column) is
the unblocked next step whenever the maintainer gives the go-ahead to BUILD.
