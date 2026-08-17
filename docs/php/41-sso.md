# OpenID Connect SSO

Tina4 uses one provider-neutral OpenID Connect flow. Configure an issuer; the framework discovers its endpoints, runs Authorization Code with PKCE, verifies the result through introspection, and stores the normalized identity in the existing Tina4 Session.

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

SSO is off unless the required values are present. When configured, `tina4 serve` mounts `GET /auth/login`, `GET /auth/callback`, and `POST /auth/logout`. A collision with an application route fails startup.

Use the existing secured-route mechanism. The normalized identity is available as `$request->user`; provider tokens remain in reserved Session data and never appear in `Session::all()`.

```php
use Tina4Sso;

$sso = Sso::fromIssuer();
$identity = $sso->identity($request->session);
```

## Provider recipes

The runtime does not name providers. For Keycloak, set the realm issuer:

```ini
TINA4_SSO_ISSUER=https://sso.example.com/realms/my-realm
```

Enable authorization-code flow and register `https://app.example.com/auth/callback`. For Microsoft Entra ID, use `https://login.microsoftonline.com/your-tenant-id/v2.0` as the issuer. Use `TINA4_SSO_CLAIM_MAP` when a provider exposes roles or groups under different claim names.

Production issuer and callback URLs must use HTTPS; HTTP is loopback-only. Introspection is the supported verification mode in 3.13.104 and requires a client secret. `jwks` fails at configuration until an application cryptography capability is available.
