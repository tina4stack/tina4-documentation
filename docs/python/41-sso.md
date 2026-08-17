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

SSO is off unless the required values are present. When configured, `tina4 serve` mounts `GET /auth/login`, `GET /auth/callback`, and `POST /auth/logout`. Defining one of those routes yourself is a startup error, so an application never silently replaces part of the login flow.

An authenticated browser keeps only the normal Tina4 Session cookie. Provider tokens stay in reserved Session data and never appear in `session.all()` or `request.user`.

## Use the signed-in identity

Use the normal secured-route mechanism. There is no SSO-only decorator.

```python
from tina4_python import get, Sso

@get("/account")
async def account(request, response):
    return response.json(request.user)

sso = Sso.from_issuer()
identity = sso.identity(request.session)
```

`request.user` contains `issuer`, `subject`, `username`, `email`, `name`, and sorted `roles` and `groups`. Provider tokens are deliberately excluded.

## Provider recipes

The runtime does not name providers. A recipe only supplies standard configuration.

For Keycloak, use the realm issuer:

```ini
TINA4_SSO_ISSUER=https://sso.example.com/realms/my-realm
```

Register `https://app.example.com/auth/callback` as a valid redirect URI and configure the client for authorization-code flow. Map realm roles, client roles, or groups into claims when your application needs them.

For Microsoft Entra ID, use the tenant-specific v2 issuer:

```ini
TINA4_SSO_ISSUER=https://login.microsoftonline.com/your-tenant-id/v2.0
```

Register the same callback URI and use `TINA4_SSO_CLAIM_MAP` when your tenant exposes roles or groups under different claim names.

## Security boundary

Production issuer and callback URLs must use HTTPS; plain HTTP is accepted only on loopback for local testing. External return URLs are rejected. Introspection is the supported verification mode in 3.13.104 and requires a client secret. Selecting `jwks` fails during configuration until an application cryptography capability is available.
