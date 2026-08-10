# Feature 046: Default landing page

## Identity and status

- Matrix identity: 46 - Default landing page
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the landing-page registration in
  each app bootstrap). No framework code changed.
- Dependencies: Feature 31 router (the `/` route and its precedence), route auto-discovery
- Dependants: a fresh app with no `/` route yet; the "it works" first-run experience
- Existing ADRs: the routing precedence (Feature 31)
- Shared fixtures: `landing_page_contract.json` is required
- Catalog phase: Routing and middleware

## Why this feature exists

A developer who just started a Tina4 app and opens `http://localhost` should see a branded
"it works" page confirming the server is up - but the MOMENT they define their own `/` route,
that page must vanish and their route must win, in all four languages.

## Boundary

This feature owns the default `/` landing page: its registration, its content, and the rule
that it never shadows a user-defined `/` route. It DELEGATES routing and precedence to Feature
31 and the response to Feature 30. It does not own any other route.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Default landing at `/` | yes | `registerLandingPage()` | yes | yes |
| Registered when | route discovery, if no `/` route | after discovery, only if no `/` route exists | same | same |
| User `/` route precedence | wins | wins ("takes precedence over the landing page") | wins | wins |
| Content | branded Tina4 welcome | branded welcome | branded welcome | branded welcome |
| Production behaviour | (to confirm) | (to confirm) | (to confirm) | (to confirm) |

The default landing page is registered during app bootstrap and, per the PHP source, renders at
`/` ONLY when the application has not defined its own `/` route: "a user route takes precedence
over the landing page." This no-shadow rule is the important behaviour, and it must be identical
in all four so that defining a `/` route reliably replaces the default everywhere.

## Public surface contract

When an application has no `/` route, the framework serves a branded default landing page at
`/`. When the application defines a `/` route, that route serves and the default landing page is
never registered or is overridden. The developer takes no action to remove the default; defining
their route is the action.

## Inputs and outputs

- Input: whether the application registered a `/` route (checked during bootstrap).
- Output: the branded landing page at `/` when no user route exists; otherwise the user route's
  response.
- The landing page is a simple, self-contained HTML response (no external dependency), so it
  renders offline.

## Lifecycle and operation graph

1. Route auto-discovery registers the application's routes.
2. After discovery, the framework checks whether a `/` route exists.
3. If none exists, it registers the default landing page at `/`.
4. If one exists, the default is not registered, so the user's `/` route serves.

## Configuration and precedence

- A user-defined `/` route ALWAYS takes precedence; the default is a fallback only.
- The registration happens AFTER user routes are discovered, so the check sees the user's route.
- Whether the default landing shows in production (framework fingerprinting) is the one policy
  question below.

## Failures, side effects and security

- PRECEDENCE: the default must NEVER shadow a user `/` route; a bootstrap-ordering bug that
  registered the default before user discovery would break every fresh app's first custom route.
- FINGERPRINTING: the branded page reveals "this is a Tina4 app", which is minor information
  disclosure. The policy question is whether the default landing shows in production or only in
  development; a production server usually has its own `/` route, so this is an edge case, but it
  should be a deliberate decision, not an accident.
- The page is self-contained (no CDN), so it cannot break offline or leak a request to a third
  party.

## Wire and persistence contract

There is no persistence; the wire output is a self-contained HTML page at `/` with a 200 status.
The presence-or-absence rule (shown only when no user `/` route) is the contract and is identical
across the four.

## Providers and substitutability

The landing page is transport-level and engine-agnostic. A future runtime registers the same
default at `/` after discovery, with the same no-shadow precedence and the same
self-contained content.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| LP-01 | The no-shadow precedence (user `/` route wins) and the after-discovery registration timing are not gated as parity. | Gate that a user `/` route replaces the default, and that the default shows only when absent, in all four. |
| LP-02 | The production behaviour (show the branded page or not) is not a stated decision. | Decide whether the default landing shows in production; gate the chosen behaviour in all four. |
| LP-03 | The page's self-containment (no external asset) is not gated. | Gate that the landing page renders offline (no CDN/asset request) in all four. |
| LP-04 | No shared fixture exists. | Add `landing_page_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. The default landing page shows at `/` ONLY when the application has no `/` route; a user `/`
   route always wins, and the check runs after route discovery, in all four.
2. Decide the production behaviour: either the default landing shows in production (simple,
   confirms the server is up) or it is suppressed there to avoid framework fingerprinting;
   pin one, identical across four. Recommendation: allow it, since a production app almost always
   defines its own `/`, and suppress only if fingerprinting is a stated concern.
3. The landing page is self-contained HTML with no external asset, so it renders offline.

## Proposed conformance fixture

Add `landing_page_contract.json` with stable ids for: a fresh app (no `/` route) serving the
branded landing page at `/` with a 200; the same app after defining a `/` route serving the
user's response instead (the default gone); the landing page containing no external asset
request (offline-safe); and the chosen production behaviour. Every case runs a real app through a
real request; no mock can claim conformance.

## Integration map

- Feature 31 owns routing and the precedence; the app bootstrap registers the default after
  discovery.
- The first-run/getting-started docs reference the landing page.
- Central fixtures, four runners, the CI matrix and the getting-started docs update together.

## Breaking changes and migration

- No application break; the audit gates the no-shadow precedence and the offline-safety. If the
  production behaviour is changed (suppressed), state it in the release note; a fresh app is
  unaffected because it has no `/` route to conflict.

## Implementation backlog

1. Add `landing_page_contract.json` and wire four runners.
2. Gate the no-shadow precedence and after-discovery timing (LP-01) in all four.
3. Decide and gate the production behaviour (LP-02) and the offline-safety (LP-03).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

After route discovery, check whether a `/` route exists; if not, register a branded,
self-contained (no external asset) landing page at `/`. A user `/` route always wins - never
register the default over it. Apply the chosen production behaviour. Prove the port with a
fresh-app landing case and a user-route-replaces-default case.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (LP-01..04).
- [x] Owner ambiguities recorded (3 proposed; the no-shadow precedence and production behaviour).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
