# OpenID Connect SSO

Tina4 completes one provider-neutral OpenID Connect flow. Configure an issuer
and Tina4 discovers the provider, runs Authorization Code with PKCE, regenerates
the Session, and sends the normalized identity through the existing secured
route gate. The browser keeps the normal Tina4 Session cookie.

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

When configured, Tina4 mounts:

| Method | Route | Purpose |
| --- | --- | --- |
| `GET` | `/auth/login` | Start login and create one-use state, nonce, and PKCE values. |
| `GET` | `/auth/callback` | Validate state, exchange the code, and create the identity. |
| `POST` | `/auth/logout` | Destroy the local Session and request provider logout. |

A route collision stops startup with an error.

## Use the identity

Secured routes use the same authentication gate as local Tina4 authentication.
The normalized identity is available as `$request->user`. Provider tokens never
enter that value, logs, error pages, Swagger, or `Session::all()`.

```php
use Tina4\Sso;

if (Sso::configured()) {
    $sso = Sso::fromIssuer();
    $metadata = $sso->discover();
    $identity = $sso->identity($request);
}
```

| Method | Result |
| --- | --- |
| `Sso::configured()` | Reports whether required environment values exist. |
| `Sso::fromIssuer()` | Creates the client and discovers the issuer. |
| `discover($force = false)` | Returns validated metadata. Force refreshes it. |
| `login($request, $returnTo = '/')` | Stores one-use state and returns the authorization URL. |
| `callback($request, $query = null)` | Validates the callback and regenerates Session. |
| `identity($request)` | Returns the normalized identity or `null`. |
| `refresh($request)` | Replaces credentials and identity atomically. |
| `logout($request, $returnTo = '/')` | Destroys Session and returns the safe logout target. |

`returnTo` accepts a local absolute path. Tina4 rejects schemes, hosts,
protocol-relative URLs, backslashes, and control characters.

## Map claims and providers

```ini
TINA4_SSO_CLAIM_MAP={"username":"preferred_username","roles":"realm_access.roles","groups":"groups"}
```

The runtime does not name providers. For Keycloak, use a realm issuer such as
`https://sso.example.com/realms/my-realm`. For Microsoft Entra ID, use the
tenant-specific v2 issuer. Register the exact Tina4 callback URI in either
provider. Use a claim map only when roles or groups use different claim names.

Version 3.13.104 supports introspection without another PHP package and needs a
client secret. Selecting `jwks` fails during configuration until the application
installs a supported cryptography capability. State, nonce, code, and verifier
are one-use. Logout always destroys the local Session first.

## Swagger

When configured, Swagger publishes the issuer discovery URL as an
`openIdConnect` scheme. Secured routes accept the normal Tina4 Session cookie or
the configured bearer scheme.
