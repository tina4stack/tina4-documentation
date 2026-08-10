# Feature 039: Frond template caching

## Identity and status

- Matrix identity: 39 - cache compiled Frond templates
- Current state: reopened / queued for a standalone 3.14 audit
- Historical evidence was mixed into the Feature 43 cache-backend audit
- Dependencies: Features 28-31 and the Feature 43 cache-provider contract

Feature 39 owns compiled-template cache identity, freshness, invalidation,
development behavior, concurrency and bounds. It does not own fragment output
caching (Feature 40), general KV backends (Feature 43) or HTTP response caching.

The previous combined cache audit did not provide a standalone template-cache
contract or fixture. This packet exists to keep the number visible and honest;
it remains unaudited under the 3.14 rules.
