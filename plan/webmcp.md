# WebMCP for Tina4

Governed by [ADR-0087](v3/decisions/ADR-0087.md). WebMCP lets a running Tina4
application hand an agent its own actions - `filterOrders`, `checkout` - as Model
Context Protocol (MCP) tools the agent discovers and calls directly, instead of
scraping the page and clicking. It is the production cousin of the `/__dev/mcp` dev
surface (feature 101), which is about coding against local code; this is about using
the app the code became, with the end user present. The two are never conflated.

Two rendering modes force two execution paths, and that split is the whole shape of
this plan. A tina4-js single-page application (SPA) keeps its state in browser signals,
so a tool registers and runs in the page - no backend. A Frond-rendered page is
templated on the server, so a tool call has to bridge to the backend to reach the state
it needs. Phase 1 ships the in-page module on its own. Phase 2 brings the Frond bridge
to all four backends at parity.

## Scope

- [ ] Phase 1 - the `tina4js/webmcp` client module, shipping independently
- [ ] Phase 2 - the Frond backend bridge, at parity across Python, PHP, Ruby and Node.js

Both phases are in scope. Phase 1 stands alone and reaches all four backends the day it
ships, because every backend serves a tina4-js frontend. Phase 2 adds the one render
mode that needs the server.

## Phase 1 - the tina4-js client module (`tina4js/webmcp`)

The client module is the reference the Frond bridge will follow in Phase 2. It runs
entirely in the browser, touches no backend, and adds nothing to an app that does not
import it.

- [ ] The author API `webmcp.tool(name, schema, handler, { risk })` - one call registers one tool. Declarative, signals-aware, the same signature the Frond bridge will accept in Phase 2.
- [ ] A `navigator.modelContext` conformance layer, so a standard-speaking agent finds the app's tools with no Tina4-specific knowledge. The wrapper is what the developer writes; the conformance surface is what the agent reads.
- [ ] Tool lifecycle tied to the component and signal lifecycle - a tool registers when its component mounts and unregisters when it unmounts, so a tool never outlives the page state it drives.
- [ ] The tiered-consent UI primitive - `risk: 'read'` auto-allows, `risk: 'write'` surfaces a Tina4 UI prompt and runs the handler only after the user approves it.
- [ ] JavaScript Object Notation (JSON) schema tool descriptions - each tool declares its argument schema so the agent knows how to call it.
- [ ] A tree-shakeable, zero-dependency export. An app that ignores WebMCP pays nothing; the tina4-js core stays zero-dependency.
- [ ] Unit tests and integration tests (real browser signals, no mocks).
- [ ] A documentation page.

### Phase 1 acceptance criteria

- [ ] A read tool registered with `webmcp.tool()` is discoverable through `navigator.modelContext` and returns state without a consent prompt.
- [ ] A write tool does not run until the user approves it through the Tina4 UI primitive; a declined prompt runs nothing.
- [ ] A tool registered by a component is gone from the surface after that component unmounts.
- [ ] The module tree-shakes out of a build that never imports it, and the tina4-js core bundle size is unchanged when WebMCP is absent.
- [ ] Unit and integration suites pass with zero failures and zero skips on a real browser runtime, proven by mutation.

## Phase 2 - the Frond bridge (parity across Python, PHP, Ruby, Node.js)

A Frond-rendered page cannot answer a tool call in the browser, because the logic lives
on the server. The bridge is how the call crosses over: the page declares its tools in
the Frond route or template, the agent invokes one, the request travels to the server,
the server runs the handler against the real application state, and the result comes
back. The bridge is REQUIRED only for the Frond server-side-rendered (SSR) case - it is
conditional, never the default, and it is the piece of work that lands in all four
backends, because Frond rendering exists in all four.

- [ ] A way to declare a page's tools in the Frond route or template, so the server registers them and exposes them to an agent over a production MCP surface distinct from `/__dev/mcp`.
- [ ] Agent invocation to server execution to return - the round trip for one tool call, with the same author-facing declaration as Phase 1.
- [ ] Consent semantics preserved server-side - a `risk: 'write'` tool is approved before the bridge runs, and the bridge refuses a write it has no consent for, so an agent cannot reach past the prompt by calling the surface directly.
- [ ] A shared contract fixture `plan/v3/fixtures/webmcp_contract.json` (the ADR-0024 one-fixture-one-checker pattern), so the four frameworks are behaviour-locked at parity and answer a tool call the same way.
- [ ] Per-framework tests with real, no-mock execution - a real tool call driven end to end on each backend.
- [ ] The existing MCP server implementations in each framework (feature 101, the `/__dev/mcp` mount) are the starting point for the production surface, reused rather than rebuilt.

### Phase 2 acceptance criteria

- [ ] The same `webmcp.tool()` declaration works on a Frond page and on an SPA page with no change to the author's code.
- [ ] A tool call on a Frond page executes the handler on the server and returns the result the SPA path would return for the same tool.
- [ ] A write tool is refused server-side without consent, on all four frameworks.
- [ ] `webmcp_contract.json` drives all four runners from the same bytes, and `scripts/audit-contract-fixtures.py` flips the feature from owed to proven.
- [ ] Every framework's suite passes with zero failures and zero skips at HEAD on the lab, proven by mutation, and the production surface is confirmed distinct from `/__dev/mcp`.

### Phase 2 open risks

- **Authentication and consent on a server surface.** The production MCP surface is reachable by an agent, so it inherits the trust-boundary posture of [ADR-0082](v3/decisions/ADR-0082.md) and the two-layer capability-plus-authorization gate feature 101 proves for `/__dev/mcp`. The surface must not fail open.
- **The session model.** A tool call has to be tied to the user whose consent it carries, so a write approved by one user cannot be replayed against another's session.
- **Server-side reach and abuse.** A tool that runs on the server can reach outbound; the bridge inherits the same abuse and request-forgery discipline the dev MCP surface already carries, and a tool must not become a path to reach services the process alone could touch.

## Out of scope / future

- **Cross-page tool federation** - one agent seeing and composing tools across several pages or several running apps at once. Each page declares its own tools for now.
- **Agent identity and authentication beyond consent** - proving which agent is calling, and per-agent authorisation, sit above the tiered read/write consent this plan ships.

## Tests (written first, real - no mocks, positive + negative)

- [ ] Phase 1: read tool auto-allows and returns (real browser signals)
- [ ] Phase 1: write tool blocks until approval; declined prompt runs nothing
- [ ] Phase 1: tool unregisters on component unmount
- [ ] Phase 2: same declaration runs on Frond and SPA with identical result
- [ ] Phase 2: write refused server-side without consent, all four frameworks
- [ ] Phase 2: `webmcp_contract.json` drives all four runners, owed to proven

## Bugs

- [ ] (log here as `[ ]`, tick when a real test proves it fixed)

## Commits

- (hash  description - one line per landed change, per framework)

## Status: Proposed
