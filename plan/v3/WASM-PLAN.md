# WebAssembly (WASM) in Tina4 — the plan

- Status: Proposed (Phase 1 ready to schedule; Phases 2–3 are optional bets)
- Date: 2026-10-15
- Decision of record: [ADR-0097](decisions/ADR-0097.md) — zero dependency governs WASM adoption
- Related: ADR-0002 (metrics engine lives in the Rust client), the Feature 36 security-header set (COOP/COEP)

## The one constraint that sorts everything

Tina4's promise is zero runtime dependencies. A WASM *runtime* is itself a
dependency in three of the four backends: Node ships WASM in the engine for free,
Python needs `wasmtime-py`, PHP needs an extension or FFI, and Ruby needs a
`wasmtime` gem. So every idea below is weighed against one question that is cheap
to trace: does it keep the zero-dependency default, or does it break it? That
single test ranks the menu.

## The menu, ranked by what it costs the promise

### 1. Browser compute — the tension-free win (RECOMMENDED FIRST)

COOP (shipped 2026-10-15, default `same-origin-allow-popups`) plus a COEP header
give a tina4-js app `crossOriginIsolated`, which switches on `SharedArrayBuffer`,
which switches on WASM threads in the browser. The app brings its own `.wasm`;
Tina4 serves only the two isolation headers. **No backend gains a dependency.**

- A Tina4 app can then run ffmpeg.wasm, in-browser SQLite, image processing or
  real codecs on a worker thread — the server never spends a cycle on it, which
  reads straight onto the green/Carbonah story.
- It is the natural next step after the COOP header and the only idea with zero
  cost to the core promise.

### 2. The Rust client to `wasm32` — cheap, narrow, no backend cost

The `tina4` client is already Rust. Its pure-compute parts — the metrics engine
(ADR-0002), the SQL grammar, the language detector — compile to `wasm32` and run
in a browser playground, on an edge runtime, or in a CI with no native binary to
download. It touches none of the four frameworks, so zero dependency is untouched.
The win is a "try Tina4 metrics on your own code" page and dependency-free CI —
narrow, but almost free.

### 3. The parity engine — the seductive one the constraint kills

The dream: compile one pure component (the SQL dialect translator) to WASM once,
call it from all four frameworks, and collapse four implementations to one —
ending the whole class of cross-language drift (the `?`→`%s` placeholder
translator that drifted in tina4-python#138 / #227; the Mongo SQL parser that
exists four times). It aims squarely at Tina4's deepest maintenance cost.

The honest trace of why it does not pay off as stated:

- To **kill** drift the WASM module must be the ONLY implementation — which
  forces a WASM runtime into Python, PHP and Ruby and breaks zero dependency
  outright.
- To **keep** zero dependency the four native implementations stay and WASM is an
  opt-in fast path — but then nothing is deleted; it is a fifth implementation to
  keep in sync.

Either the promise breaks or the drift stays. The dream does not survive the
constraint. It earns a time-boxed spike to settle with data, never a commitment
up front. See ADR-0097.

### 4. The backend on WASM (php-wasm, Pyodide, ruby.wasm) — not now

Real, but each runtime's build is large and it fights "Simple." Parked.

## The staged plan

### Phase 1 — Browser compute (ship next, no regret)

Finish the isolation switch and prove it with one demo.

- Add a `TINA4_COEP` opt-in to sit alongside the shipped `TINA4_COOP`
  (`SecurityHeadersMiddleware`), default unset so it never breaks a CDN
  subresource; when set to `require-corp` it completes `crossOriginIsolated`.
- Document the recipe (COOP `same-origin` + COEP `require-corp` → isolated
  context → `SharedArrayBuffer`), including the CORP/CORS requirement on
  cross-origin subresources.
- Build ONE gallery demo behind it — an in-browser SQLite query page or a
  client-side image filter — proving WASM threads run.
- Parity: the `TINA4_COEP` knob lands in all four frameworks, with a contract
  case in the Feature 36 fixture.

Deliverable: the env knob (×4), a docs page, one demo. Backend dependency cost:
none.

### Phase 2 — Rust client to `wasm32` (cheap pilot)

Compile the metrics engine to `wasm32-wasi` and run it from a docs playground
page. Proves the Rust core is portable; gives a public "try it" surface. No
framework dependency moves.

Deliverable: a `wasm32` build target in the `tina4` client's CI, plus one
playground page in the docs. Honest caveat: most of the client does filesystem
and process work WASI only half-supports, so this covers the pure analysers only.

### Phase 3 — Parity-engine spike (research, hard go/no-go)

Take the SQL translator, build a Rust→`wasm32` version, wire it into **Node only**
(where WASM is free) as the single path, and MEASURE: does it reduce real
maintenance against the cost of a fifth implementation and a runtime dependency?

- **Go/no-go gate:** extend to Python/PHP/Ruby ONLY if the Node pilot shows a
  genuine maintenance drop AND an acceptable dependency story for the other three.
- Predicted outcome: no-go on zero-dependency grounds — but the spike turns an
  argument into an ADR either way.

Deliverable: a throwaway Node branch + a measurement write-up folded into
ADR-0097, not shipped code.

## Where to start

Phase 1. It is the natural next step after the COOP header, it is the one idea
with zero cost to the core promise, and it gives a user something to see and run.
Phases 2 and 3 are optional bets taken or declined on their own merits.
