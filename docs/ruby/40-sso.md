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

SSO stays off until the issuer, client id, and redirect URI exist. Production
issuer and callback URLs require HTTPS; loopback HTTP remains available for development.
When configured, Tina4 mounts `GET /auth/login`, `GET /auth/callback`, and
`POST /auth/logout`. A route collision stops startup with an error.

## Use the identity

Secured routes use the same gate as local Tina4 authentication. The normalized
identity is available as `request.user`. Provider tokens never enter it, logs,
error pages, Swagger, or `session.all`.

```ruby
if Tina4::Sso.configured?
  sso = Tina4::Sso.from_issuer
  metadata = sso.discover
  identity = sso.identity(request)
end
```

| Method | Result |
| --- | --- |
| `Tina4::Sso.configured?` | Reports whether required environment values exist. |
| `Tina4::Sso.from_issuer` | Creates the client and discovers the issuer. |
| `discover(force = false)` | Returns validated metadata. Force refreshes it. |
| `login(request, return_to = "/")` | Stores one-use state and returns the authorization URL. |
| `callback(request, query = nil)` | Validates the callback and regenerates Session. |
| `identity(request)` | Returns the normalized identity or `nil`. |
| `refresh(request)` | Replaces credentials and identity atomically. |
| `logout(request, return_to = "/")` | Destroys Session and returns the safe logout target. |

The return path must be local and absolute. Tina4 rejects schemes, hosts,
protocol-relative URLs, backslashes, and control characters.

## Claims and provider recipes

```ini
TINA4_SSO_CLAIM_MAP={"username":"preferred_username","roles":"realm_access.roles","groups":"groups"}
```

The runtime does not name providers. Keycloak uses a realm issuer such as
`https://sso.example.com/realms/my-realm`. Microsoft Entra ID uses its
tenant-specific v2 issuer. Register the exact callback URI and map claims only
when roles or groups use different names.

Version 3.13.104 supports introspection without another gem and requires a
client secret. Selecting `jwks` fails during configuration until the application
installs a supported cryptography capability. State, nonce, code, and verifier
are one-use. Logout always destroys the local Session first.

When configured, Swagger publishes the issuer discovery URL as an
`openIdConnect` scheme.
