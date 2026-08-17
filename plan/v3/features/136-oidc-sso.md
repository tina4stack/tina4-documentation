# Feature 136: Configuration-first OpenID Connect SSO

**Outcome:** Configure an OIDC issuer once; Tina4 completes login, hands the verified
identity into its existing Session, and authenticates the same secured routes in every
backend.

## Identity and status

- Matrix identity: 136 - OpenID Connect SSO
- Audit state: accepted; implementation in 3.13.104
- Dependencies: Features 29 (request), 31 (routing), 33 (middleware), 45 (Swagger),
  64 (JWT/Auth), 65 (Session), 81 (HTTP client)
- Dependants: application login/logout and role-based browser authorization
- Existing ADRs: ADR-0021, ADR-0041, ADR-0056 (Accepted)
- Shared fixtures: `sso_contract.json` (10 invariant groups)
- Release line: 3.13.104

## Why this feature exists

Enterprise applications commonly delegate login to an OpenID Connect provider.
Tina4 currently makes each application rebuild this security-sensitive flow even though
the framework already owns HTTP, Auth, Session, routing and secured-route enforcement.

## Boundary

Feature 136 owns configuration/discovery, Authorization Code + PKCE, callback validation,
provider verification, identity/role normalization, refresh, logout and the Session
handoff. It delegates transport, JWT primitives, storage/cookies and dispatch to existing
Tina4 features.

It does not own user provisioning, application permissions, SCIM, LDAP, SAML, social
provider APIs or browser-side token storage.

## Existing implementation evidence

| Capability | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| JWT/Bearer authentication | ✅ | ✅ | ✅ | ✅ |
| Server-side Session | ✅ | ✅ | ✅ | ✅ |
| HTTP client | ✅ | ✅ | ✅ | ✅ |
| Swagger OIDC description | ✅ | ✅ | ✅ | ✅ |
| Core live OIDC flow | ✅ | ✅ | ✅ | ✅ |
| Provider identity -> Session | ✅ | ✅ | ✅ | ✅ |
| Refresh/logout/claim mapping | ✅ | ✅ | ✅ | ✅ |
| Full adversarial fixture | owed | owed | owed | owed |

## Public surface contract

- `Sso.from_issuer(...)` / idiomatic equivalent resolves discovery from configuration.
- `sso.login(request, return_to="/")` stores one-use state/nonce/PKCE values in Session
  and redirects to the discovered authorization endpoint.
- `sso.callback(request)` validates and exchanges the code, verifies identity,
  regenerates Session, stores reserved SSO data and redirects locally.
- `sso.logout(request, return_to="/")` destroys the local Session and optionally follows
  the discovered provider logout endpoint.
- `sso.identity(request)` returns normalized identity or native absence.
- Existing secured routes accept a valid SSO Session. No second decorator is introduced.

Canonical configured routes are `GET /auth/login`, `GET /auth/callback`, and
`POST /auth/logout`. A collision with an application route fails startup loudly.

## Inputs and outputs

Configuration is the primary API:

```ini
TINA4_SSO_ISSUER=https://id.example.com/realms/example
TINA4_SSO_CLIENT_ID=my-application
TINA4_SSO_CLIENT_SECRET=change-me
TINA4_SSO_REDIRECT_URI=https://app.example.com/auth/callback
TINA4_SSO_SCOPES=["openid", "profile", "email"]
TINA4_SSO_VERIFY=introspection
TINA4_SSO_CLOCK_SKEW=60
```

`TINA4_SSO_CLIENT_SECRET` is optional for public clients. Configuration values follow
explicit argument > environment > default (ADR-0041). The `.env` typed-list contract is
reused; no comma-parser is invented specifically for SSO.

Normalized `request.user`:

```json
{
  "issuer": "https://id.example.com/realms/example",
  "subject": "provider-stable-subject",
  "username": "andre",
  "email": "andre@example.com",
  "name": "Andre",
  "roles": ["admin", "developer"],
  "groups": ["/engineering"]
}
```

Issuer and subject are required. Optional scalars use native absence; roles/groups are
always sorted, de-duplicated string lists. Tokens never appear in `request.user`.

## Lifecycle and operation graph

