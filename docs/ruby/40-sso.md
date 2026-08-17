# OpenID Connect SSO

Tina4 uses one provider-neutral OpenID Connect flow. Configure an issuer; the framework discovers its endpoints, runs Authorization Code with PKCE, verifies the result through introspection, and hands the normalized identity to the existing Session and secured-route gate.

```ini
TINA4_SSO_ISSUER=https://identity.example.com/realms/my-app
TINA4_SSO_CLIENT_ID=my-app
TINA4_SSO_CLIENT_SECRET=replace-me
TINA4_SSO_REDIRECT_URI=https://app.example.com/auth/callback
TINA4_SSO_SCOPES=["openid", "profile", "email"]
TINA4_SSO_VERIFY=introspection
```

When configured, `tina4 serve` mounts `GET /auth/login`, `GET /auth/callback`, and `POST /auth/logout`. Route collisions fail startup. Existing secured routes receive the identity through `request.user`; there is no SSO-only gate.

```ruby
sso = Tina4::Sso.from_issuer
identity = sso.identity(request.session)
```

Provider tokens remain in reserved Session data and never appear in `session.all`.

## Provider recipes

The runtime does not name providers. Keycloak uses its realm issuer, such as `https://sso.example.com/realms/my-realm`. Microsoft Entra ID uses its tenant v2 issuer, such as `https://login.microsoftonline.com/your-tenant-id/v2.0`. In either case, register the Tina4 callback URI and use `TINA4_SSO_CLAIM_MAP` only when roles or groups use different claim names.

Production issuer and callback URLs require HTTPS; HTTP is loopback-only. Introspection is the supported 3.13.104 verification mode and requires a client secret. `jwks` fails during configuration until an application cryptography capability is available.
