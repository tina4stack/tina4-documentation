# Feature 050: HTTP client

## Identity and status

- Matrix identity: 50 - standard-library HTTP client
- Current state: reopened / queued for a standalone 3.14 audit
- Evidence outside the old 32: later surface-parity work, no shared fixture

This packet reserves the correct standalone number. Feature 50 owns request
methods, redirects, timeouts, TLS, cookies, upload/download, response shape and
transport errors. Existing later parity work does not satisfy the 3.14 audit
bar. A shared data contract, adversarial real-server tests and a future-language
implementation formula are still required.