1. CONFIGURE: require issuer and client id; validate redirect URI and verification mode.
2. DISCOVER: fetch `.well-known/openid-configuration`; require exact issuer equality and
   the endpoints needed by the selected capabilities; cache successful metadata briefly.
3. LOGIN: validate a local return path; create state/nonce/PKCE verifier in Session;
   redirect using Authorization Code + PKCE S256.
4. CALLBACK: exact-match and consume state; exchange the one-use code over verified TLS;
   validate the provider result and normalize identity.
5. HANDOFF: regenerate Session while preserving deliberate pre-login state; atomically
   store `_tina4_sso`; save; emit the normal hardened Session cookie.
6. RESUME: Session load -> SSO restore/refresh -> existing Auth gate -> route.
7. REFRESH: replace access/id/rotated refresh credentials atomically; failure clears SSO.
8. LOGOUT: destroy local Session and cookie first, then provider end-session if advertised.

## Configuration and precedence

The runtime contains no `if provider == keycloak/entra/okta` branches. The standard
configuration is:

- `TINA4_SSO_ISSUER` (required)
- `TINA4_SSO_CLIENT_ID` (required)
- `TINA4_SSO_CLIENT_SECRET` (optional)
- `TINA4_SSO_REDIRECT_URI` (required outside trusted loopback development)
- `TINA4_SSO_SCOPES` (default native list `openid, profile, email`)
- `TINA4_SSO_VERIFY` (`introspection` in 3.13.104; `jwks` fails at configuration until an application cryptography capability is installed)
- `TINA4_SSO_POST_LOGOUT_REDIRECT_URI` (optional)
- `TINA4_SSO_CLOCK_SKEW` (default 60, non-negative)
- `TINA4_SSO_CLAIM_MAP` (optional native object mapping normalized fields/roles/groups)

Provider profiles are documentation/scaffolding recipes that populate these values and,
where necessary, a claim map. They do not add runtime adapters.

## Failures, side effects and security

- Fail configuration loudly for invalid issuer/client/redirect/mode or missing required
  crypto capability. HTTPS is mandatory except loopback; TLS verification stays enabled.
- State, nonce, code and verifier are one-use. Mismatch/replay creates no identity.
- Return targets allow local absolute paths only; reject hosts, schemes, `//`, backslashes
  and control characters.
- Pin algorithms/configuration; reject `none` and algorithm confusion; refresh JWKS once
  for an unknown `kid`.
- Always regenerate Session after login. `_tina4_sso` is reserved and excluded from
  `session.all()`, logs, errors, status, Swagger output and debug tools.
- Refresh is single-flight where concurrent requests can overlap. A failed refresh clears
  provider authentication rather than continuing with expired credentials.

## Wire and persistence contract

- Discovery/token/userinfo/introspection use standard OIDC HTTP through Feature 81.
- Browser receives only the existing Tina4 Session cookie—never provider tokens.
- Reserved `_tina4_sso` contains schema version, normalized identity, verification mode,
  expiry and provider credentials. It is internal and versioned.
- Swagger registers the discovery URL as `openIdConnect` and documents the actual
  `tina4_session` cookie as an alternative on the same secured-route metadata used by
  Feature 45. It does not pretend that a provider access token is a Tina4 Session.

## Provider substitutability

Runtime support is one standards-compliant, discovery-based OIDC contract. There are no
provider adapters, provider enums, or provider-specific branches. Named-provider setup
belongs only in documentation recipes, where issuer and claim-map examples can be tested
without changing the framework API. OAuth-only and SAML services are outside this feature.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| SSO-01 | Swagger describes OIDC but no backend executes it. | Build one discovery-driven runtime contract. |
| SSO-02 | Existing JWT validation is not a complete external-provider contract. | Add issuer/audience/key rotation rules without weakening Feature 64. |
| SSO-03 | A separate SSO decorator would split Auth. | Session handoff must feed the existing secured gate. |
| SSO-04 | A standard library alone cannot safely verify provider RSA tokens. | Introspect or require app crypto at JWKS point-of-use; never hand-roll RSA. |

## Owner decisions

Recorded:

1. Configuration first: issuer discovery drives providers; no brand adapters.
2. Verified SSO identity hands into the existing Tina4 Session.
3. One unified, provider-neutral fixture drives all four frameworks; a real self-hosted
   provider may implement the disposable lab environment without entering the public API.

