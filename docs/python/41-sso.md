# OpenID Connect SSO

Tina4 completes one provider-neutral OpenID Connect flow. You configure an
issuer. Tina4 discovers the provider, runs Authorization Code with PKCE,
verifies the result, regenerates the Session, and hands the normalized identity
to the existing secured-route gate.

No provider SDK. No second authentication system. The browser keeps the normal
Tina4 Session cookie.

## Configure SSO

```ini
TINA4_SSO_ISSUER=https://identity.example.com/realms/my-app
TINA4_SSO_CLIENT_ID=my-app
TINA4_SSO_CLIENT_SECRET=replace-me
TINA4_SSO_REDIRECT_URI=https://app.example.com/auth/callback
TINA4_SSO_SCOPES=["openid", "profile", "email"]
TINA4_SSO_VERIFY=introspection
TINA4_SSO_POST_LOGOUT_REDIRECT_URI=https://app.example.com/
```

SSO stays off until the issuer, client id, and redirect URI exist. A
confidential client also needs its secret. Production issuer and callback URLs
require HTTPS. Loopback HTTP remains available for local development.

When configured, Tina4 mounts these routes:

| Method | Route | Purpose |
| --- | --- | --- |
| `GET` | `/auth/login` | Start login and create one-use state, nonce, and PKCE values. |
| `GET` | `/auth/callback` | Validate state, exchange the code, and create the Session identity. |
| `POST` | `/auth/logout` | Destroy the local Session, then request provider logout when supported. |

An application route that collides with one of these paths stops startup with
an error. Tina4 never replaces part of the login flow in silence.

## Protect a route

SSO uses the same `@secured()` gate as local Tina4 authentication.

```python
from tina4_python import get, secured

@get("/account")
@secured()
async def account(request, response):
    return response.json(request.user)
```

`request.user` contains:

```json
{
  "issuer": "https://identity.example.com/realms/my-app",
  "subject": "provider-stable-subject",
  "username": "andre",
  "email": "andre@example.com",
  "name": "Andre",
  "roles": ["admin", "developer"],
  "groups": ["/engineering"]
}
```

Issuer and subject are required. Roles and groups are sorted, de-duplicated
lists. Provider tokens never enter `request.user`, logs, error pages, Swagger,
or `session.all()`.

## Use the SSO client

Automatic routes cover the normal browser flow. The public client remains
available when an application needs to start or inspect the flow itself.

```python
from tina4_python import Sso

if Sso.configured():
    sso = Sso.from_issuer()
    metadata = sso.discover()
    identity = sso.identity(request)
```

| Method | Result |
| --- | --- |
| `Sso.configured()` | Reports whether the required environment values exist. |
| `Sso.from_issuer()` | Creates the client and discovers the configured issuer. |
| `discover(force=False)` | Returns validated provider metadata. `force=True` refreshes it. |
| `login(request, return_to="/")` | Stores one-use login state and returns the authorization URL. |
| `callback(request, query=None)` | Validates the callback, regenerates Session, and returns identity plus the local return path. |
| `identity(request)` | Returns the normalized identity or `None`. |
| `refresh(request)` | Replaces provider credentials and identity atomically. |
| `logout(request, return_to="/")` | Destroys local Session first and returns the safe logout target. |

`return_to` accepts a local absolute path. Tina4 rejects schemes, hosts,
protocol-relative URLs, backslashes, and control characters.

## Map provider claims

Use `TINA4_SSO_CLAIM_MAP` when a provider stores a normalized field under
another claim path:

```ini
TINA4_SSO_CLAIM_MAP={"username":"preferred_username","roles":"realm_access.roles","groups":"groups"}
```

The value is a native `.env` object, not a comma-separated string.

## Provider recipes

The runtime does not name providers. Recipes only supply standard OIDC values.

### Keycloak

```ini
TINA4_SSO_ISSUER=https://sso.example.com/realms/my-realm
TINA4_SSO_REDIRECT_URI=https://app.example.com/auth/callback
```

Enable Authorization Code flow, register the exact callback URI, and map realm
roles, client roles, or groups into claims when the application needs them.

### Microsoft Entra ID

```ini
TINA4_SSO_ISSUER=https://login.microsoftonline.com/your-tenant-id/v2.0
TINA4_SSO_REDIRECT_URI=https://app.example.com/auth/callback
```

Use the tenant-specific v2 issuer. Add a claim map only when the tenant exposes
roles or groups under different names.

## Verification and failure rules

Version 3.13.104 supports introspection without an extra Python package. It
requires a confidential client secret. Selecting `jwks` fails during
configuration until the application installs a supported cryptography
capability.

State, nonce, authorization code, and PKCE verifier are one-use. A mismatch or
replay creates no identity. A failed refresh removes SSO identity rather than
continuing with expired credentials. Logout always destroys the local Session
before it contacts the provider.

## Swagger

When SSO is configured, Swagger publishes the issuer discovery URL as an
`openIdConnect` scheme. Secured routes accept the normal Tina4 Session cookie or
the configured bearer scheme. Swagger never presents a provider access token as
a Tina4 Session.