4. Introspection is the zero-extra-package verification mode in 3.13.104. JWKS must fail
   at configuration until an application cryptography capability is installed.
5. A disposable standards-compliant OIDC server is the mandatory live gate. Named
   providers are documentation recipes, not runtime branches.

## Proposed conformance fixture

`fixtures/sso_contract.json` defines ten owed adversarial groups. The current four-way
runner proves the core live PKCE/callback/Session/refresh/logout path against a real,
version-pinned OIDC service and real Session storage. The groups remain owed until every
named negative and substitutability witness is implemented in every runner.

No mocks, fake OIDC server, decoded-without-validation token or direct mutation of Session
internals is accepted. Mutations must prove state, redirect, regeneration, reserved-data,
refresh rotation and local-first logout gates can go red.

## Integration map

- Export one `Sso`/`SSO` class from the normal framework root.
- Startup mounts canonical routes only when configured; SSO remains off by default.
- Request pipeline: Session -> SSO -> existing Auth gate -> route.
- A later signed Tina4 client release should add commented generic OIDC configuration
  to `tina4 init` and a credential-safe doctor check. This is client work, not part of
  the four framework package release.
- Documentation/book/skills teach configuration first, then tested provider recipes.
- Swagger and release notes update with the implementation.

## Breaking changes and migration

Additive. Applications already owning canonical `/auth/*` paths must disable automatic
mounting or move those routes. `_tina4_sso` is reserved and not an application API.

## Implementation backlog

### Scope

- [x] Define configuration-first OIDC and Session boundary.
- [x] Allocate Feature 136 and proposed ADR-0056.
- [x] Define the unified fixture cases.
- [x] Verification default and provider-neutral proof tier accepted.
- [x] Write four baseline runners and observe the core flow red before implementation.
- [x] Implement configure/discover/login/callback/session handoff in all four.
- [x] Implement resume/refresh/logout/roles/Swagger in all four.
- [x] Publish framework docs, four book chapters and four developer-skill references.
- [ ] Mutation-prove every security witness.
- [x] Run full suites and the final real-provider lab gate as root.
- [ ] Extend the signed Tina4 client's `init` and doctor commands in a separate client release.
- [ ] Move fixture cases owed -> proven and sync CONTRACT-MAP.

### Parity

| Capability | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Plan + proposed fixture | ✅ | ✅ | ✅ | ✅ |
| Baseline runner | ✅ | ✅ | ✅ | ✅ |
| OIDC flow | ✅ | ✅ | ✅ | ✅ |
| Session handoff | ✅ | ✅ | ✅ | ✅ |
| Real provider proof | ✅ | ✅ | ✅ | ✅ |

### Tests (written first, real — no mocks, positive + negative)

- [ ] All four consume identical JSON cases.
- [ ] Runner negative controls prove provider/session failures are observable.
- [ ] Real file and non-file Session backends complete callback -> resume -> logout.
- [ ] Each named mutation witness turns red before restoration.

### Bugs

- [ ] Add reproduced implementation defects here with four-language regressions.

### Commits

- Python: `c0c901b` (runtime), `3ff4148` (release), `a2f9026` (skills)
- PHP: `87106ecf` (runtime), `6b9667e8` (release), `ff48b444` (skills)
- Ruby: `f68e788` (runtime), `bc0a0fd` (release), `5409582` (skills)
- Node.js: `42c59a2` (runtime), `ac76bea` (release), `f95a1f5` (runner), `bf8206c` (skills)
- Documentation: `b5ec94e`, `c7ce745`
- Books: `15b0699`

## Porting capsule

Reuse the new backend's HTTP, Auth, Session, router and middleware. Implement the eight
configuration-driven lifecycle stages above and exact `TINA4_SSO_*`, route, normalized
identity, reserved-session and failure contracts. Run `sso_contract.json` against the same
real provider. Mechanism may differ; redirects, Session outcome, `request.user`, roles and
failures may not.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner decisions 4-5 recorded.
- [x] Proposed cases and mutation witnesses complete.
- [x] Integration map and migration complete.
- [x] Backlog dependency-ordered.
- [x] Porting capsule clean-room sufficient.

## Status: Accepted for 3.13.104
